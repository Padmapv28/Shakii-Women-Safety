# 🛡️ Shakti — Women's Safety App
### Built for Bengaluru | Offline-First | AI-Powered

---

## Architecture Overview

```
shakti_app/
├── lib/                        # Flutter frontend
│   ├── main.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── map_screen.dart
│   │   ├── sos_screen.dart
│   │   ├── guardian_screen.dart
│   │   └── chatbot_screen.dart
│   ├── services/
│   │   ├── sos_service.dart           # SOS + escalation logic
│   │   ├── location_service.dart      # GPS + geofencing
│   │   ├── activity_monitor.dart      # AI routine tracking
│   │   ├── voice_service.dart         # Speech recognition
│   │   ├── face_verify_service.dart   # Face recognition
│   │   ├── guardian_service.dart      # SMS + push notifications
│   │   ├── battery_service.dart       # Low battery alerts
│   │   └── offline_service.dart       # SQLite + sync queue
│   ├── models/
│   │   ├── guardian.dart
│   │   ├── safe_zone.dart
│   │   ├── alert.dart
│   │   └── activity_pattern.dart
│   └── widgets/
│       ├── sos_button.dart
│       └── risk_zone_overlay.dart
├── backend/
│   ├── src/
│   │   ├── routes/
│   │   │   ├── sos.ts
│   │   │   ├── zones.ts
│   │   │   ├── guardian.ts
│   │   │   └── activity.ts
│   │   ├── services/
│   │   │   ├── sms_service.ts
│   │   │   ├── push_service.ts
│   │   │   ├── ai_monitor.ts
│   │   │   └── media_upload.ts
│   │   └── models/
│   │       ├── User.ts
│   │       └── Zone.ts
│   └── functions/              # Firebase Cloud Functions
│       ├── sos_trigger.ts
│       └── activity_check.ts
└── assets/
    └── bengaluru_risk_zones.json   # Pre-seeded from CSV data
```

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile Frontend | Flutter 3.x (Dart) |
| State Management | Riverpod |
| Backend | Node.js + Express + Firebase |
| Database | Firestore + SQLite (offline) |
| Maps | Google Maps SDK |
| SMS | Twilio |
| Push | Firebase Cloud Messaging |
| Speech | Google Speech-to-Text |
| Face Verify | Google ML Kit |
| Activity AI | TensorFlow Lite (on-device) |
| Offline Sync | SQLite + WorkManager |

## Offline Capabilities
- All SOS data queued in SQLite when offline
- Last known location stored locally every 5 minutes
- Risk zone data cached locally (weekly refresh)
- SMS sent via device SIM (no internet needed)
- Voice trigger works fully offline (on-device model)
