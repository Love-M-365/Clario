# analyze_journal.py
import os
import json
from datetime import datetime, timezone
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, auth, db as firebase_db
from google import genai

# ---------- CONFIG ----------
PROJECT_ID = os.environ.get("PROJECT_ID", "clario-f60b0")
LOCATION = os.environ.get("LOCATION", "us-central1")
MODEL = os.environ.get("MODEL", "gemini-2.5-flash")
RTDB_URL = os.environ.get("RTDB_URL", f"https://{PROJECT_ID}.firebaseio.com")

# ---------- Initialize Firebase Admin (Auth + RTDB) ----------
# Use Application Default Credentials when deployed to GCP.
if not firebase_admin._apps:
    cred = credentials.ApplicationDefault()
    # Provide databaseURL so firebase_admin.db works
    firebase_admin.initialize_app(cred, {"projectId": PROJECT_ID, "databaseURL": RTDB_URL})

# ---------- Initialize Gemini Client (Vertex AI GenAI wrapper) ----------
# Uses Application Default Credentials as well
client = genai.Client(vertexai=True, project=PROJECT_ID, location=LOCATION)

app = Flask(__name__)

# ---------- Helper: ask model to analyze journal ----------
def analyze_with_model(journal_text):
    """
    Instruct model to produce a small JSON object:
    { "mood_score": int(0-100), "mood_type": "sad|anxious|neutral|happy|angry|calm|mixed", "explanation": "..." }
    We'll parse the response strictly as JSON.
    """
    prompt = (
        "You are an emotion and mood analyzer. Read the user's full journal below and output a single JSON object "
        "with three keys exactly: mood_score (integer 0-100), mood_type (one-word tag like 'sad', 'anxious', 'neutral', 'happy', 'angry', 'calm', or 'mixed'), "
        "and explanation (one brief sentence). Do not output anything else. Keep explanation <= 40 words.\n\n"
        "Journal:\n"
        f"{journal_text}\n\n"
        "Output JSON only (no surrounding text). Example: {\"mood_score\": 42, \"mood_type\": \"sad\", \"explanation\": \"...\"}"
    )

    resp = client.models.generate_content(model=MODEL, contents=prompt)
    try:
        text = resp.candidates[0].content.parts[0].text.strip()
    except Exception:
        text = ""

    # Try to find first JSON object in output
    try:
        start = text.index("{")
        end = text.rindex("}") + 1
        json_text = text[start:end]
        parsed = json.loads(json_text)
    except Exception:
        # fallback: conservative default
        parsed = {
            "mood_score": 50,
            "mood_type": "neutral",
            "explanation": "I couldn't parse model output; defaulting to neutral."
        }

    # sanitize types
    try:
        parsed["mood_score"] = int(parsed.get("mood_score", 50))
        if parsed["mood_score"] < 0: parsed["mood_score"] = 0
        if parsed["mood_score"] > 100: parsed["mood_score"] = 100
    except Exception:
        parsed["mood_score"] = 50

    parsed["mood_type"] = str(parsed.get("mood_type", "neutral")).lower()
    parsed["explanation"] = str(parsed.get("explanation", "")).strip()

    return parsed

# ---------- Route: analyze journal ----------
@app.route("/analyze-journal", methods=["POST"])
def analyze_journal():
    """
    POST JSON body:
    {
      "journal_text": "<string>",          # required
      "uid": "<firebase uid (optional)>",  # optional if sending ID token
    }
    Optional header:
      Authorization: Bearer <firebase id token>
    """
    try:
        data = request.get_json(force=True)
        journal_text = (data or {}).get("journal_text", "")
        if not journal_text or not journal_text.strip():
            return jsonify({"error": "journal_text is required"}), 400

        uid = None

        # 1) Try to verify Authorization Bearer ID token if provided
        auth_header = request.headers.get("Authorization") or ""
        if auth_header.startswith("Bearer "):
            id_token = auth_header.split(" ", 1)[1]
            try:
                decoded = auth.verify_id_token(id_token)
                uid = decoded.get("uid")
            except Exception as e:
                # If token invalid, ignore and allow uid from body (if present)
                uid = None

        # 2) If no verified token, accept explicit uid from body (use with caution)
        if not uid:
            uid = (data or {}).get("uid")

        # 3) Call model to analyze journal
        model_out = analyze_with_model(journal_text)
        mood_score = model_out.get("mood_score", 50)
        mood_type = model_out.get("mood_type", "neutral")
        explanation = model_out.get("explanation", "")

        # 4) If uid known, save to Realtime DB under users/{uid}/journals
        saved_path = None
        if uid:
            try:
                # create a safe journal entry
                entry = {
                    "text": journal_text,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "moodScore": mood_score,
                    "moodTag": mood_type,
                    "explanation": explanation
                }
                ref = firebase_db.reference(f"users/{uid}/journals")
                new_ref = ref.push(entry)
                saved_path = new_ref.path
                
                user_ref = firebase_db.reference(f"users/{uid}")
                user_ref.update({
                    "latestMood": mood_type
                }) 
            except Exception as e:
                # don't fail whole response; include note
                saved_path = f"error_writing:{str(e)}"

        # 5) Return results
        resp = {
            "mood_score": mood_score,
            "mood_type": mood_type,
            "explanation": explanation,
            "saved_path": saved_path
        }
        return jsonify(resp), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# run locally (useful for testing)
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
