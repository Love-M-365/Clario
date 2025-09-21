# Clario

Clario is an AI-powered reflection and journaling application built with Flutter, Firebase, and Google Cloud. It combines guided self-reflection, journaling, emotional awareness, and relationship insights to support personal growth.

---

## Features

- **Onboarding with Empty Chair**  
  Guided reflection feature where users interact with an AI "empty chair" for perspective-taking exercises.

- **Journal Reflections**  
  - Save reflections to Firebase Firestore.  
  - View journal history in an organized timeline.

- **Emotion Avatar System**  
  AI-driven avatars display emotions based on user reflections and interactions.

- **Notifications**  
  Smart reminders to encourage consistent journaling and reflection practices.

- **Relation Mapping**  
  Visualize and map personal relationships to better understand patterns and dynamics.

- **AI Integration**  
  - Uses Google GenAI for natural language understanding and responses.  
  - Cloud Functions (Flask) handle AI requests and processing.

---

## Tech Stack

- **Frontend:** Flutter, Dart  
- **Backend:** Firebase Authentication, Firestore, Firebase Cloud Functions (Python/Flask)  
- **AI:** Google GenAI API  
- **Cloud:** Google Cloud Platform (GCP)

---

## Architecture Overview

1. **Frontend (Flutter App)**  
   - Onboarding, journaling UI, dashboards, and emotion avatars.  
   - Connects to Firebase for authentication and Firestore for data storage.  

2. **Backend (Cloud Functions + Firebase)**  
   - Cloud Functions process AI requests and responses.  
   - Firestore stores journals, relationships, and user metadata.  

3. **AI Layer**  
   - Google GenAI provides conversational intelligence for Empty Chair, journaling analysis, and emotion detection.  

---

## Getting Started

### Prerequisites
- Flutter SDK installed  
- Firebase CLI installed and configured  
- Google Cloud SDK configured with a valid project  

### Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/Love-M-365/Clario
   cd clario
