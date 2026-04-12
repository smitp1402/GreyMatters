# NeuroLearn

EEG-adaptive learning platform — Flutter + Neurosity Crown.

Detects student attention drift in real time using the Neurosity Crown EEG headset. When drift is detected, an RL agent selects the best rescue intervention (flashcard, video, simulation, voice challenge, hand gesture game, curiosity bomb, or draw-it mode) to re-engage the student before they fall behind.

## Team

| Developer | Module | Folder |
|-----------|--------|--------|
| Smit | Student module + EEG daemon | `lib/student/`, `daemon/` |
| Felipe | Teacher module | `lib/teacher/` |
| Joint | Core layer | `lib/core/` |

## Setup

### Prerequisites
- Flutter SDK >= 3.3.0
- Dart SDK (bundled with Flutter)
- Python 3.11+ (for EEG daemon only)

### Install and run

```bash
# Install Flutter dependencies
flutter pub get

# Generate drift database code
dart run build_runner build

# Run on desktop
flutter run -d windows   # or -d macos

# Run on iPad (requires macOS + Xcode)
flutter run -d <your-ipad-udid>

# Run on Android
flutter run -d <your-device-id>
```

### Python daemon (Smit only — weeks 1-2)

```bash
cd daemon/
pip install -r requirements.txt
python attention_engine.py
# WebSocket server on ws://0.0.0.0:8765
```

## Architecture

```
Crown (WiFi/OSC)
  |
Python daemon (BrainFlow → attention index → WebSocket)
  |
WebSocketClient (core/ — parses JSON → AttentionState)
  |
AttentionStream (core/ — broadcast)
  |
  +-- Student HUD + Intervention Engine (lib/student/)
  +-- Teacher Monitor (lib/teacher/)
  |
SQLite via drift (local persistence)
```

## Module boundaries

- `lib/student/` — Smit owns entirely. Felipe never touches.
- `lib/teacher/` — Felipe owns entirely. Smit never touches.
- `lib/core/` — Joint. Discuss before changing.
- No imports between `student/` and `teacher/`.

## Branching

- `main` — always deployable, protected
- `feature/smit/xxx` — Smit's feature branches
- `feature/felipe/xxx` — Felipe's feature branches
- PR required to merge to main
