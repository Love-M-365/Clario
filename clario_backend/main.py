import os
import json
import re # For parsing Gemini response
from datetime import datetime, timezone
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import auth, credentials, initialize_app, db as rtdb # Use RTDB for simplicity with getCurrentAvatar example
from google.cloud import firestore # Keep if used by Flask routes
import functions_framework
from google.cloud import language_v1 # For old analyzeMood helper (optional fallback)

# --- Imports for Gemini ---
import google.generativeai as genai
from vertexai.generative_models import GenerativeModel

# --- Imports for generateAvatar ---
import vertexai
import base64
from vertexai.preview.vision_models import ImageGenerationModel

# ------------------ CONFIG ------------------
PROJECT_ID = "clario-f60b0" # Your Project ID
LOCATION = "us-central1"
GEMINI_MODEL_CHAT = "gemini-pro" # Model for chat
GEMINI_MODEL_ANALYSIS = "gemini-pro"# Model for sentiment analysis

CRON_SECRET = os.environ.get("DAILY_QUOTE_SECRET", "REPLACE_THIS_WITH_A_REAL_SECRET")
# --- END NEW ADDITION ---

MAX_RECENT_HISTORY = 10 # How many turns of recent history to include in chat prompt

# ------------------ Initialize Clients ------------------
# Initialize Firebase Admin SDK (runs only once per instance)
if not firebase_admin._apps:
    initialize_app()

db_firestore = firestore.Client(project=PROJECT_ID) # Keep for Flask routes if needed
language_client_nlp = language_v1.LanguageServiceClient() # Keep for fallback sentiment

# --- Configure Gemini ---
# IMPORTANT: Set GOOGLE_API_KEY environment variable during deployment
try:
    gemini_api_key = os.environ.get("GOOGLE_API_KEY")
    if not gemini_api_key:
        raise ValueError("GOOGLE_API_KEY environment variable not set.")
    genai.configure(api_key=gemini_api_key)
    print("Gemini configured successfully.")
except Exception as e:
    print(f"ERROR: Failed to configure Gemini: {e}")
    # Handle this case - maybe disable Gemini features?

# Initialize Flask app (used for /chat and /onboarding routes IF deploying as Cloud Run)
app = Flask(__name__)

# ------------------ Authentication Helper ------------------
def verify_token(req):
    """Verifies the Firebase Auth token from the request header."""
    # ... (Keep existing verify_token function) ...
    auth_header = req.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        print("Missing or invalid Authorization header")
        return None
    id_token = auth_header.split(' ').pop()
    try:
        decoded_token = auth.verify_id_token(id_token)
        return decoded_token
    except Exception as e:
        print(f"Error verifying token: {e}")
        return None


# ------------------ Onboarding Data (Keep as is) ------------------
ONBOARDING_QUESTIONS_FULL = [
    "", "Hi, I am Clario. Before we begin, I’d love to get to know you a little better. I’ll ask you a few quick questions about yourself so I can support you in a way that feels personal and meaningful. So, what’s your name (or nickname you’d like me to use)?",
    "How old are you?",
    "What’s your gender/pronouns (optional)?",
    "How are you feeling today on a scale of 1–10?",
    "Do you currently feel stressed, anxious, or low?",
    "Have you ever spoken to a therapist or counselor before?",
    "What would you like me to help you with the most?",
    "Are there specific areas of your life you’d like to improve?",
    "Who are the most important people in your life?",
    "Would you like me to track interactions/conflicts with specific people?",
    "How many hours of sleep do you usually get?",
    "Do you exercise regularly?",
    "Do you practice meditation, journaling, or other self-care habits?",
    "Do you want me to check in if I notice you sound very sad, anxious, or hopeless?",
    "Do you have a trusted person I should remind you to reach out to if you’re feeling very low? If yes, who?",
    "Do you prefer short, friendly chats or longer, deeper conversations?",
    "Is there anything you don’t want me to talk about?",
]
ONBOARDING_KEYS = [
    "intro","name", "age", "gender", "mood_scale", "stress_status", "therapy_history",
    "main_goal", "life_areas", "important_people", "track_interactions",
    "sleep_hours", "exercise_habit", "self_care_habits", "check_in_if_low",
    "trusted_person", "conversation_length_pref", "no_talk_topics"
]

# ------------------ Firestore Utilities (Keep as is) ------------------
# These use db_firestore
def get_user_profile(user_id):
    doc_ref = db_firestore.collection("users").document(user_id)
    doc = doc_ref.get()
    return doc.to_dict() if doc.exists else {}

def save_user_profile(user_id, profile_data):
    db_firestore.collection("users").document(user_id).set(profile_data, merge=True)

