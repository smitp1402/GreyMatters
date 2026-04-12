# NeuroLearn

## Project
EEG-adaptive learning Flutter app. Uses Neurosity Crown to detect student attention drift in real time and trigger RL-selected rescue interventions (flashcard, video, simulation, voice, gesture, curiosity bomb, draw-it).

## Module ownership
- `lib/student/`  → Smit (student module, RL agent, interventions, HUD)
- `lib/teacher/`  → Felipe (teacher module, live monitor, session history, export)
- `lib/core/`     → Joint (discuss before changing)
- `daemon/`       → Smit (Python EEG research daemon)

## Frozen interface — DO NOT modify without agreement from BOTH developers
- `lib/core/models/attention_state.dart` — AttentionState + AttentionLevel enum
- `lib/core/models/session.dart` — Session model
- `lib/core/services/attention_stream.dart` — broadcast stream + forSession() filter
- WebSocket JSON schema (daemon → Flutter)

## Tech stack
- Flutter 3.x / Dart — go_router, flutter_riverpod, drift (SQLite)
- Python 3.11 / BrainFlow — daemon research only (weeks 1-2)
- Supabase — deferred to Week 5 (cloud sync, not local)

## Platforms
Windows desktop (primary dev), macOS desktop, iPad (iOS), Android

## Architecture
- 5 layers: Crown hardware → Python daemon → WebSocket relay → Flutter app → SQLite (drift)
- Local-first: SQLite on-device for sessions, interventions, baselines
- Privacy: raw EEG never leaves the machine running the daemon
- One desktop = one Crown = one student = one session
- State management: Riverpod (ProviderScope wraps app in main.dart)

## Run commands
```
flutter pub get
dart run build_runner build
flutter run -d windows
```

## Database
SQLite via drift. Tables: sessions, interventions, baselines.
Supabase Postgres for anonymized cloud sync — Week 5, opt-in only.

## Key patterns
- Immutable data models (const constructors, final fields)
- AttentionStream singleton broadcasts to all subscribers
- WebSocketClient singleton with auto-reconnect
- Session namespacing via 6-char session_id
- RL agent: rule-based (1-5) → bandit (6-30) → DQN (30+)
