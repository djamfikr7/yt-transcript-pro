# YouTube Transcript & Translate Pro

A unified desktop and web application for AI-powered YouTube transcription, translation, and dubbing with a stunning neomorphic UI.

## 🎯 Features

- **Intelligent Transcription**: Powered by Whisper AI with speaker diarization
- **Multi-Language Translation**: 50+ languages with context-aware translation
- **AI Dubbing**: Voice synthesis and video assembly
- **Neomorphic UI**: Beautiful glassmorphic design for web and mobile
- **Local-First**: All processing happens on your device

## 🏗️ Architecture

- **Frontend**: Flutter (Web, Android, iOS)
- **Backend**: Python FastAPI
- **AI Models**: Whisper, Pyannote, Coqui TTS

## 🚀 Quick Start

### Frontend (Flutter)
```bash
cd yt_transcript_pro
flutter pub get
flutter run -d chrome  # For web
flutter run             # For mobile
```

### Backend (Python)
```bash
cd backend
pip install -r requirements.txt
python main.py
```

## 📦 Project Structure

```
YT01/
├── yt_transcript_pro/     # Flutter frontend
│   ├── lib/
│   │   ├── screens/       # UI screens
│   │   ├── widgets/       # Custom widgets
│   │   └── theme/         # Design system
├── backend/               # Python backend
│   ├── main.py           # FastAPI server
│   └── requirements.txt
└── README.md
```

## 🎨 Design System

Based on neomorphic design principles with:
- Soft shadows and gradients
- Glassmorphism effects
- Smooth animations
- Dark/Light mode support

## 📄 License

Educational and personal use only. See PRD for legal compliance guidelines.
