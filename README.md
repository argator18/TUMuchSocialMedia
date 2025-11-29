
# Project Name

**A FastAPI backend for app usage supervision and context-aware permission management.**

> ⚠️ This project is based on [FastAPI-Backend-Template](https://github.com/Aeternalis-Ingenium/FastAPI-Backend-Template). For detailed explanations of core FastAPI functionalities, project structure, or common patterns not covered here, please refer to the original template repository.

---

## Overview

Backend service for:

- User onboarding with app usage restrictions.
- App permission decisions using a context-aware agent.
- Voice transcription via OpenAI Whisper.
- Supervision of structured events with optional screenshots.
- Daily usage tracking.

Frontend is implemented in **Flutter** and runs on **Android**.

---

## Tech Stack

- Python 3.11+
- FastAPI
- Pydantic
- Uvicorn
- Pandas
- OpenAI API
- Flutter (Android frontend)

---

## Getting Started

### Backend
```bash
git clone git@github.com:argator18/TUMuchSocialMedia.git
cd TUMuchSocialMedia/backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
````

make a `.env` from the `.env.example` and add to the  `.env`:

```
OPENAI_API_KEY=your_openai_api_key
API_BASE=http://localhost:8000
```

Run the server:

```bash
uvicorn main:backend_app --reload --host 0.0.0.0 --port 8000
# actually you can execute from the backend folder this
uvicorn src.main:backend_app --host 0.0.0.0 --port 8000 --reload
```

---

## API Endpoints (short)

* **POST `/echo`**: ask agent for app permission.
* **GET `/todays_count?user_id=...`**: get today's request count.
* **POST `/onboard`**: create a new user with preferences.
* **POST `/voice`**: upload audio for transcription and permission.
* **POST `/supervise`**: send structured events + optional screenshot.

---

## Usage

* Mobile app sends **app usage**, **events**, **voice**, and optional screenshots.
* Agent makes **permission decisions** based on configured restrictions.
* Daily usage data can be retrieved for analytics.


