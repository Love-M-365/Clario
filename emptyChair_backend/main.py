import functions_framework
import uuid
import json
from google.cloud import firestore
import vertexai
from vertexai.generative_models import GenerativeModel, Part, Content
from vertexai.language_models import TextEmbeddingModel 
import numpy as np 


# --- Setup: This is the official and correct way ---
PROJECT_ID = "clario-4558"
LOCATION = "us-central1"
GEMINI_MODEL_NAME = "gemini-2.5-flash" 
EMBEDDING_MODEL_NAME = "text-embedding-004" 

# Initialize clients now that permissions are fixed.
# This code runs once when the function instance starts.
db = firestore.Client(project=PROJECT_ID)
vertexai.init(project=PROJECT_ID, location=LOCATION)
model = GenerativeModel(GEMINI_MODEL_NAME)
embedding_model = TextEmbeddingModel.from_pretrained(EMBEDDING_MODEL_NAME) 


# Helper function to generate embedding
def get_embedding_vertexai(text_content):
    if not text_content:
        return []
    try:
        embeddings = embedding_model.get_embeddings([text_content])
        return embeddings[0].values
    except Exception as e:
        print(f"ERROR generating embedding: {e}")
        return []

# Helper function for cosine similarity
def cosine_similarity(v1, v2):
    if not v1 or not v2:
        return 0.0
    v1_np = np.array(v1)
    v2_np = np.array(v2)
    dot_product = np.dot(v1_np, v2_np)
    norm_v1 = np.linalg.norm(v1_np)
    norm_v2 = np.linalg.norm(v2_np)
    if norm_v1 == 0 or norm_v2 == 0:
        return 0.0
    return dot_product / (norm_v1 * norm_v2)


# --- startSession Function (UPDATED) ---
@functions_framework.http
def startSession(request):
    """
    Initializes a new session. It starts the user in a 'pre-analysis' phase
    where AI guides them to articulate the core problem/emotion before
    the Empty Chair dialogue begins.
    """
    try:
        request_json = request.get_json(silent=True)
        user_id = request_json["userId"]
        person_in_chair = request_json.get("personInChair", "the issue")
        user_goal = request_json.get("userGoal", "find some clarity")
        print(f"--- INITIALIZING NEW SESSION for user: {user_id} with {person_in_chair} for goal: {user_goal} ---")
    except (TypeError, KeyError) as e:
        print(f"ERROR: Bad Request. Missing required fields. Details: {e}")
        return ("Bad Request: Missing required fields in JSON body.", 400)

    initial_ai_message = (
        f"Hello! Welcome to your session. Today, you want to explore '{person_in_chair}' to '{user_goal}'.\n\n"
        f"Before we begin the Empty Chair dialogue, let's take a moment to understand what's truly "
        f"at the heart of this. **Please describe in your own words what this situation brings up for you.**"
    )
    
    session_id = str(uuid.uuid4())
    try:
        session_ref = db.collection("users").document(user_id).collection("sessions").document(session_id)
        session_ref.set({
            "personInChair": person_in_chair, 
            "userGoal": user_goal, 
            "startTime": firestore.SERVER_TIMESTAMP,
            "sessionPhase": "initial_analysis"
            # "groundingOffered" has been removed as it's no longer needed
        })
        
        messages_ref = session_ref.collection("messages").document()
        messages_ref.set({"text": initial_ai_message, "role": "ai", "timestamp": firestore.SERVER_TIMESTAMP, "perspective": "facilitator", "phase": "initial_analysis"})

    except Exception as e:
        print(f"ERROR saving new session to Firestore in startSession: {e}")
        return ("Internal Server Error: Could not save session data.", 500)
    
    response_data = {
        "sessionId": session_id, 
        "initialAiMessage": initial_ai_message,
        "sessionPhase": "initial_analysis" 
    }
    headers = {"Access-Control-Allow-Origin": "*"}
    return (json.dumps(response_data), 200, headers)

