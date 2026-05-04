# Shakii-Women-Safety
Shakii Women Safety 🛡️
A full-stack women's safety application with a Flutter mobile frontend and a Node.js/TypeScript backend, designed to empower women with real-time safety tools and emergency response features.
---
📁 Project Structure
```
Shakii-Women-Safety/
│
├── shakti_app/                  # 📱 Flutter Mobile App (Frontend)
│   ├── android/                 # Android build configuration
│   ├── assets/                  # Images, icons, fonts
│   ├── backend/                 # API integration layer
│   ├── lib/                     # Dart source code (screens, widgets, logic)
│   └── pubspec.yaml             # Flutter dependencies
│
└── Safe-Travel-Companion/       # 🖥️ Node.js/TypeScript Server (Backend)
    ├── .agents/                 # AI agent configurations
    ├── artifacts/               # Build output
    ├── attached_assets/         # Uploaded media/assets
    ├── lib/                     # Shared backend libraries
    ├── scripts/                 # Automation and utility scripts
    ├── package.json             # Node.js dependencies
    ├── tsconfig.json            # TypeScript config
    ├── pnpm-workspace.yaml      # Workspace/monorepo config
    └── README.md                # Backend-specific notes
```
---
✨ Features
🆘 Emergency SOS — Instantly alert trusted contacts with your live location
📍 Real-time Location Sharing — Share location with family and friends
🗺️ Safe Travel Companion — AI-powered route safety analysis
📞 Quick Dial — One-tap emergency contacts and helplines
🔔 Background Alerts — Protection even when the app is minimized
🤖 AI Safety Assistant — Smart guidance and safety recommendations
---
🛠️ Tech Stack
Layer	Technology
Mobile Frontend	Flutter (Dart)
Backend Server	Node.js + TypeScript
Package Manager	pnpm
Platform	Android (iOS planned)
Hosting	Replit
---
🚀 Getting Started
Prerequisites
Flutter SDK >= 3.x
Node.js >= 18.x
pnpm — install via `npm install -g pnpm`
Android Studio or VS Code with Flutter + Dart extensions
---
1. Clone the Repository
```bash
git clone https://github.com/Padmapv28/Shakii-Women-Safety.git
cd Shakii-Women-Safety
```
---
2. Start the Backend
```bash
cd Safe-Travel-Companion
pnpm install
pnpm run dev
```
Backend runs at `http://localhost:3000` (or as configured in `.replit`).
---
3. Run the Flutter App
```bash
cd shakti_app
flutter pub get
flutter run
```
Make sure an Android emulator is running or a device is connected.
---
🌐 API Overview
The Flutter app communicates with the Node.js backend for:
User authentication
Location data processing
SOS alert dispatch
AI safety recommendations
---
📱 Screenshots
> _Add app screenshots here_
---
🤝 Contributing
Fork the repository
Create your feature branch (`git checkout -b feature/YourFeature`)
Commit your changes (`git commit -m 'Add YourFeature'`)
Push to the branch (`git push origin feature/YourFeature`)
Open a Pull Request
---
📄 License
This project is licensed under the MIT License.
---
👩‍💻 Author
Padmapv28 — github.com/Padmapv28
---
> _Built with ❤️ to make eve
