import os
import json
from datetime import datetime, timezone
import google_genai as genai
from google.cloud import firestore

# ------------------ CONFIG ------------------
PROJECT_ID = "clario-f60b0"  # Your Firebase project ID
LOCATION = "us-central1"
MODEL = "gemini-2.5-flash"

MAX_RECENT = 8
SUMMARY_TRIGGER = 10

# ------------------ Initialize Clients ------------------
# Use Google GenAI with Vertex AI
client = genai.Client(
    vertexai=True,
    project=PROJECT_ID,
    location=LOCATION
)

db = firestore.Client(project=PROJECT_ID)

# ------------------ Onboarding Questions ------------------
ONBOARDING_QUESTIONS_FULL = [
    "What’s your name (or nickname you’d like me to use)?",
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

# Keys for storing in Firestore (aligned with questions)
ONBOARDING_KEYS = [
    "name", "age", "gender", "mood_scale", "stress_status", "therapy_history",
    "main_goal", "life_areas", "important_people", "track_interactions",
    "sleep_hours", "exercise_habit", "self_care_habits", "check_in_if_low",
    "trusted_person", "conversation_length_pref", "no_talk_topics"
]

# ------------------ Firestore Utilities ------------------
def get_user_profile(user_id):
    doc_ref = db.collection("users").document(user_id)
    doc = doc_ref.get()
    return doc.to_dict() if doc.exists else None

def save_user_profile(user_id, profile_data):
    db.collection("users").document(user_id).set(profile_data)

def save_chat_message(user_id, role, text):
    db.collection("users").document(user_id).collection("chats").add({
        "role": role,
        "text": text,
        "ts": datetime.now(timezone.utc)
    })

def load_history(user_id):
    chats_ref = db.collection("users").document(user_id).collection("chats").order_by("ts")
    docs = chats_ref.stream()
    return [
        {
            "role": d.get("role"),
            "text": d.get("text"),
            "ts": d.get("ts").isoformat() if hasattr(d.get("ts"), "isoformat") else str(d.get("ts"))
        }
        for d in (doc.to_dict() for doc in docs)
    ]

# ------------------ Onboarding Helper ------------------
def get_onboarding_question(user_id, answer=None, question_index=0):
    """
    Returns the next onboarding question for the user.
    Saves previous answer if provided.
    """
    profile = get_user_profile(user_id) or {}

    # Save previous answer
    if answer is not None and question_index > 0:
        key = ONBOARDING_KEYS[question_index - 1]
        profile[key] = answer
        save_user_profile(user_id, profile)

    # If all questions done, return None
    if question_index >= len(ONBOARDING_QUESTIONS_FULL):
        return None, profile

    # Return next question and updated index
    return ONBOARDING_QUESTIONS_FULL[question_index], question_index


# ------------------ Chat Handler with Onboarding ------------------
def chat_with_user(user_id, user_message, onboarding_index=None):
    """
    Handles both onboarding questions and regular AI responses.
    - onboarding_index: which onboarding question we are at
    """
    profile = get_user_profile(user_id)

    # If user profile not complete, do onboarding
    if not profile or onboarding_index is not None:
        question, next_index = get_onboarding_question(user_id, answer=user_message, question_index=onboarding_index or 0)
        if question:
            return {
                "role": "ai",
                "text": question,
                "onboarding_index": next_index + 1  # frontend tracks next question
            }
        else:
            # Finished onboarding, reload profile
            profile = get_user_profile(user_id)

    # ---------------- Normal AI chat ----------------
    history = load_history(user_id)
    memory_summary = summarize_memory(history)
    reply = get_assistant_reply(memory_summary, history, user_message, profile)
    save_chat_message(user_id, "user", user_message)
    save_chat_message(user_id, "ai", reply)
    return {"role": "ai", "text": reply}

# ------------------ Onboarding ------------------
def run_onboarding(user_id, profile_data):
    profile_data["created_at"] = datetime.now(timezone.utc).isoformat()
    save_user_profile(user_id, profile_data)
    return profile_data

# ------------------ Relations ------------------
def update_relations(user_id, user_message):
    analysis_prompt = f"""
    From this message, extract if the user is talking about another person.
    Return JSON with keys: name (if any), sentiment ("conflict", "supportive", or "neutral").
    Message: {user_message}
    """
    try:
        resp = client.models.generate_content(model=MODEL, contents=analysis_prompt)
        analysis = json.loads(resp.candidates[0].content.parts[0].text)
    except Exception:
        return

    if "name" in analysis and analysis["name"]:
        relations_ref = db.collection("users").document(user_id).collection("relations").document(analysis["name"])
        doc = relations_ref.get()
        if doc.exists:
            data = doc.to_dict()
            data.update({
                "times_mentioned": data.get("times_mentioned", 0) + 1,
                "last_mentioned": datetime.now(timezone.utc).isoformat(),
                "sentiment": analysis["sentiment"]
            })
            relations_ref.set(data)
        else:
            relations_ref.set({
                "name": analysis["name"],
                "sentiment": analysis["sentiment"],
                "times_mentioned": 1,
                "last_mentioned": datetime.now(timezone.utc).isoformat()
            })

# ------------------ Memory Summarization ------------------
def summarize_memory(history):
    summarization_preamble = (
        "Summarize essential, stable facts from the conversation that will help in future therapy-style responses. "
        "Include: user's background facts, ongoing problems, therapy preferences, exercises tried, and any safety concerns. "
        "Keep summary concise (<= 250 words)."
    )
    convo_text = [f"{t.get('role').upper()} ({t.get('ts')}): {t.get('text')}" for t in history]
    full_input = summarization_preamble + "\n\nConversation:\n" + "\n".join(convo_text)
    resp = client.models.generate_content(model=MODEL, contents=full_input)
    try:
        return resp.candidates[0].content.parts[0].text.strip()
    except Exception:
        return ""

# ------------------ Prompt Building ------------------
def build_prompt(memory_summary, history, profile):
    system_instructions = (
        "You are Clario — a compassionate, evidence-informed mental health companion. "
        "Behave like a supportive therapist and best friend: validate feelings, ask clarifying questions. "
        "Speak in a warm, conversational tone, 3-6 sentences. "
        "Prioritize empathy. Do not suggest exercises immediately unless user shares details. "
        "If self-harm risk, direct user to professional help."
        "Use the following guidance:\n"
        "- Guilt/conflict → Empty Chair Technique\n"
        "- Anxiety → Grounding 5-4-3-2-1\n"
        "- Overwhelm → Breathing/journaling\n"
        "- Hopeless/self-critical → Gentle reframing/affirmations\n"
    )

    parts = [system_instructions]

    if profile:
        parts.append("User profile:\n" + json.dumps(profile, indent=2) + "\n")
    if memory_summary:
        parts.append("Memory summary:\n" + memory_summary + "\n")

    recent = history[-MAX_RECENT*2:] if history else []
    if recent:
        parts.append("Recent conversation:")
        for turn in recent:
            parts.append(f"{turn.get('role').upper()} ({turn.get('ts')}): {turn.get('text')}")
        parts.append("")

    parts.append("Now respond to the user's latest message empathetically.")
    return "\n".join(parts)

# ------------------ Generate AI Reply ------------------
def get_assistant_reply(memory_summary, history, user_message, profile):
    temp_history = history + [{"role": "user", "text": user_message, "ts": datetime.now(timezone.utc).isoformat()}]
    prompt = build_prompt(memory_summary, temp_history, profile)
    resp = client.models.generate_content(model=MODEL, contents=prompt)
    try:
        return resp.candidates[0].content.parts[0].text.strip()
    except Exception:
        return "Sorry, I couldn't generate a response right now."