def save_chat_message(user_id, role, text):
     db_firestore.collection("users").document(user_id).collection("chats").document().set({
        "role": role, "text": text, "ts": datetime.now(timezone.utc)
    })

def load_history(user_id):
    chats_ref = db_firestore.collection("users").document(user_id).collection("chats").order_by("ts", direction=firestore.Query.DESCENDING).limit(MAX_RECENT_HISTORY * 2) # Limit history load
    docs = chats_ref.stream()
    history = []
    for doc in docs:
        data = doc.to_dict()
        ts_val = data.get("ts")
        ts_str = ts_val.isoformat() if hasattr(ts_val, "isoformat") else str(ts_val)
        history.append({ "role": data.get("role"), "text": data.get("text"), "ts": ts_str })
    return history[::-1] # Reverse to get chronological order


# --- Gemini Chat Helper ---
def generate_gemini_chat_reply(history, user_message, profile):
    """Generates a chat reply using the Gemini API."""
    try:
        model = genai.GenerativeModel(GEMINI_MODEL_CHAT)
        
        # Build context for Gemini
        context_prompt = (
            "You are Clario, a compassionate mental health companion. "
            "Behave like a supportive therapist and friend: validate feelings, ask clarifying questions. "
            "Speak warmly, 2-3 sentences. Prioritize empathy. "
            "If self-harm risk, direct user to professional help.\n"
            "User profile:\n"
            f"{json.dumps(profile, indent=2)}\n\n"
            "Recent conversation history (user and assistant turns):\n"
        )
        
        # Format history for the model (ensure user/model roles)
        gemini_history = []
        for turn in history:
             # Adjust role based on Gemini's expectation ('user'/'model')
             role = 'user' if turn.get('role') == 'user' else 'model' 
             gemini_history.append({'role': role, 'parts': [turn.get('text', '')]})

        # Start chat with context and history
        chat_session = model.start_chat(history=gemini_history)
        
        # Send the latest user message (append context if desired, or let history handle it)
        full_user_prompt = f"{context_prompt}\nUSER: {user_message}\nASSISTANT:" # Or just user_message if using start_chat history
        
        # Use generate_content for single turn with full context, or send_message with chat_session
        # Using generate_content for simplicity here, including history in the prompt text
        prompt_parts = [context_prompt]
        for turn in history: # Add history turns explicitly
             prompt_parts.append(f"{turn.get('role', '').upper()}: {turn.get('text', '')}")
        prompt_parts.append(f"USER: {user_message}")
        prompt_parts.append("ASSISTANT:") # Ask model to complete as assistant

        response = model.generate_content("\n".join(prompt_parts))

        # response = chat_session.send_message(user_message) # Alternative using chat session state
        
        reply_text = response.text.strip()
        print(f"Gemini chat reply generated: '{reply_text[:60]}...'")
        return reply_text
        
    except Exception as e:
        print(f"ERROR generating Gemini chat reply: {e}")
        # Consider checking specific error types (e.g., BlockedPromptException)
        return "I'm having trouble thinking right now. Could you try rephrasing?"