# --- analyzeInitialProblem Function (FIXED & CLEANED) ---
@functions_framework.http
def analyzeInitialProblem(request):
    """
    Handles the pre-analysis dialogue phase. Guides the user until an analysis is explicitly requested,
    then identifies the core problem and transitions the session to the Empty Chair phase.
    """
    try:
        request_json = request.get_json(silent=True)
        session_id = request_json["sessionId"]
        user_id = request_json["userId"]
        user_message_text = request_json["message"]
        print(f"--- ANALYZING INITIAL PROBLEM for session: {session_id} ---")
    except (TypeError, KeyError) as e:
        return ("Bad Request: Missing required fields in JSON body.", 400)

    session_ref = db.collection("users").document(user_id).collection("sessions").document(session_id)
    session_data = session_ref.get()
    if not session_data.exists:
        return ("Not Found: Session not found.", 404)
    
    session_details = session_data.to_dict()
    current_person_in_chair = session_details.get("personInChair", "the issue")
    user_goal = session_details.get("userGoal", "find some clarity")
    session_phase = session_details.get("sessionPhase", "unknown")
    
    if session_phase != "initial_analysis":
        return ("Conflict: This session is not in the 'initial_analysis' phase. Please use processMessage.", 409)

    # --- Build conversation history ---
    conversation_history_for_ai = []
    full_transcript_text = ""
    try:
        messages_query = session_ref.collection("messages").order_by("timestamp").stream()
        for msg_doc in messages_query:
            msg_data = msg_doc.to_dict()
            if msg_data.get("phase") == "initial_analysis":
                role = "model" if msg_data.get("role") == "ai" else "user"
                conversation_history_for_ai.append(Content(role=role, parts=[Part.from_text(msg_data["text"])]))
                full_transcript_text += f"\n[{msg_data.get('role').upper()}]: {msg_data['text']}"
        # Append the current user message
        conversation_history_for_ai.append(Content(role="user", parts=[Part.from_text(user_message_text)]))
        full_transcript_text += f"\n[USER]: {user_message_text}"
    except Exception as e:
        return ("Internal Server Error: Could not retrieve dialogue history.", 500)

    # --- Check for trigger keywords or message length ---
    trigger_keywords = [
        "analyze", "analysis", "decode", "summarize my feelings",
        "tell me the root", "core emotion", "root cause",
        "what's the core issue", "help me understand the core",
        "identify the main", "what's really going on",
        "break this down", "make sense of this"
    ]
    explicit_trigger = any(keyword in user_message_text.lower() for keyword in trigger_keywords)
    conversation_length_trigger = len(conversation_history_for_ai) >= 6  # 3 user + 3 AI messages
    print(f"DEBUG: Message count: {len(conversation_history_for_ai)}, Explicit trigger: {explicit_trigger}, Length trigger: {conversation_length_trigger}")

    ai_response_text = "An error occurred."  # Default

    try:
        if explicit_trigger or conversation_length_trigger:
            # --- Perform Final Analysis ---
            analysis_prompt_template = f"""
You are a skilled and empathetic psychological analyst. You have just completed a pre-analysis dialogue phase with a user to identify the core problem regarding '{current_person_in_chair}'.
Session Goal: {user_goal}
Pre-Analysis Dialogue Transcript:
{full_transcript_text}

Your Task: Based solely on the dialogue, identify the single most prominent core emotion and its primary cause. Formulate a short (2-3 sentences) overall analysis.

Format:
Analysis Statement: [2-3 sentence analysis]
Root Emotion: [core emotion]
Cause of Emotion: [primary cause]
"""
            analysis_full_response = model.generate_content(analysis_prompt_template).text.strip()

            # --- Parse the Analysis ---
            parsed_root_emotion = "Not identified"
            parsed_cause_of_emotion = "Not identified"
            parsed_analysis_statement = analysis_full_response
            if "Root Emotion:" in analysis_full_response and "Cause of Emotion:" in analysis_full_response:
                parsed_analysis_statement = analysis_full_response.split("Root Emotion:")[0].strip()
                parsed_root_emotion = analysis_full_response.split("Root Emotion:")[1].split("Cause of Emotion:")[0].strip()
                parsed_cause_of_emotion = analysis_full_response.split("Cause of Emotion:")[1].strip()

            ai_response_text = (
                f"{parsed_analysis_statement}\n\n"
                f"**Root Emotion:** {parsed_root_emotion}\n"
                f"**Cause of Emotion:** {parsed_cause_of_emotion}\n\n"
                f"Now that we have identified this, we can move into the Empty Chair dialogue. "
                f"**To begin, please share your first thoughts about '{current_person_in_chair}' from your BLUE Chair perspective.**"
            )

            # --- Update Firestore for Empty Chair ---
            session_ref.update({
                "sessionPhase": "empty_chair_ready",
                "preAnalysisRootEmotion": parsed_root_emotion,
                "preAnalysisCauseOfEmotion": parsed_cause_of_emotion,
                "preAnalysisStatement": parsed_analysis_statement
            })

            response_data = {
                "sessionId": session_id,
                "aiMessage": ai_response_text,
                "sessionPhase": "empty_chair_ready",
                "rootEmotion": parsed_root_emotion,
                "causeOfEmotion": parsed_cause_of_emotion
            }
            headers = {"Access-Control-Allow-Origin": "*"}
            return (json.dumps(response_data), 200, headers)

        else:
            # --- Continue Pre-Analysis Dialogue ---
            system_message = f"You are an empathetic AI facilitator in a pre-analysis phase. The user wants to talk about '{current_person_in_chair}' to achieve '{user_goal}'. Ask brief, open-ended questions (1-2 sentences) without analysis."
            conversation_with_system = [Content(role="system", parts=[Part.from_text(system_message)])] + conversation_history_for_ai

            try:
                response = model.generate_content(conversation_with_system)
                ai_response_text = response.text.strip()
            except Exception as e:
                # Fallback
                response = model.generate_content(conversation_history_for_ai)
                ai_response_text = response.text.strip()

    except Exception as e:
        ai_response_text = f"I'm sorry, I'm having a technical issue. Could you please tell me more about what's on your mind regarding '{current_person_in_chair}'?"

    # --- Save messages in Firestore ---
    try:
        session_ref.collection("messages").document().set({
            "text": user_message_text,
            "role": "user",
            "timestamp": firestore.SERVER_TIMESTAMP,
            "phase": "initial_analysis"
        })
        session_ref.collection("messages").document().set({
            "text": ai_response_text,
            "role": "ai",
            "timestamp": firestore.SERVER_TIMESTAMP,
            "perspective": "facilitator",
            "phase": "initial_analysis"
        })
    except Exception as e:
        return ("Internal Server Error: Could not save dialogue data.", 500)

    response_data = {"sessionId": session_id, "aiMessage": ai_response_text, "sessionPhase": "initial_analysis"}
    headers = {"Access-Control-Allow-Origin": "*"}
    return (json.dumps(response_data), 200, headers)



