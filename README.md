# GreyMatter

EEG-adaptive learning platform — Flutter + EEG Device (Neurosity Crown).

Detects student attention drift in real time using the Neurosity Crown EEG headset. When drift is detected, an RL agent selects the best rescue intervention (flashcard, video, simulation, voice challenge, hand gesture game, curiosity bomb, or draw-it mode) to re-engage the student before they fall behind.

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

# Run on web (primary)
flutter run -d chrome

# Run on desktop
flutter run -d windows   # or -d macos

# Run on iPad (requires macOS + Xcode)
flutter run -d <your-ipad-udid>

# Run on Android
flutter run -d <your-device-id>
```

### Python daemon

```bash
cd daemon/
pip install -r requirements.txt
python attention_engine.py
# WebSocket server on ws://0.0.0.0:8765
```

## Hardware

Primary EEG device: **Neurosity Crown** (consumer dry-electrode headset).

- **EEG channels:** 8
- **Electrode positions (10–20 system):** CP3, C3, F5, PO3, PO4, F6, C4, CP4
- **Reference electrode:** T7
- **Bias (ground) electrode:** T8
- **Sample rate:** 256 Hz
- **Sensor type:** Flexible dry sensors, Silver / Silver Chloride (Ag/AgCl)
- **Noise floor:** 0.25 µVrms
- **Connectivity:** WiFi 802.11 ac/a/b/g/n, Bluetooth 4.2 / BLE
- **Data egress to our daemon:** OSC over UDP (port **9000**), consumed by BrainFlow's `BoardIds.CROWN_BOARD`. Requires "OSC enabled" in the Neurosity Developer Console and UDP:9000 open on the host firewall.

Channel → scalp region map:

| Channel | Region                  | Typical signal of interest    |
|---------|-------------------------|-------------------------------|
| F5      | Left frontal            | Executive function, focus     |
| F6      | Right frontal           | Executive function, focus     |
| C3      | Left central            | Motor / sensorimotor mu       |
| C4      | Right central           | Motor / sensorimotor mu       |
| CP3     | Left centroparietal     | Attention, P300               |
| CP4     | Right centroparietal    | Attention, P300               |
| PO3     | Left parieto-occipital  | Visual / spatial attention    |
| PO4     | Right parieto-occipital | Visual / spatial attention    |

The channel mapping is the adapter boundary for future EEG devices (Muse, OpenBCI, etc.). Any new device needs its own channel-index → named-position table before it can plug into the attention pipeline.

Source: [Neurosity Crown tech specs](https://neurosity.co/tech-specs).

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

- `lib/student/` — Student module, RL agent, interventions, HUD
- `lib/teacher/` — Teacher module, live monitor, session history, export
- `lib/core/` — Shared core layer (models, services, database)
- No imports between `student/` and `teacher/`.

## Branching

- `main` — always deployable, protected
- Feature branches for individual work
- PR required to merge to main