def analyze_sentiment_with_gemini(text_content):
    """
    Analyzes sentiment using Gemini, aiming for a 0-10 score and tag.
    Improved JSON parsing and validation.
    """
    if not text_content: # Handle empty input
        print("WARN: analyze_sentiment_with_gemini received empty text.")
        return {"score": 0.0, "tag": "Neutral"}

    try:
        model = genai.GenerativeModel(GEMINI_MODEL_ANALYSIS)
        prompt = (
            "Analyze the sentiment of the following journal entry. Provide a sentiment score from 0 (very negative) to 10 (very positive) "
            "and a single descriptive tag (e.g., Positive, Negative, Neutral, Anxious, Grateful, Frustrated, Hopeful, Mixed). "
            "Format the output strictly as JSON: {\"score\": SCORE, \"tag\": \"TAG\"}\n\n"
            f"Journal Entry:\n\"\"\"\n{text_content}\n\"\"\"\n\n"
            "JSON Output:"
        )

        # Generate content with safety settings if needed (optional)
        # response = model.generate_content(prompt, safety_settings={'HARASSMENT': 'BLOCK_NONE', ...})
        response = model.generate_content(prompt)

        # Check for empty or blocked response *before* accessing text
        if not response.candidates:
             print("WARN: Gemini response blocked or empty.")
             # Check response.prompt_feedback if needed for block reason
             return {"score": 0.0, "tag": "Neutral"} # Fallback

        response_text = response.text.strip()
        print(f"Gemini sentiment analysis raw response: {response_text}")

        # Attempt to extract and parse the JSON response more robustly
        try:
            # Find the first JSON object using regex
            match = re.search(r"\{.*\}", response_text, re.DOTALL)
            if not match:
                raise ValueError("No JSON object found in the response.")

            json_string = match.group(0)
            result = json.loads(json_string)

            # Validate structure and types
            score_val = result.get("score")
            tag_val = result.get("tag")

            if isinstance(score_val, (int, float)) and isinstance(tag_val, str):
                score_0_10 = float(score_val)
                # Clamp score to 0-10 range just in case
                score_0_10 = max(0.0, min(10.0, score_0_10))

                # Convert 0-10 score to -1.0 to +1.0
                score_neg1_pos1 = (score_0_10 / 5.0) - 1.0

                print(f"Gemini sentiment parsed: Score={score_neg1_pos1:.2f} (from {score_0_10}), Tag={tag_val}")
                return {"score": score_neg1_pos1, "tag": tag_val}
            else:
                raise ValueError(f"Parsed JSON has incorrect structure or types. Score: {score_val}, Tag: {tag_val}")

        except (json.JSONDecodeError, ValueError, AttributeError) as json_e:
            print(f"ERROR: Failed to extract or parse Gemini sentiment JSON: {json_e}. Raw response: '{response_text}'")
            # Fallback to neutral
            return {"score": 0.0, "tag": "Neutral"}

    # Catch potential errors during the API call itself
    except Exception as e:
        print(f"ERROR analyzing sentiment with Gemini API call: {e}")
        # Fallback to neutral on error
        return {"score": 0.0, "tag": "Neutral"}


# --- Cloud Function: analyzeMood (Keep as is) ---
@functions_framework.http
def analyzeMood(req):
    """HTTP Cloud Function: Analyzes journal entry mood using Gemini. Requires Auth."""
    decoded_token = verify_token(req) # Assuming verify_token is defined
    if not decoded_token: return ("Unauthorized", 401)

    if req.method == "OPTIONS": # Handle CORS
        headers = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "POST", "Access-Control-Allow-Headers": "Content-Type, Authorization", "Access-Control-Max-Age": "3600"}
        return ("", 204, headers)
    headers = {"Access-Control-Allow-Origin": "*"}

    if not req.is_json: return ("Request must be JSON", 400, headers)
    request_json = req.get_json(silent=True)
    if not request_json or "text" not in request_json: return ("JSON payload must contain a 'text' field", 400, headers)

    journal_text = request_json["text"]
    if not journal_text.strip(): # Check if text is empty after stripping whitespace
         print(f"analyzeMood: Received empty journal text for user {decoded_token.get('uid', 'unknown')}. Returning Neutral.")
         return (jsonify({"score": 0.0, "tag": "Neutral"}), 200, headers) # Return neutral for empty text

    try:
        # --- USE FIXED GEMINI HELPER ---
        sentiment_result = analyze_sentiment_with_gemini(journal_text)
        print(f"analyzeMood (Gemini): User {decoded_token.get('uid', 'unknown')}, Result: {sentiment_result}")
        return (jsonify(sentiment_result), 200, headers)
    except Exception as e:
        # This catches errors *within* analyzeMood, not necessarily in the helper
        print(f"Unexpected error in analyzeMood function: {e}")
        return ("Internal Server Error", 500, headers)
@functions_framework.http
def generateAvatar(req):
    """Generates an avatar with fallback to safe prompt if filters trigger."""
    decoded_token = verify_token(req)
    if not decoded_token:
        return ("Unauthorized", 401)

    headers = {"Access-Control-Allow-Origin": "*"}
    if req.method == "OPTIONS":
        headers.update({
            "Access-Control-Allow-Methods": "POST",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
            "Access-Control-Max-Age": "3600"
        })
        return ("", 204, headers)

    if not req.is_json:
        return ("Request must be JSON", 400, headers)

    data = req.get_json(silent=True)
    prompt = data.get("prompt", "").strip()
    if not prompt:
        return ("'prompt' cannot be empty", 400, headers)

    # --- SANITIZE PROMPT ---
    safe_prompt = sanitize_prompt(prompt)

    try:
        vertexai.init(project=PROJECT_ID, location=LOCATION)
        model = ImageGenerationModel.from_pretrained("imagegeneration@006")
        response = model.generate_images(prompt=safe_prompt, number_of_images=1, aspect_ratio="1:1")
        if not response.images:
            # fallback prompt if blocked
            print("⚠️ Safety filter triggered. Retrying with neutral prompt.")
            fallback_prompt = "A friendly abstract avatar of a person in cartoon style"
            response = model.generate_images(prompt=fallback_prompt, number_of_images=1, aspect_ratio="1:1")

        image_bytes = response.images[0]._image_bytes
        base64_image = base64.b64encode(image_bytes).decode('utf-8')
        return (jsonify({"image_base64": base64_image}), 200, headers)

    except Exception as e:
        print("Avatar generation failed:", e)
        # final fallback → your static default avatar
        with open("default_avatar_base64.txt", "r") as f:
            default_avatar = f.read().strip()
        return (jsonify({"image_base64": default_avatar}), 200, headers)


