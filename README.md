# 🌙 Clario  

Clario is an **AI-powered reflection, journaling, and sleep wellness application** built with Flutter, Firebase, and Google Cloud.  
It combines emotional intelligence, journaling, sleep tracking, and personalized AI insights to promote mindfulness, emotional balance, and better sleep.  

---

## ✨ Features  

### 🪞 **Onboarding with Empty Chair**  
Guided self-reflection feature where users interact with an AI “Empty Chair” for perspective-taking and emotional clarity.  

### 📓 **Daily Journal & Reflection**  
- Users can write daily reflections.  
- Smart AI insights are generated for self-awareness.  
- Journals are saved securely in Firestore.  

### 😌 **Emotion Avatar System**  
- Avatars dynamically change based on mood and journal tone.  
- Avatar updates daily to match emotions and sleep wellness.  

### 💬 **MCP Server Chat – Sleep Wellness Agent**  
- A specialized AI chat agent for personalized sleep coaching and emotional support.  
- Integrated via the MCP protocol for real-time, multi-turn conversations.  

### 🌙 **Sleep Analysis with Gemini Integration**  
- AI processes user’s daily sleep data and generates a **7-day sleep report**.  
- Provides wellness suggestions, sleep score, and progress analysis.  

### 🔔 **Smart Notifications & Quotes**  
- Automated **daily quotes** and **journal prompts** delivered via Cloud Scheduler.  
- Personalized reminders for journaling and reflection.  

### 🧠 **Relation Mapping (Clario AI Twin)**  
- AI-based relationship insight engine for emotional connection tracking.  
- Links interactions and moods to people in your life.  

### 🗣️ **Voice-to-Voice & Multilingual AI**  
- Clario AI now supports **multilingual conversation**.  
- Natural **voice-based interaction** for an immersive reflection experience.  

### 🎵 **Sleep Sounds & Vibration Therapy**  
- Integrates relaxing sleep sounds for better rest.  
- Vibration cues aid relaxation during sleep tracking.  

### 👤 **AI-Generated Avatar (Mood-Based)**  
- Prompts the Gemini model to generate avatars that match the user’s **mood or emotion** from journal entries.  
- Avatar updates daily for a more personal experience.  

---

## 🧩 Tech Stack  

| Layer | Technologies Used |
|-------|--------------------|
| **Frontend** | Flutter, Dart |
| **Backend** | Firebase Authentication, Firestore, Cloud Functions (Python/Flask) |
| **AI Layer** | Gemini AI, Clario AI Twin (MCP-based), Sleep Wellness Agent |
| **Cloud** | Google Cloud Platform (GCP), Cloud Scheduler |
| **Other Integrations** | Vibration API, Sound Playback, Emotion Avatar Generator |

---

## 🏗️ Architecture Overview  

### 1. **Frontend (Flutter App)**  
- Onboarding, journaling UI, dashboards, and avatar rendering.  
- Integrates vibration, sound, and chat modules.  
- Connects to Firebase for authentication and Firestore for data storage.  

### 2. **Backend (Firebase + Cloud Functions)**  
- Handles AI requests, journal storage, and sleep data analysis.  
- Manages Cloud Scheduler for automated daily quotes.  

### 3. **AI Layer**  
- Gemini and Clario AI power journaling insights, mood detection, and sleep analysis.  
- MCP chat agent provides real-time sleep guidance.  

### 4. **Data Storage**  
- All user data, journals, sleep entries, and emotional states are securely stored in Firebase Firestore under the project’s main account.  

---

## 🚀 Getting Started  

### Prerequisites  
- Flutter SDK installed  
- Firebase CLI configured  
- Google Cloud SDK linked to your Firebase project  

### Setup  

1. Clone the repository:
   ```bash
   git clone https://github.com/Love-M-365/Clario
   cd clario




### APK Link 
https://drive.google.com/file/d/1tdGgzkBhJ-DrQob0h-M07UUJLX5BG37l/view?usp=sharing
