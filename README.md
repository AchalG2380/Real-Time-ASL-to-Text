# CosmicSigns 🤝
### Real-Time ASL-to-Text Retail Communication System

> A tablet-based accessibility platform that enables seamless communication between deaf/hard-of-hearing individuals and retail staff — in both directions.

---

## Table of Contents
- [Overview](#overview)
- [The Problem](#the-problem)
- [Our Solution](#our-solution)
- [System Architecture](#system-architecture)
- [Features](#features)
- [Dual Display Framework](#dual-display-framework)
- [Admin Framework](#admin-framework)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Setup & Installation](#setup--installation)
- [ML Pipeline](#ml-pipeline)
- [API Reference](#api-reference)
- [Team](#team)

---

## Overview

SignBridge is a hackathon project built for the **36-hour accessibility hackathon**. It is a counter-mounted tablet application that uses on-device hand gesture recognition to translate American Sign Language (ASL) into readable text in real time — enabling deaf customers to communicate with retail staff, and deaf retail employees to communicate with customers.

---

## The Problem

Deaf and hard-of-hearing individuals face daily friction at retail counters, coffee shops, and service desks. Cashiers and staff rarely know ASL. This creates:
- Embarrassing communication breakdowns at the counter
- Exclusion of deaf individuals from behind-the-counter jobs
- Reliance on phone typing, which is slow and impractical in busy retail environments

---

## Our Solution

A dual-screen tablet system mounted at the counter. One screen faces the customer, one faces the staff. ASL signs are detected by the front-facing camera, converted to text in real time, and displayed on both screens simultaneously with translation, text-to-speech, and smart AI suggestions.

Critically — the system works **in both directions**. If the staff member is deaf, the screens flip and the customer signs instead.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        TABLET (On-Device)                       │
│                                                                 │
│  Camera Feed                                                    │
│      ↓                                                          │
│  MediaPipe Hand Landmarker (21 keypoints × 3 coords per hand)  │
│      ↓                                                          │
│  Keypoint Buffer (sliding window — 25 frames)                   │
│      ↓                                                          │
│  Gesture Classifier (TFLite model — trained on ASL dataset)    │
│      ↓                                                          │
│  Raw Sign Label → Sentence Formatter                            │
│      ↓                                                          │
│  Flutter UI ←──────────────────────────────────────────────    │
│  ┌─────────────────┐         ┌─────────────────┐               │
│  │  Input Window   │         │  Output Window  │               │
│  │  (Person A)     │         │  (Person B)     │               │
│  └─────────────────┘         └─────────────────┘               │
└─────────────────────────────────────────────────────────────────┘
          ↕ (online mode only)
┌─────────────────────────────────────────────────────────────────┐
│                     Cloud / Backend (Python)                    │
│                                                                 │
│  OpenRouter API (Gemini) — Smart Suggestions Engine             │
│  Google Translate API   — Bilingual translation (EN ↔ HI)      │
│  WebSocket Server       — Real-time sign streaming             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Features

### Core
- **Real-time ASL recognition** using on-device MediaPipe hand landmark tracking
- **Multi-frame gesture classification** — tracks movement across 25 frames, not just static poses
- **Sentence stitching** — individual signs are joined into coherent, human-friendly sentences
- **Bidirectional communication** — works for deaf customers AND deaf employees
- **Bilingual display** — English and Hindi, switchable mid-conversation via Google Translate API
- **Text-to-speech** — every chat bubble has a speaker button
- **Speech-to-text** — Person B can speak their reply instead of typing
- **Offline mode** — full core functionality with pre-defined suggestions, no internet needed
- **Online mode** — AI-powered smart suggestions via OpenRouter (Gemini)

### Smart Suggestions
- **Pre-defined suggestions** — set by the store administrator, specific to store type (retail, coffee shop, bakery, etc.)
- **Default suggestions** — built-in for when store type is not configured
- **Real-time predicted suggestions** — Gemini model receives the detected sign mid-signing and predicts the full intended sentence before the sign is complete
- **Contextual follow-up suggestions** — after a message is sent, 2–3 contextual completions appear (e.g. after "I need help" → "I need help with billing", "I need help with a return")

### Conversation
- Temporary session storage only — no conversation data is ever persisted
- Conversation resets on new session start
- Opening prompt: *"Hi! Please sign or type what you'd like to say."*
- Reply via keyboard pop-up or voice

---

## Dual Display Framework

The system has two distinct windows that always face opposite directions on the tablet.

### Input Window — Person A (the signer)
| Element | Description |
|---|---|
| Camera preview | Large, dominant view with live hand landmark overlay and bounding box |
| Real-time sign display | Current detected sign shown prominently on the camera feed |
| Suggestions bar | Pre-defined + AI smart suggestions, selectable with one tap |
| Chat window | Full conversation history with Person B |
| Keyboard | For typing instead of signing |
| View available items | Store inventory browser — customer can browse and add to cart |

### Output Window — Person B (the staff/cashier)
| Element | Description |
|---|---|
| Chat window | Full conversation with large, readable translated text |
| Camera thumbnail | Live feed from Person A's camera showing their signing |
| Suggestions bar | AI-generated reply suggestions based on conversation context |
| Keyboard | For typing replies |
| TTS button | Per-bubble speak-aloud button |
| Language toggle | Switch displayed language (EN / HI) |

### Window Switch
- Either person can be the signer — the system is not locked to one direction
- When switched, **both screens flip simultaneously** — the Input window becomes the Output window and vice versa
- Window switching is **only available from the Admin panel** — customers cannot switch it themselves

---

## Admin Framework

A separate administrator interface, accessible only on the designated admin device, that persists independently of window switches.

### Admin Authentication
- PIN or password protected
- Admin session persists separately from customer sessions

### Admin Settings
| Setting | Description |
|---|---|
| Window switch | Flip Input/Output orientation |
| Online / Offline toggle | Switch between AI-powered and offline-only mode |
| Store type | Select from dropdown (Retail, Coffee Shop, Bakery, etc.) or enter custom |
| Custom suggestions | Enter store-specific pre-defined suggestions for both windows |
| Font size | Adjust display text size for accessibility |
| Language default | Set default display language |

---

## Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| Hand tracking | MediaPipe Hand Landmarker | On-device 21-point hand skeleton extraction |
| Computer vision | OpenCV | Camera feed handling, frame processing |
| ML training | TensorFlow / Keras (Colab) | 1D-CNN gesture classifier training |
| On-device inference | TFLite | Lightweight model running locally on tablet |
| Backend | Python | Gesture pipeline, WebSocket server, API integration |
| Frontend | Flutter | Dual-screen tablet UI |
| Smart suggestions | OpenRouter API (Gemini) | AI-powered real-time sign predictions |
| Translation | Google Translate API | English ↔ Hindi (and other languages) |
| Deployment | Render | Backend API hosting (online mode) |

---

## Project Structure

```
Real-Time-ASL-to-Text/
├── asl_pipeline/                  # ML pipeline (Person 2)
│   ├── data/                      # Training data (numpy sequences)
│   │   ├── HELP/
│   │   ├── THANK_YOU/
│   │   ├── HOW_MUCH/
│   │   ├── BATHROOM/
│   │   ├── BAG/
│   │   ├── WANT/
│   │   ├── REPEAT/
│   │   └── HELLO/
│   ├── models/                    # Trained model files
│   │   ├── asl_model.h5
│   │   ├── asl_model.tflite
│   │   └── classes.npy
│   ├── utils.py                   # MediaPipe extraction, shared helpers
│   ├── collect_data.py            # Data collection tool
│   ├── train_model.py             # Model training script (run on Colab)
│   ├── inference.py               # Real-time inference + sentence stitching
│   ├── api.py                     # WebSocket + REST API server
│   ├── quick_test.py              # Camera + landmark verification
│   ├── hand_landmarker.task       # MediaPipe model binary
│   └── requirements.txt
│
├── backend/                       # Smart suggestions + translation (Person 3)
│   ├── suggestions.py             # OpenRouter/Gemini integration
│   ├── translation.py             # Google Translate integration
│   ├── inventory.py               # Store inventory + cart API
│   ├── offline_suggestions/       # Pre-defined suggestion JSON bundles
│   │   ├── default.json
│   │   ├── retail.json
│   │   ├── coffee_shop.json
│   │   └── bakery.json
│   └── main.py                    # FastAPI app entry point
│
├── flutter_app/                   # Frontend (Person 1)
│   ├── lib/
│   │   ├── screens/
│   │   │   ├── input_window.dart
│   │   │   ├── output_window.dart
│   │   │   └── admin_panel.dart
│   │   ├── widgets/
│   │   │   ├── camera_view.dart
│   │   │   ├── chat_bubble.dart
│   │   │   ├── suggestion_bar.dart
│   │   │   └── inventory_panel.dart
│   │   ├── services/
│   │   │   ├── websocket_service.dart
│   │   │   ├── tts_service.dart
│   │   │   └── translation_service.dart
│   │   └── main.dart
│   └── pubspec.yaml
│
├── colab/                         # Colab training notebook (Person 2)
│   └── train_asl_model.ipynb
│
└── README.md
```

---

## Setup & Installation

### Prerequisites
- Python 3.11 or 3.12
- Flutter SDK
- Git
- A webcam
- Google Colab account (for model training)

### Backend / ML Pipeline Setup

```bash
# Clone the repo
git clone https://github.com/YOUR_ORG/Real-Time-ASL-to-Text.git
cd Real-Time-ASL-to-Text/asl_pipeline

# Create and activate virtual environment
python -m venv venv

# Windows
venv\Scripts\activate
# Mac/Linux
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Verify Setup
```bash
python quick_test.py
```
You should see your webcam open with a green hand skeleton overlay.

### Collect Training Data
```bash
python collect_data.py
```
Follow on-screen prompts. Collect at least 40 samples per sign. Get multiple people to record for diversity.

### Train the Model (Google Colab)
1. Zip your `data/` folder and upload to Google Drive
2. Open `colab/train_asl_model.ipynb` in Colab
3. Set runtime to GPU (T4)
4. Run all cells
5. Download `models/` folder and place in `asl_pipeline/models/`

### Run the Backend
```bash
python api.py
# Server starts at http://localhost:8000
# WebSocket at ws://localhost:8000/ws
```

### Flutter App Setup
```bash
cd ../flutter_app
flutter pub get
flutter run
```

---

## ML Pipeline

### How Gesture Recognition Works

1. **Frame capture** — OpenCV reads webcam frames at ~30fps
2. **Landmark extraction** — MediaPipe Hand Landmarker detects 21 3D keypoints per hand
3. **Normalisation** — coordinates are made wrist-relative and scale-normalised so hand position and size on screen don't affect classification
4. **Frame buffer** — a rolling window of 25 frames of keypoints is maintained
5. **Sign boundary detection** — keypoint velocity is tracked; when velocity drops to near-zero, the classifier is triggered
6. **Classification** — a 1D-CNN model trained on labeled keypoint sequences predicts the sign
7. **Sentence formatting** — raw sign labels are mapped to human-friendly sentences
8. **Stitching** — signs within ~2 seconds of each other are joined into one sentence; a 3-second pause finalises the sentence

### Supported Signs (v1)
| ASL Sign | Output Sentence |
|---|---|
| HELP | "I need help" |
| THANK YOU | "Thank you!" |
| HOW MUCH | "How much does this cost?" |
| BATHROOM | "Where is the bathroom?" |
| BAG | "Can I get a bag?" |
| WANT | "I want this item" |
| REPEAT | "Could you say that again?" |
| HELLO | "Hello!" |

### Adding New Signs
The classifier is language-agnostic at the model level. To add a new sign:
1. Add the sign name to `SIGN_TO_SENTENCE` in `utils.py`
2. Create a folder for it in `data/`
3. Run `collect_data.py` and record samples
4. Retrain the model on Colab

### Adding New Sign Languages
The keypoint format from MediaPipe is identical regardless of sign language. To add ISL, BSL, etc.:
1. Collect labeled data for the new language's signs
2. Retrain with the new dataset
3. Set `sign_language` as a config parameter in admin settings

---

## API Reference

### WebSocket — `ws://localhost:8000/ws`
Streams real-time gesture state to the Flutter app at ~30fps.

**Emitted JSON:**
```json
{
  "sign_confirmed": "HELP",
  "confidence": 0.91,
  "sentence": "I need help",
  "current_phrase": "I need help",
  "finalized": "",
  "hand_detected": true,
  "buffer_fill": 25,
  "status": "signing",
  "velocity": 0.012,
  "sentence_history": []
}
```

### REST Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/status` | Health check, engine status |
| GET | `/signs` | List all supported signs and sentences |
| POST | `/suggest` | Get AI smart suggestions (online mode) |
| GET | `/inventory` | Get store inventory |
| POST | `/cart/add` | Add item to session cart |
| GET | `/suggestions/offline/{store_type}` | Get pre-defined suggestions for store type |

---

## Offline vs Online Mode

| Feature | Offline | Online |
|---|---|---|
| ASL recognition | ✅ Full | ✅ Full |
| Pre-defined suggestions | ✅ | ✅ |
| AI smart suggestions | ❌ | ✅ (Gemini via OpenRouter) |
| Contextual follow-ups | ❌ | ✅ |
| Translation (EN↔HI) | ✅ (pre-translated) | ✅ (Google Translate API) |
| Inventory browsing | ✅ (cached) | ✅ (live) |

---

## Team

| Person | Role |
|---|---|
| Person 1 | Flutter Frontend — dual-screen UI, camera overlay, chat, TTS, settings |
| Person 2 | ML Pipeline — MediaPipe, gesture classifier, inference, WebSocket API |
| Person 3 | Backend — OpenRouter/Gemini suggestions, Google Translate, inventory API |
| Person 4 | Integration & Demo — Flutter↔Python bridge, data collection, edge cases, demo prep |

---

## Hackathon Context

Built in **36 hours** for the accessibility hackathon.

**Anti-vibe coding constraints met:**
- ✅ On-device kinematics via MediaPipe (no cloud video APIs)
- ✅ Custom multi-frame gesture classification pipeline (25-frame 1D-CNN, not static poses)
- ✅ Continuous translation with sentence stitching
- ✅ Live demo of 8+ retail phrases

---

## Future Roadmap
- Add ISL (Indian Sign Language) support
- Larger sign vocabulary via community data collection
- iOS/Android tablet app packaging
- Dedicated admin tablet hardware setup

---

*Built with ❤️ for accessibility*