# --- HELPER FUNCTION: prompt sanitizer ---
def sanitize_prompt(prompt: str) -> str:
    """Cleans unsafe or ambiguous prompts before sending to Imagen."""
    import re
    blocked_words = [
        "nude", "blood", "weapon", "kill", "death", "violence",
        "drug", "sex", "hate", "nsfw", "gun", "murder", "war"
    ]
    clean = re.sub(r"|".join(blocked_words), "peaceful", prompt, flags=re.IGNORECASE)
    # add neutral style context
    clean += " | high quality portrait in digital art style, neutral lighting"
    return clean

# --- Flask Routes (Keep as is) ---
@app.route("/chat", methods=["POST"])
def chat():
    """Flask Route: Handles general chat interactions using Gemini."""
    try:
        decoded_token = verify_token(request)
        if not decoded_token: return jsonify({"error": "Unauthorized"}), 401
        user_id = decoded_token["uid"]

        profile = get_user_profile(user_id)
        body = request.get_json()
        user_message = body.get("message", "").strip()

        if not profile.get("onboarding_complete", False):
           return jsonify({"error": "Please complete onboarding first via /onboarding route."}), 400

        history = load_history(user_id) # Loads limited recent history
        save_chat_message(user_id, "user", user_message)

        # --- Use Gemini for reply ---
        reply = generate_gemini_chat_reply(history, user_message, profile)
        # --- End Gemini call ---

        save_chat_message(user_id, "assistant", reply)
        return jsonify({"reply": reply})

    except Exception as e:
        print(f"Error in /chat route: {e}")
        return jsonify({"error": "An internal server error occurred"}), 500

@app.route("/onboarding", methods=["POST"])
def onboarding():
    """Flask Route: Handles the step-by-step onboarding process."""
    # ... (Keep existing onboarding logic exactly as it was) ...
    try:
        decoded_token = verify_token(request) 
        if not decoded_token: return jsonify({"error": "Unauthorized"}), 401
        user_id = decoded_token["uid"]
        body = request.get_json()
        user_response = body.get("answer", "").strip()
        profile_data = get_user_profile(user_id)
        answered_keys = [k for k in ONBOARDING_KEYS if k in profile_data and k != "intro"]
        current_question_index = len(answered_keys) + 1 
        if user_response and current_question_index > 0: 
            previous_key_index = current_question_index -1 
            if previous_key_index < len(ONBOARDING_KEYS): 
                 previous_key = ONBOARDING_KEYS[previous_key_index]
                 profile_data[previous_key] = user_response
                 save_user_profile(user_id, profile_data) 
        answered_keys_after_save = [k for k in ONBOARDING_KEYS if k in profile_data and k != "intro"]
        next_question_index = len(answered_keys_after_save) + 1
        if next_question_index >= len(ONBOARDING_QUESTIONS_FULL):
            profile_data["onboarding_complete"] = True
            save_user_profile(user_id, profile_data) 
            return jsonify({"status": "complete", "message": "Onboarding completed!"})
        return jsonify({"status": "in_progress", "question": ONBOARDING_QUESTIONS_FULL[next_question_index]})
    except Exception as e:
        print(f"Error in /onboarding route: {e}")
        return jsonify({"status": "error", "message": "An internal server error occurred"}), 500