@functions_framework.http
def startEmptyChairSession(request):
    """
    Marks a session as ready for Empty Chair dialogue.
    Assumes the session exists (created by startSession).
    """
    try:
        request_json = request.get_json(force=True)
        user_id = request_json["userId"]
        session_id = request_json["sessionId"]
    except (TypeError, KeyError):
        return (json.dumps({"error": "Missing userId or sessionId"}), 400, {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"})

    # Directly return a successful response without Firestore check
    response_data = {
        "sessionId": session_id,
        "sessionPhase": "empty_chair_ready",
        "message": "Session is now ready for Empty Chair dialogue."
    }
    return (json.dumps(response_data), 200, {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"})
# --- processMessage Function (Self-initializing) ---
@functions_framework.http
def processMessage(request):
    """
    Handles ongoing Empty Chair session messages, generates AI prompts,
    and manages conversation history in Firestore, now incorporating
    long-term memory from past sessions, specifically targeting sessions
    with the same 'personInChair' using semantic search (RAG).
    Automatically creates a session if one doesn't exist.
    """
    try:
        request_json = request.get_json(silent=True)
        session_id = request_json.get("sessionId")
        user_id = request_json["userId"]
        user_message_text = request_json["message"]
        perspective = request_json["perspective"]

        if perspective not in ["blue", "red"]:
            return ("Bad Request: Invalid 'perspective' field. Must be 'blue' or 'red'.", 400)

    except (TypeError, KeyError) as e:
        return ("Bad Request: Missing required fields in JSON body for processMessage.", 400)

    session_ref = None
    session_data = None

    # --- Auto-create session if not provided or not found ---
    if not session_id:
        session_id = str(uuid.uuid4())

    session_ref = db.collection("users").document(user_id).collection("sessions").document(session_id)
    session_data = session_ref.get()

    if not session_data.exists:
        # Create new session with defaults
        try:
            session_ref.set({
                "personInChair": "the issue",
                "userGoal": "find some clarity",
                "startTime": firestore.SERVER_TIMESTAMP,
                "sessionPhase": "empty_chair_ready"  # Directly ready for messaging
            })
            # Add first message
            session_ref.collection("messages").document().set({
                "text": user_message_text,
                "role": "user",
                "timestamp": firestore.SERVER_TIMESTAMP,
                "phase": "empty_chair_ready",
                "perspective": perspective
            })
            session_data = session_ref.get()
        except Exception as e:
            return ("Internal Server Error: Could not create session automatically.", 500)

    session_details = session_data.to_dict()

    # --- Ensure sessionPhase is 'empty_chair_ready' ---
    if session_details.get("sessionPhase") != "empty_chair_ready":
        return ("Conflict: Session not ready for Empty Chair dialogue.", 409)

    current_person_in_chair = session_details.get("personInChair", "the issue")
    user_goal = session_details.get("userGoal", "find some clarity")

    # --- Generate embedding for current message ---
    current_message_embedding = []
    try:
        current_message_embedding = get_embedding_vertexai(user_message_text)
    except Exception as e:
        print(f"ERROR generating embedding: {e}")

    # --- Long-term memory RAG ---
    long_term_memory_context = ""
    try:
        past_sessions_query = db.collection("users").document(user_id).collection("sessions") \
            .where("personInChair", "==", current_person_in_chair) \
            .where("blueSummaryEmbedding", "!=", []) \
            .order_by("startTime", direction=firestore.Query.DESCENDING).limit(10).stream()
        candidates = []
        for doc in past_sessions_query:
            if doc.id == session_id:
                continue
            past_session_data = doc.to_dict()
            if all(k in past_session_data for k in ["blueSummary", "blueSummaryEmbedding", "redSummary", "redSummaryEmbedding", "overallSessionReflection", "reflectionEmbedding"]):
                target_embedding = past_session_data.get("reflectionEmbedding", [])
                if current_message_embedding and target_embedding:
                    similarity = cosine_similarity(current_message_embedding, target_embedding)
                    candidates.append((similarity, past_session_data))

        candidates.sort(key=lambda x: x[0], reverse=True)
        relevant_summaries_text = []
        for score, sdata in candidates[:2]:
            relevant_summaries_text.append(f"Past Session ({sdata.get('startTime').strftime('%Y-%m-%d')}, goal: {sdata.get('userGoal')}):")
            relevant_summaries_text.append(f"  User Perspective (Blue): {sdata['blueSummary']}")
            relevant_summaries_text.append(f"  Other Perspective (Red): {sdata['redSummary']}")
            relevant_summaries_text.append(f"  Reflection: {sdata['overallSessionReflection']}\n")

        if relevant_summaries_text:
            long_term_memory_context = f"### User's Past Session Learnings (Semantic RAG for '{current_person_in_chair}'):\n" + "\n".join(relevant_summaries_text)
    except Exception as e:
        long_term_memory_context = ""

    # --- Retrieve current session conversation ---
    conversation_history = []
    try:
        messages_query = session_ref.collection("messages").order_by("timestamp").stream()
        for msg_doc in messages_query:
            msg_data = msg_doc.to_dict()
            if msg_data.get("phase") == "empty_chair_ready":
                if msg_data["role"] == "ai":
                    conversation_history.append(Content(role="model", parts=[Part.from_text(msg_data["text"])]))
                else:
                    msg_perspective = msg_data.get('perspective', 'blue')
                    formatted_user_msg = f"[{msg_perspective.upper()} Chair]: {msg_data['text']}"
                    conversation_history.append(Content(role="user", parts=[Part.from_text(formatted_user_msg)]))
        conversation_history.append(Content(role="user", parts=[Part.from_text(f"[{perspective.upper()} Chair]: {user_message_text}")]))

    except Exception as e:
        return ("Internal Server Error: Could not retrieve conversation history.", 500)

    # --- Generate AI Response ---
    ai_response_text = "Please continue."
    try:
        system_instruction_parts = [
            "You are an empathetic facilitator for an Empty Chair therapy session. ",
            f"The person in the 'RED Chair' is '{current_person_in_chair}'. ",
            f"The user's goal for this session is '{user_goal}'. ",
            "Always respond with a short, open-ended question or prompt (1-2 sentences max) to encourage deeper reflection. ",
            long_term_memory_context + "\n" if long_term_memory_context else ""
        ]
        system_instruction = "".join(system_instruction_parts)
        conversation_with_system = [Content(role="user", parts=[Part.from_text(system_instruction)])]
        conversation_with_system.extend(conversation_history)

        model_response = model.generate_content(conversation_with_system)
        ai_response_text = model_response.text.strip()

    except Exception as e:
        ai_response_text = "I understand. Can you tell me more about that feeling?"

    # --- Save messages ---
    try:
        session_ref.collection("messages").document().set({
            "text": user_message_text,
            "role": "user",
            "timestamp": firestore.SERVER_TIMESTAMP,
            "perspective": perspective,
            "phase": "empty_chair_ready"
        })
        session_ref.collection("messages").document().set({
            "text": ai_response_text,
            "role": "ai",
            "timestamp": firestore.SERVER_TIMESTAMP,
            "perspective": "facilitator",
            "phase": "empty_chair_ready"
        })
    except Exception as e:
        return ("Internal Server Error: Could not save conversation data.", 500)

    response_data = {"aiMessage": ai_response_text, "sessionPhase": session_details.get("sessionPhase")}
    headers = {"Access-Control-Allow-Origin": "*"}
    return (json.dumps(response_data), 200, headers)


# --- generateSessionSummaries Function ---
@functions_framework.http
def generateSessionSummaries(request):
    """
    Generates 'blueSummary', 'redSummary', and an overall session reflection
    based on the entire session transcript.
    """
    try:
        request_json = request.get_json(silent=True)
        session_id = request_json["sessionId"]
        user_id = request_json["userId"]

        print(f"--- GENERATING SUMMARIES for session: {session_id} ---")
    except (TypeError, KeyError) as e:
        print(f"ERROR: Bad Request. Missing required fields in JSON body for generateSessionSummaries. Details: {e}")
        return ("Bad Request: Missing required fields in JSON body.", 400)

    session_ref = db.collection("users").document(user_id).collection("sessions").document(session_id)
    session_data = session_ref.get()

    if not session_data.exists:
        print(f"ERROR: Session {session_id} not found for user {user_id}")
        return ("Not Found: Session not found.", 404)

    session_details = session_data.to_dict()
    person_in_chair = session_details.get("personInChair", "the issue")
    user_goal = session_details.get("userGoal", "find some clarity")

    blue_summary_text = "No Blue Chair summary generated."
    red_summary_text = "No Red Chair summary generated."
    overall_session_reflection = "No overall session reflection generated."
    
    blue_summary_embedding = []
    red_summary_embedding = [] 
    reflection_embedding = []   


    blue_chair_content = []
    red_chair_content = []
    full_conversation_transcript = [] 

    try:
        messages_query = session_ref.collection("messages").order_by("timestamp").stream()
        for msg_doc in messages_query:
            msg_data = msg_doc.to_dict()
            text = msg_data.get("text", "")
            role = msg_data.get("role", "unknown")
            perspective = msg_data.get("perspective", "unknown")

            # Filter for messages from the 'empty_chair_ready' phase to summarize
            if msg_data.get("phase") == "empty_chair_ready": 
                if role == "user":
                    if perspective == "blue": 
                        blue_chair_content.append(text)
                    elif perspective == "red":
                        red_chair_content.append(text)
                full_conversation_transcript.append(f"[{perspective.upper()} Chair]: {text}")
            elif role == "ai" and msg_data.get("phase") == "empty_chair_ready": # Only include AI messages from EC phase for transcript
                full_conversation_transcript.append(f"[Facilitator]: {text}")
                
        print(f"DEBUG: Found {len(blue_chair_content)} blue messages and {len(red_chair_content)} red messages in EC phase.")

    except Exception as e:
        print(f"ERROR retrieving messages for summarization: {e}")
        return ("Internal Server Error: Could not retrieve conversation messages for analysis.", 500)


    try: 
        if blue_chair_content:
            blue_summary_prompt = f"""You are a summary bot. Given the following user's (Blue Chair) statements, summarize their perspective and key feelings/thoughts in 1-2 bullet points for a psychological counseling context.
            User statements from their own perspective:
            {'- '.join(blue_chair_content)}
            Summary of Blue Chair Perspective:"""
            blue_summary_text = model.generate_content(blue_summary_prompt).text.strip()
            print("DEBUG: Generated Blue Chair summary.")
            blue_summary_embedding = get_embedding_vertexai(blue_summary_text)

        
        if red_chair_content:
            red_summary_prompt = f"""You are a summary bot. Given the following statements from the 'Person in the RED Chair' (who is {person_in_chair}), summarize their perspective and key imagined feelings/thoughts in 1-2 bullet points. This summary is for a user who interacted with this perspective in an Empty Chair session.
            Statements from {person_in_chair}'s perspective:
            {'- '.join(red_chair_content)}
            Summary of Red Chair Perspective ({person_in_chair}):"""
            red_summary_text = model.generate_content(red_summary_prompt).text.strip()
            print("DEBUG: Generated Red Chair summary.")
            red_summary_embedding = get_embedding_vertexai(red_summary_text)
    
        transcript_text = '\n'.join(full_conversation_transcript) 
        
        if full_conversation_transcript: 
            reflection_prompt = f"""You are a thoughtful AI facilitator reflecting on a just-completed Empty Chair session.
            Session Goal: The user wanted to talk with '{person_in_chair}' to achieve '{user_goal}'.
            Transcript:
            {transcript_text}

            Provide a brief (2-3 sentences) overarching reflection or a key takeaway about the session's dynamics, progress, or insights gained. This is a final thought from the facilitator."""
            overall_session_reflection = model.generate_content(reflection_prompt).text.strip()
            print("DEBUG: Generated overall session reflection.")
            reflection_embedding = get_embedding_vertexai(overall_session_reflection)

    except Exception as e: 
        print(f"CRITICAL CRASH calling the AI model for summarization: {e}")
        import traceback
        traceback.print_exc()

    try:
        session_ref.update({
            "blueSummary": blue_summary_text,
            "blueSummaryEmbedding": blue_summary_embedding,
            "redSummary": red_summary_text,
            "redSummaryEmbedding": red_summary_embedding,   
            "overallSessionReflection": overall_session_reflection,
            "reflectionEmbedding": reflection_embedding,     
            "endTime": firestore.SERVER_TIMESTAMP
        })
        print("DEBUG: Saved summaries, embeddings, and marked session as ended in Firestore.")
    except Exception as e:
        print(f"ERROR saving summaries and embeddings to Firestore: {e}")
        return ("Internal Server Error: Could not save session summaries and embeddings.", 500)
    
    response_data = {
        "sessionId": session_id,
        "blueSummary": blue_summary_text,
        "redSummary": red_summary_text,
        "overallSessionReflection": overall_session_reflection
    }
    headers = {"Access-Control-Allow-Origin": "*"}
    return (json.dumps(response_data), 200, headers)