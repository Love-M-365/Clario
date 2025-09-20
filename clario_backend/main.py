import os
import json
from datetime import datetime, timezone
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import auth, credentials
from google import genai
from google.cloud import firestore

# ------------------ CONFIG ------------------
PROJECT_ID = "clario-f60b0"
LOCATION = "us-central1"
MODEL = "gemini-2.5-flash"

MAX_RECENT = 8
SUMMARY_TRIGGER = 10

# ------------------ Initialize Clients ------------------
if not firebase_admin._apps:
    cred = credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred, {"projectId": PROJECT_ID})

db = firestore.Client(project=PROJECT_ID)
client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)

app = Flask(__name__)

# ------------------ Onboarding Questions ------------------
ONBOARDING_QUESTIONS_FULL = [
    "",
    "Hi, I am Clario. Before we begin, I’d love to get to know you a little better. I’ll ask you a few quick questions about yourself so I can support you in a way that feels personal and meaningful. So, what’s your name (or nickname you’d like me to use)?",
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
    "Is there anything you don’t want me to talk about?"
]

ONBOARDING_KEYS = [
    "intro","name", "age", "gender", "mood_scale", "stress_status", "therapy_history",
    "main_goal", "life_areas", "important_people", "track_interactions",
    "sleep_hours", "exercise_habit", "self_care_habits", "check_in_if_low",
    "trusted_person", "conversation_length_pref", "no_talk_topics"
]

# ------------------ Firestore Utilities ------------------
def get_user_profile(user_id):
    doc_ref = db.collection("users").document(user_id)
    doc = doc_ref.get()
    return doc.to_dict() if doc.exists else {}

def save_user_profile(user_id, profile_data):
    db.collection("users").document(user_id).set(profile_data)

def save_chat_message(user_id, role, text):
    db.collection("users").document(user_id).collection("chats").document().set({
        "role": role,
        "text": text,
        "ts": datetime.now(timezone.utc)
    })

def load_history(user_id):
    chats_ref = db.collection("users").document(user_id).collection("chats").order_by("ts")
    docs = chats_ref.stream()
    history = []
    for doc in docs:
        data = doc.to_dict()
        history.append({
            "role": data.get("role"),
            "text": data.get("text"),
            "ts": data.get("ts").isoformat() if hasattr(data.get("ts"), "isoformat") else str(data.get("ts"))
        })
    return history

# ------------------ AI Logic ------------------
def summarize_memory(history):
    preamble = (
        "Summarize essential, stable facts from the conversation that will help in future therapy-style responses. "
        "Include user's background facts, ongoing problems, therapy preferences, exercises tried, and any safety concerns. "
        "Keep summary concise (<= 250 words)."
    )
    convo_text = [f"{t['role'].upper()} ({t['ts']}): {t['text']}" for t in history]
    full_input = preamble + "\n\nConversation:\n" + "\n".join(convo_text)
    resp = client.models.generate_content(model=MODEL, contents=full_input)
    try:
        return resp.candidates[0].content.parts[0].text.strip()
    except Exception:
        return ""

def build_prompt(memory_summary, history, profile):
    instructions = (
        "You are Clario — a compassionate, evidence-informed mental health companion. "
        "Behave like a supportive therapist and best friend: validate feelings, ask clarifying questions. "
        "Speak in a warm, conversational tone, 2-3 sentences. "
        "Prioritize empathy. Do not suggest exercises immediately unless user shares details. "
        "If self-harm risk, direct user to professional help.\n"
        "Use the following guidance:\n"
        "- Guilt/conflict → Empty Chair Technique\n"
        "- Anxiety → Grounding 5-4-3-2-1\n"
        "- Overwhelm → Breathing/journaling\n"
        "- Hopeless/self-critical → Gentle reframing/affirmations\n"
    )
    parts = [instructions]

    if profile:
        parts.append("User profile:\n" + json.dumps(profile, indent=2) + "\n")
    if memory_summary:
        parts.append("Memory summary:\n" + memory_summary + "\n")

    recent = history[-MAX_RECENT*2:] if history else []
    if recent:
        parts.append("Recent conversation:")
        for turn in recent:
            parts.append(f"{turn['role'].upper()} ({turn['ts']}): {turn['text']}")
        parts.append("")

    parts.append("Now respond to the user's latest message empathetically.")
    return "\n".join(parts)