# --- Cloud Function: processSensorData (Keep as is) ---
@functions_framework.http
def processSensorData(req):
    """
    HTTP Cloud Function that receives sensor or app usage data,
    analyzes it, and stores reminder/notification info in Firestore.
    """
    decoded_token = verify_token(req)
    if not decoded_token:
        return ("Unauthorized", 401)

    if req.method == "OPTIONS":  # Handle CORS
        headers = {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
            "Access-Control-Max-Age": "3600"
        }
        return ("", 204, headers)
    headers = {"Access-Control-Allow-Origin": "*"}

    if not req.is_json:
        return ("Request must be JSON", 400, headers)

    try:
        payload = req.get_json()
        user_id = decoded_token["uid"]

        # Example: {"type": "screen_time", "app": "Instagram", "minutes": 50}
        event_type = payload.get("type")
        app_name = payload.get("app")
        minutes = float(payload.get("minutes", 0))

        if event_type == "screen_time":
            if minutes > 30:
                message = f"You’ve spent {int(minutes)} mins on {app_name}. Maybe take a short break?"
                db_firestore.collection("users").document(user_id).collection("notifications").add({
                    "title": "Mindful Reminder",
                    "message": message,
                    "timestamp": datetime.now(timezone.utc),
                    "type": "screen_time",
                    "app": app_name,
                    "read": False
                })
                print(f"Notification created for user {user_id}: {message}")
                return (jsonify({"status": "ok", "notification": message}), 200, headers)
            else:
                print(f"No notification needed for {app_name} ({minutes} mins).")
                return (jsonify({"status": "ok", "notification": None}), 200, headers)

        else:
            print(f"Unhandled event type: {event_type}")
            return (jsonify({"status": "ignored", "message": "Unknown event type"}), 200, headers)

    except Exception as e:
        print(f"Error in processSensorData: {e}")
        return (jsonify({"error": str(e)}), 500, headers)

# --- NEW ADDITION: Daily Quote Generation Function ---
@functions_framework.http
def updateDailyQuote(req):
    """
    HTTP Cloud Function: Generates a daily quote using Vertex AI (no API key needed)
    and saves it to Firestore.
    Intended to be called by Cloud Scheduler.
    Requires a 'secret' query parameter to run for security.
    """
    
    # --- Security Check ---
    # We still need this secret to protect the public function URL
    provided_secret = req.args.get("secret")
    if provided_secret != CRON_SECRET:
        print(f"Unauthorized attempt to run updateDailyQuote. Provided secret: '{provided_secret}'")
        return ("Unauthorized", 401)

    # Handle CORS preflight (good practice)
    if req.method == "OPTIONS":
        headers = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET", "Access-Control-Allow-Headers": "Content-Type", "Access-Control-Max-Age": "3600"}
        return ("", 204, headers)
    headers = {"Access-Control-Allow-Origin": "*"}

    print("Daily quote update job started (using Vertex AI)...")

    try:
        # --- Initialize Vertex AI ---
        # This uses your project's service account (like gauth) - NO API KEY!
        vertexai.init(project=PROJECT_ID, location=LOCATION)
        
        # Use the model you already have defined
        model = GenerativeModel(GEMINI_MODEL_ANALYSIS) 
        
        prompt = (
            "You are an assistant that provides one inspirational quote for mental wellness. "
            "Provide a short, insightful, and supportive quote. "
            "Format the output strictly as JSON: {\"text\": \"QUOTE_TEXT\", \"author\": \"AUTHOR_NAME\"}\n\n"
            "JSON Output:"
        )

        # Generate content using the Vertex AI SDK
        response = model.generate_content(prompt)

        if not response.candidates:
            print("WARN: Daily quote Vertex AI response blocked or empty.")
            return ("Gemini response was blocked or empty", 500, headers)

        response_text = response.text.strip()
        print(f"Daily quote raw response: {response_text}")

        # Use the same robust JSON parsing
        match = re.search(r"\{.*\}", response_text, re.DOTALL)
        if not match:
            raise ValueError("No JSON object found in the quote response.")
        
        json_string = match.group(0)
        quote_data = json.loads(json_string)

        if "text" not in quote_data or "author" not in quote_data:
            raise ValueError(f"Parsed JSON has incorrect structure: {quote_data}")

        quote_data["updated_at"] = datetime.now(timezone.utc)

        # Save to Firestore (same as before)
        doc_ref = db_firestore.collection("config").document("dailyQuote")
        doc_ref.set(quote_data)

        print(f"Successfully saved daily quote to Firestore: {quote_data['text']}")
        return (jsonify({"status": "success", "quote": quote_data}), 200, headers)

    except Exception as e:
        print(f"ERROR in updateDailyQuote (Vertex AI): {e}")
        return (jsonify({"status": "error", "message": str(e)}), 500, headers)


# ------------------ Entry for Local Flask Development ------------------
if __name__ == "__main__":
    print("Starting Flask server for local development...")
    # Make sure GOOGLE_API_KEY is set in your local environment for testing
    if not os.environ.get("GOOGLE_API_KEY"):
         print("WARNING: GOOGLE_API_KEY environment variable not set for local testing.")
    # --- NEW: Also check for the cron secret ---
    if not os.environ.get("DAILY_QUOTE_SECRET"):
         print("WARNING: DAILY_QUOTE_SECRET environment variable not set for local testing. Using default.")
    # --- END NEW ---
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)), debug=True)