def get_assistant_reply(memory_summary, history, user_message, profile):
    temp_history = history + [{"role": "user", "text": user_message, "ts": datetime.now(timezone.utc).isoformat()}]
    prompt = build_prompt(memory_summary, temp_history, profile)
    resp = client.models.generate_content(model=MODEL, contents=prompt)
    try:
        return resp.candidates[0].content.parts[0].text.strip()
    except Exception:
        return "Sorry, I couldn't generate a response right now."

# ------------------ Flask Routes ------------------
@app.route("/chat", methods=["POST"])
def chat():
    try:
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return jsonify({"error": "Missing or invalid Authorization header"}), 401

        id_token = auth_header.split(" ")[1]
        decoded_token = auth.verify_id_token(id_token)
        user_id = decoded_token["uid"]

        profile = get_user_profile(user_id)
        body = request.get_json()
        user_message = body.get("message", "").strip()

        # ---- Onboarding ----
        if not profile.get("onboarding_complete", False):
            answered_keys = [k for k in ONBOARDING_KEYS if k in profile]
            current_index = len(answered_keys)

            # First question if no answer yet
            if current_index == 0 and not user_message:
                return jsonify({
                    "status": "in_progress",
                    "question": ONBOARDING_QUESTIONS_FULL[0]
                })

            # Save the previous answer
            if user_message and current_index < len(ONBOARDING_KEYS):
                current_key = ONBOARDING_KEYS[current_index]
                profile[current_key] = user_message
                save_user_profile(user_id, profile)
                current_index += 1

            # Check if onboarding is complete
            if current_index >= len(ONBOARDING_QUESTIONS_FULL):
                profile["onboarding_complete"] = True
                save_user_profile(user_id, profile)
                return jsonify({
                    "status": "complete",
                    "message": "Onboarding completed! You can now start chatting."
                })

            # Ask next question
            return jsonify({
                "status": "in_progress",
                "question": ONBOARDING_QUESTIONS_FULL[current_index]
            })

        # ---- Normal chat ----
        history = load_history(user_id)
        memory_summary = summarize_memory(history) if len(history) >= SUMMARY_TRIGGER else ""
        save_chat_message(user_id, "user", user_message)
        reply = get_assistant_reply(memory_summary, history, user_message, profile)
        save_chat_message(user_id, "assistant", reply)
        return jsonify({"reply": reply})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ------------------ Onboarding Route ------------------
@app.route("/onboarding", methods=["POST"])
def onboarding():
    try:
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return jsonify({"error": "Missing or invalid Authorization header"}), 401

        id_token = auth_header.split(" ")[1]
        decoded_token = auth.verify_id_token(id_token)
        user_id = decoded_token["uid"]

        body = request.get_json()
        user_response = body.get("answer", "").strip()

        profile_ref = db.collection("users").document(user_id)
        profile_doc = profile_ref.get()
        profile_data = profile_doc.to_dict() if profile_doc.exists else {}

        answered_keys = [k for k in ONBOARDING_KEYS if k in profile_data]
        current_index = len(answered_keys)

        if user_response and current_index < len(ONBOARDING_KEYS):
            prev_key = ONBOARDING_KEYS[current_index - 1]
            profile_data[prev_key] = user_response
            profile_ref.set(profile_data, merge=True)
            current_index += 1

        if current_index >= len(ONBOARDING_QUESTIONS_FULL):
            profile_data["onboarding_complete"] = True
            profile_ref.set(profile_data, merge=True)
            return jsonify({"status": "complete", "message": "Onboarding completed!"})

        return jsonify({"status": "in_progress", "question": ONBOARDING_QUESTIONS_FULL[current_index]})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 400

# ------------------ Entry ------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
