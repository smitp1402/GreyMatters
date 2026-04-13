# NeuroLearn — Project Plan

> Generated from PRD review on 2026-04-12

## 1. Product Overview

### Vision
NeuroLearn is an EEG-adaptive learning platform that monitors a student's real-time brain activity through the Neurosity Crown headset and automatically intervenes when cognitive drift is detected. Unlike conventional adaptive learning systems that rely on behavioral proxies (quiz scores, click patterns), NeuroLearn uses the actual neural signal — band power ratios from frontal EEG channels — as both the drift detector and the reinforcement learning reward. A teacher can monitor any student's focus state live from a separate device using a session code, without ever accessing raw brain data.

### Target Users
- **Students** — K-12 and university STEM students who want to learn more effectively. Have a Neurosity Crown. Use Windows desktop or iPad.
- **Teachers/Tutors** — Monitor a student's live focus state from a separate device. Want real-time visibility into engagement without accessing raw brain signals.
- **Researchers** (future) — Education researchers wanting objective EEG-based attention data correlated with learning outcomes.

### Key Outcomes
- Detect attention drift within 8 seconds using real-time EEG (not quiz scores)
- Deploy RL agent whose reward signal is the brain's own recovery response
- Learn which intervention format works best per individual student across sessions
- Give teachers live neural-level engagement data without exposing raw brain signals
- Run 100% on-device — raw EEG never leaves the student's machine

---

## 2. Requirements Summary

### Functional Requirements

| ID | Domain | Requirement | Priority |
|----|--------|-------------|----------|
| FR-01 | EEG Daemon | Python daemon connects to Crown via BrainFlow, computes band powers (theta/alpha/beta/gamma) via Welch PSD on F5/F6, calculates attention index = (theta+alpha)/beta normalized against baseline, classifies focused/drifting/lost with 2-window hysteresis, emits AttentionState JSON every 1s over WebSocket :8765 | Must-have |
| FR-02 | EEG Daemon | Mock daemon mode generating realistic synthetic EEG patterns (drift cycles, recovery, natural variation) for testing without Crown | Must-have |
| FR-03 | Session | Session start: Crown signal quality check → 30s baseline calibration → session ID generation (6-char) → session code display | Must-have |
| FR-04 | Session | Session end: summary screen (duration, avg focus, intervention count, most effective format, color-coded focus timeline). Saved to SQLite. | Must-have |
| FR-05 | Session | Session code sharing: student sees code, teacher enters code to subscribe to live stream | Must-have |
| FR-06 | Lesson | Full-screen lesson content renderer: dense text, static diagrams, embedded video. Intentionally low-stimulation design (white background, serif font). | Must-have |
| FR-07 | Lesson | Curriculum content for Periodic Table (primary demo topic) with real educational text, diagrams, and video links. 3 other topics as placeholders. | Must-have |
| FR-08 | Lesson | Pacing engine: content advances while focused, pauses on drift/lost, resumes from exact pause point after recovery | Must-have |
| FR-09 | HUD | Live focus HUD: bottom strip with focus score gauge + theta/alpha/beta/gamma band power bars, updating every 1s | Must-have |
| FR-10 | Intervention | Intervention engine: on drift/lost, pause content, query RL agent for format, launch intervention, measure EEG 60s post, compute reward, update policy | Must-have |
| FR-11 | Intervention | Simulation: drag-and-drop interactive (Chem: drag electrons; Bio: drag organelles) | Must-have |
| FR-12 | Intervention | Gesture: hand gesture recognition via Python MediaPipe subprocess on WS :8766 (hold up fingers = answer count, point to element) | Must-have |
| FR-13 | Intervention | Flashcard: swipeable 5-card deck per topic with active recall questions | Must-have |
| FR-14 | Intervention | Voice challenge: TTS speaks question, speech_to_text captures answer, fuzzy match check. Typed text fallback. | Must-have |
| FR-15 | Intervention | Curiosity bomb: full-screen surprising fact tied to current topic | Should-have |
| FR-16 | Intervention | Video clip: 60-90s educational video + 1 comprehension question | Should-have |
| FR-18 | RL Agent | Rule-based (sessions 1-5): fixed cascade by drift duration — mild→flashcard, moderate→simulation, severe→voice, lost→gesture | Must-have |
| FR-19 | RL Agent | Contextual bandit (sessions 6-30): learns per-student format preferences from historical reward. Context: {attention_level, topic, session_number}. | Should-have |
| FR-21 | Dashboard | Student home tab: attention-prioritized topic cards (worst focus first), drift count, status badges. Filter by subject. | Must-have |
| FR-22 | Dashboard | Student library tab: full content browser by subject. All topics with last focus score, estimated time. | Must-have |
| FR-23 | Dashboard | Topic card: topic name, subject, last session stats, estimated time, "Start Session" button | Must-have |
| FR-24 | Post-intervention | After recovery: 1 confirmation question + recap sentence + content resumes from exact pause point | Must-have |
| FR-25 | Post-intervention | After failed recovery (60s): RL picks next format immediately, cascade continues | Must-have |
| FR-26 | Post-intervention | Section completion reward: real-world connection card when student completes section while focused | Should-have |
| FR-27 | Teacher | Live focus monitor: real-time focus gauge + band power bars via AttentionStream.forSession(sessionId), updating every 1s | Must-have |
| FR-28 | Teacher | Session code join: teacher enters 6-char code to subscribe to student's live stream | Must-have |
| FR-29 | Teacher | Intervention event feed: real-time list of intervention events for monitored session | Should-have |
| FR-30 | Teacher | Session history: list of past sessions, sortable/filterable | Should-have |
| FR-31 | Teacher | Session detail: full stats + focus timeline chart + intervention breakdown | Should-have |
| FR-32 | Teacher | Export session data as CSV or PDF | Could-have |
| FR-33 | Teacher | Multi-session dashboard: view multiple active students simultaneously | Could-have |
| FR-34 | Auth | Role picker: "I'm a Student" / "I'm a Teacher". No auth in v1 — identity is local. | Must-have |
| FR-35 | Data | All session data persisted to SQLite via Drift. Local-first, on-device. | Must-have |
| FR-36 | Data | Reactive data streams via Drift streams for live UI updates | Must-have |
| FR-37 | Privacy | Raw EEG never leaves daemon machine. Only derived AttentionState transmitted. | Must-have |
| FR-40 | Connectivity | WebSocket auto-reconnect: retry every 3s with visual indicator | Must-have |
| FR-41 | Connectivity | Connection status indicator: green/yellow/red | Should-have |
| FR-42 | Onboarding | First-launch tutorial overlay | Should-have |
| FR-43 | Lesson | Confirmation question after each intervention (1 MCQ) to verify re-engagement | Must-have |
| FR-44 | Teacher | Focus timeline chart: scrolling time-series, color-coded by attention level | Should-have |

### Non-Functional Requirements

| ID | Category | Requirement | Target |
|----|----------|-------------|--------|
| NFR-01 | Latency | Drift detection to intervention screen | < 4 seconds |
| NFR-02 | Latency | AttentionState broadcast frequency | 1 Hz |
| NFR-03 | Latency | WebSocket message delivery | < 100ms local |
| NFR-04 | Privacy | Raw EEG containment | Never leaves daemon machine |
| NFR-05 | Privacy | Data to teacher | Only derived AttentionState |
| NFR-06 | Storage | Session retention | Indefinite, local SQLite, user-deletable |
| NFR-07 | Performance | Frame rate during lesson + HUD | 60fps on Windows desktop |
| NFR-08 | Performance | Memory during 10-min session | < 500MB (app + daemon) |
| NFR-09 | Reliability | WebSocket auto-reconnect | Within 3s, infinite retries |
| NFR-10 | Reliability | Session persistence | No data loss on unexpected close |
| NFR-11 | Usability | Calibration time | 30 seconds |
| NFR-12 | Usability | Session code | 6-char, uppercase, monospaced, tap-to-copy |
| NFR-14 | Offline | Full offline functionality | App + daemon + SQLite work offline |
| NFR-15 | Accessibility | Text contrast | WCAG AA (4.5:1) |

### Assumptions
- Neurosity Crown is available and charged for demo day
- BrainFlow Python bindings work with Crown on Windows (untested — mitigation: mock daemon as fallback)
- Demo will be 5-10 minutes showing one full session flow on Periodic Table topic
- Single student per session, single Crown per machine
- Demo on same WiFi network (teacher and student devices)
- `speech_to_text` Flutter package works on Windows desktop (fallback: typed text input)
- Python MediaPipe hand tracking works on Windows (high confidence — well-supported platform)

### Open Questions
- Crown physical availability confirmed for Monday?
- MediaPipe Python hand landmark accuracy sufficient with standard webcam lighting?
- `speech_to_text` Windows desktop reliability — needs testing early in build

---

## 3. Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────┐
│                    HARDWARE LAYER                        │
│  Neurosity Crown (WiFi/OSC) ──► BrainFlow BoardShim     │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│               PYTHON DAEMON LAYER                        │
│                                                          │
│  attention_engine.py          mediapipe_server.py        │
│  ├─ BrainFlow → band powers   ├─ Camera → MediaPipe     │
│  ├─ Welch PSD (F5/F6)         ├─ Hand landmark detect    │
│  ├─ Attention index calc       └─ WS :8766 → landmarks   │
│  ├─ Hysteresis classifier                                │
│  └─ WS :8765 → AttentionState JSON                      │
│                                                          │
│  --mock flag → synthetic data (no Crown needed)          │
└──────────────────────┬──────────────────────────────────┘
                       │ WebSocket (localhost)
┌───────���──────────────▼──────────────────────────────────┐
│               FLUTTER APP LAYER                          │
│                                                          │
│  ┌─── core/ ───────────────────────────────────────┐     │
│  │ models: AttentionState, Session, Intervention   │     │
│  │ services: WebSocketClient, AttentionStream,     │     │
│  │           SessionManager, EEGService            │     │
│  │ data: drift DB + DAOs                           │     │
│  │ widgets: FocusGauge, BandPowerBars, ErrorState  │     │
│  │ theme: AppColors, AppSpacing, AppTheme          │     │
│  └─────────────────────────────────────────────────┘     │
│                                                          │
│  ┌─── student/ ────────────────┐  ┌─── teacher/ ──────┐ │
│  │ Dashboard (Home + Library)  │  │ Live Monitor      │ │
│  │ Session flow (calibrate,    │  │ Session Code Join  │ │
│  │   lesson, HUD)              │  └────────────────────┘ │
│  │ Intervention Engine         │                         │
│  │ ├─ FlashcardScreen          │                         │
│  │ ├─ SimulationScreen         │                         │
│  │ ├─ GestureScreen (WS:8766) │                         │
│  │ ├─ VoiceChallengeScreen     │                         │
│  │ RL Agent (rule-based)       │                         │
│  │ Pacing Engine               │                         │
│  └─────────────────────────────┘                         │
│                                                          │
│  State: Riverpod (StreamProvider.family for sessions)    │
│  Nav: go_router (role_picker → shells)                   │
│  DB: drift SQLite (sessions, interventions, baselines)   │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│               STORAGE LAYER                              │
│  SQLite (on-device) — sessions, interventions, baselines │
│  [Supabase — deferred to post-demo]                      │
└─────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### Python Attention Daemon (`daemon/attention_engine.py`)
- **Responsibility:** Connect to Crown via BrainFlow, compute band powers, classify attention, broadcast AttentionState JSON over WebSocket
- **Key interfaces:** WebSocket server on port 8765, emits `{session_id, focus_score, theta, alpha, beta, gamma, level, timestamp}` at 1 Hz
- **Technology:** Python 3.11, BrainFlow, NumPy, SciPy (Welch PSD), websockets library
- **Modes:** `--mock` for synthetic data, default for real Crown

#### Python MediaPipe Server (`daemon/mediapipe_server.py`)
- **Responsibility:** Camera capture → MediaPipe hand landmark detection → broadcast hand data over WebSocket
- **Key interfaces:** WebSocket server on port 8766, emits `{landmarks: [...], finger_count: int, pointing_direction: str}`
- **Technology:** Python 3.11, mediapipe, opencv-python, websockets

#### Flutter Core Layer (`lib/core/`)
- **Responsibility:** Shared models, services, data layer, theme, and widgets consumed by both student and teacher modules
- **Key interfaces:** AttentionState model, AttentionStream broadcast, SessionManager, drift DAOs
- **Technology:** Flutter 3.x, Dart, drift, web_socket_channel, flutter_riverpod
- **Status:** Partially scaffolded (models, services, DB, widgets exist)

#### Student Module (`lib/student/`)
- **Responsibility:** Dashboard, session flow, lesson renderer, HUD, intervention engine, RL agent, all intervention format screens
- **Key interfaces:** Consumes core/ only. Never imports from teacher/.
- **Technology:** Flutter widgets, Riverpod state, go_router navigation

#### Teacher Module (`lib/teacher/`)
- **Responsibility:** Live focus monitor, session code join, (should-have) session history
- **Key interfaces:** Consumes core/ only. Never imports from student/.
- **Technology:** Flutter widgets, Riverpod state, AttentionStream.forSession()

### Data Models

#### AttentionState (frozen — do not modify)
```dart
enum AttentionLevel { focused, drifting, lost }

class AttentionState {
  final String sessionId;
  final double focusScore;      // 0.0 - 1.0
  final double theta;
  final double alpha;
  final double beta;
  final double gamma;
  final AttentionLevel level;
  final DateTime timestamp;
}
```

#### Session (frozen — do not modify)
```dart
class Session {
  final String id;              // 6-char uppercase alphanumeric
  final String topicId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? avgFocusScore;
  final int interventionCount;
}
```

#### Intervention
```dart
class Intervention {
  final String id;
  final String sessionId;
  final String format;          // flashcard, simulation, gesture, voice
  final AttentionLevel triggerLevel;
  final int driftDurationSec;
  final bool? recovered;
  final double? reward;         // +1.0 or -1.0
  final DateTime triggeredAt;
  final DateTime? completedAt;
}
```

#### Baseline
```dart
class Baseline {
  final String id;
  final String sessionId;
  final double baselineIndex;   // mean((theta+alpha)/beta) during calibration
  final DateTime calibratedAt;
}
```

#### Topic (curriculum content)
```dart
class Topic {
  final String id;
  final String name;
  final String subject;         // Biology, Chemistry
  final List<Section> sections;
  final List<Flashcard> flashcards;
  final SimulationConfig? simulation;
  final List<GestureQuestion> gestureQuestions;
  final List<VoiceQuestion> voiceQuestions;
  final String? curiosityBomb;
  final int estimatedMinutes;
}
```

### WebSocket JSON Schemas

#### AttentionState (daemon → Flutter, port 8765)
```json
{
  "session_id": "ABC123",
  "focus_score": 0.72,
  "theta": 12.5,
  "alpha": 8.3,
  "beta": 15.1,
  "gamma": 3.2,
  "level": "focused",
  "timestamp": "2026-04-13T10:05:32.123Z"
}
```

#### Hand Landmarks (MediaPipe → Flutter, port 8766)
```json
{
  "detected": true,
  "finger_count": 3,
  "pointing_direction": "right",
  "landmarks": [[0.5, 0.3], [0.6, 0.4]],
  "timestamp": "2026-04-13T10:05:32.456Z"
}
```

### Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| App framework | Flutter 3.x / Dart (SDK >=3.3.0) | Locked. Cross-platform desktop + mobile. |
| Navigation | go_router ^13.0.0 | Locked. Declarative routing. |
| State management | flutter_riverpod ^2.5.0 | Locked. StreamProvider.family fits session-filtered streams. |
| Local database | drift ^2.18.0 + sqlite3_flutter_libs | Locked. Type-safe queries + reactive streams. |
| WebSocket | web_socket_channel ^2.4.0 | Locked. Daemon communication. |
| EEG processing | Python 3.11 + BrainFlow | Mature Python bindings for Crown. |
| Signal processing | NumPy + SciPy (Welch PSD) | Standard scientific Python. |
| Hand tracking | Python MediaPipe + OpenCV | Reliable on Windows. Separate WS server. |
| Speech-to-text | speech_to_text Flutter package | Simplest integration. Typed text fallback. |
| Curriculum content | JSON files in assets/curriculum/ | No build step, easy to author. |

### Detected Stack Constraints
Existing Flutter project with pubspec.yaml locking: go_router ^13.0.0, flutter_riverpod ^2.5.0, drift ^2.18.0, web_socket_channel ^2.4.0, sqlite3_flutter_libs ^0.5.0, uuid ^4.3.0, intl ^0.19.0. All recommendations fit within this stack. No framework changes.

### Shared Interfaces

| Interface | Location | Purpose | Depended on by |
|-----------|----------|---------|----------------|
| AttentionState + AttentionLevel | `lib/core/models/attention_state.dart` | EEG state model (FROZEN) | HUD, pacing engine, intervention engine, teacher monitor, RL agent |
| Session model | `lib/core/models/session.dart` | Session data model (FROZEN) | Session flow, dashboard, teacher history |
| AttentionStream | `lib/core/services/attention_stream.dart` | Broadcast stream + forSession filter (FROZEN) | HUD, pacing engine, teacher monitor, intervention engine |
| WebSocketClient | `lib/core/services/websocket_client.dart` | WS connection + auto-reconnect | AttentionStream, gesture screen |
| Intervention model + DAO | `lib/core/data/intervention_dao.dart` | Intervention persistence | Intervention engine, all format screens, dashboard stats, teacher feed |
| RLAgent interface | `lib/student/rl/rl_agent.dart` | Abstract selectFormat/updateReward | Intervention engine, RuleBasedAgent, (future) BanditAgent |
| Topic/Curriculum model | `lib/core/models/topic.dart` | Content structure | Lesson renderer, flashcards, simulations, topic cards |

---

## 4. Strategy

### Build vs. Buy

| Capability | Decision | Rationale |
|-----------|----------|-----------|
| EEG signal processing | Build (Python daemon) | BrainFlow provides hardware abstraction; attention classification is our core IP |
| Hand gesture recognition | Buy (MediaPipe) | Google's pre-trained hand landmark model, no training needed |
| Speech-to-text | Buy (speech_to_text package) | Platform STT engines (Windows SAPI), no custom model needed |
| Database | Buy (SQLite via drift) | Proven embedded DB, type-safe Dart wrapper |
| Curriculum content | Build (JSON authored) | Custom educational content for 4 STEM topics |
| RL agent | Build | Core differentiator — rule-based now, bandit later |

### MVP Scope (Demo Day — April 13)

**In scope (must-have):**
- Mock daemon + real Crown daemon (BrainFlow)
- Full session flow: role picker → calibration → lesson → HUD → interventions → summary
- 4 intervention formats: flashcard, simulation, gesture, voice
- Rule-based RL agent (cascade by drift duration)
- Student dashboard (home + library tabs)
- Teacher live monitor + session code join
- Periodic Table as fully authored demo topic; 3 placeholder topics

**Explicitly deferred:**
- Contextual bandit RL (post-demo, sessions 6-30)
- DQN agent (post-launch)
- Supabase cloud sync (Week 5)
- Draw-it intervention (requires shape recognition ML)
- Teacher session history/export (should-have, post-demo)
- Onboarding tutorial overlay

### Iteration Approach
1. Demo day (April 13): Must-have features, Periodic Table topic
2. Week 2: Add contextual bandit RL, remaining 3 topics with full content
3. Week 3: Should-have features (curiosity bomb, video clip, teacher history, onboarding)
4. Week 4: Could-have features (export, multi-session teacher view)
5. Week 5: Supabase cloud sync (optional, anonymized)

### Deployment Strategy
- **Demo:** Local desktop app. `flutter run -d windows`. Python daemon as subprocess.
- **Distribution (post-demo):** Flutter desktop builds for Windows/macOS. Python daemon bundled or installed separately.
- **No CI/CD needed for demo day.** Post-demo: GitHub Actions for Flutter build + test.

---

## 5. Project Structure

```
neurolearn/
├── daemon/
│   ├── attention_engine.py       # EEG daemon (real + mock mode)
│   ├── mediapipe_server.py       # Hand tracking WebSocket server
│   ├── requirements.txt          # Python dependencies
│   └── test_daemon.py            # Daemon unit tests
├── lib/
│   ├── main.dart                 # App entry, ProviderScope
│   ├── router.dart               # go_router configuration
│   ├── core/
│   │   ├── models/
│   │   │   ├── attention_state.dart    # FROZEN
│   │   │   ├── session.dart            # FROZEN
│   │   │   ├── topic.dart              # Curriculum data model
│   │   │   └── user.dart
│   │   ├── services/
│   │   │   ├── attention_stream.dart   # FROZEN
│   │   │   ├── websocket_client.dart
│   │   │   ├── session_manager.dart
│   │   │   ├── eeg_service.dart        # Spawns Python daemon
│   │   │   └── attention_stream_provider.dart
│   │   ├── data/
│   │   │   ├── database.dart           # Drift database definition
│   │   │   ├── session_dao.dart
│   │   │   ├── intervention_dao.dart
│   │   │   └── baseline_dao.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_spacing.dart
│   │   │   └── app_theme.dart
│   │   └── widgets/
│   │       ├── focus_gauge.dart
│   │       ├── band_power_bars.dart
│   │       ├── session_code_display.dart
│   │       └── error_state.dart
│   ├── student/
│   │   ├── student_shell.dart          # Bottom nav: Home, Library
│   │   ├── screens/
│   │   │   ├── dashboard_screen.dart   # Home tab
│   │   │   ├── library_screen.dart     # Library tab
│   │   │   ├── session_start_screen.dart  # Calibration + code
│   │   │   ├── lesson_screen.dart      # Content + HUD + pacing
│   │   │   ├── session_end_screen.dart # Summary stats
│   │   │   └── interventions/
│   │   │       ├── intervention_engine.dart  # Orchestrator
│   │   │       ├── flashcard_screen.dart
│   │   │       ├── simulation_screen.dart
│   │   │       ├── gesture_screen.dart
│   │   │       └── voice_challenge_screen.dart
│   │   ├── rl/
│   │   │   ├── rl_agent.dart           # Abstract interface
│   │   │   ├── rule_based_agent.dart   # Sessions 1-5
│   │   │   └── bandit_agent.dart       # Sessions 6-30 (post-demo)
│   │   └── widgets/
│   │       ├── topic_card.dart
│   │       ├── focus_hud.dart
│   │       └── pacing_controller.dart
│   └── teacher/
│       ├── teacher_shell.dart
│       ├── screens/
│       │   ├── join_session_screen.dart
│       │   └── live_monitor_screen.dart
│       └── widgets/
│           └── intervention_feed.dart
├── assets/
│   ├── curriculum/
│   │   ├── periodic_table.json     # Full content (demo topic)
│   │   ├── chemical_bonding.json   # Placeholder
│   │   ├── cell_structure.json     # Placeholder
│   │   └── dna_replication.json    # Placeholder
│   └── images/
│       └── (diagrams for topics)
├── test/
│   ├── core/
│   ├── student/
│   └── teacher/
├── pubspec.yaml
├── CLAUDE.md
└── PROJECT_PLAN.md
```

---

## 6. Implementation Plan

### Timeline
- **Start date:** 2026-04-12 (today)
- **Target completion:** 2026-04-13 (demo day)
- **Total estimated duration:** ~16-20 hours of focused development

---

### Phase 1: Python Daemon (Mock + Real) — 2-3 hours

**Goal:** Working EEG daemon that broadcasts AttentionState over WebSocket. Mock mode first (unblocks all Flutter work), then real Crown connection.

**Features Completed:**
- Mock daemon generating realistic synthetic EEG with drift cycles (FR-02)
- Real daemon connecting to Crown via BrainFlow with attention classification (FR-01)

**Deliverables:**
- [ ] `daemon/attention_engine.py` with mock + real modes
- [ ] `daemon/requirements.txt` with all Python dependencies
- [ ] WebSocket server on port 8765 emitting AttentionState JSON at 1 Hz
- [ ] Mock mode: realistic 60s focus → 15s drift → recovery cycles with noise
- [ ] Real mode: BrainFlow Crown connection, Welch PSD, attention index, hysteresis classifier

**Key Tasks:**
1. Create `daemon/requirements.txt`: brainflow, numpy, scipy, websockets
2. Build mock data generator: sinusoidal attention cycles with Gaussian noise on band powers, configurable drift/recovery timing
3. Build WebSocket server: async Python, port 8765, 1 Hz emission
4. Add `--mock` CLI flag to switch between mock and real mode
5. Build real mode: BrainFlow BoardShim for Crown, bandpass filter (1-45 Hz), 4s rolling window (1024 samples), Welch PSD on F5/F6 channels, attention_index = (theta+alpha)/beta
6. Add baseline calibration support: accept `{"command": "calibrate", "session_id": "..."}` over WS, record 30s of EEG, compute baseline_index
7. Add hysteresis classifier: focused (≤1.5x baseline), drifting (1.5-2.2x, 2 consecutive windows), lost (>2.2x, 2 consecutive windows)
8. Test mock mode: verify WebSocket emissions, verify drift cycles appear naturally
9. Test real mode with Crown (if available): verify BrainFlow connection, verify band power values are reasonable

**How to Test Locally:**
```bash
# Install Python deps
cd daemon && pip install -r requirements.txt

# Start mock daemon
python attention_engine.py --mock

# In another terminal, verify WebSocket output
python -c "
import asyncio, websockets, json
async def test():
    async with websockets.connect('ws://localhost:8765') as ws:
        for i in range(10):
            msg = json.loads(await ws.recv())
            print(f'{msg[\"level\"]:8s} focus={msg[\"focus_score\"]:.2f} theta={msg[\"theta\"]:.1f}')
asyncio.run(test())
"
```
- Should see ~10 AttentionState messages at 1/second
- Focus scores should vary naturally, with occasional drift/lost periods
- Band powers (theta, alpha, beta, gamma) should all be positive floats

**Success Criteria:**
- Mock daemon runs and emits valid JSON at 1 Hz over WebSocket
- Real daemon connects to Crown (or fails gracefully with clear error)
- AttentionState JSON matches the frozen schema exactly

**Risks:**
- BrainFlow Crown connection may fail on first try → mitigation: mock daemon is primary, real Crown is bonus
- Crown may not be on same WiFi → mitigation: verify network before demo

---

### Phase 2: Core Services + Session Flow — 2-3 hours

**Goal:** Flutter app connects to daemon, displays session code, runs calibration, persists session data.

**Features Completed:**
- WebSocket connection to daemon with auto-reconnect (FR-40)
- Session start flow: calibration + code generation (FR-03)
- Session code display and sharing (FR-05)
- Role picker working (FR-34)
- Reactive data streams (FR-36)

**Deliverables:**
- [ ] WebSocketClient connecting to daemon on :8765 with auto-reconnect every 3s
- [ ] AttentionStream broadcasting parsed AttentionState to all subscribers
- [ ] SessionManager: startSession() with calibration, endSession() with summary save
- [ ] EEGService: spawn daemon subprocess, check health
- [ ] Session start screen: signal quality → calibration countdown → code display
- [ ] Riverpod providers wired up for all services
- [ ] Drift database generating and running (build_runner)

**Key Tasks:**
1. Wire WebSocketClient to connect to `ws://localhost:8765`, parse JSON to AttentionState, push to AttentionStream
2. Add auto-reconnect logic: on disconnect, retry every 3s, emit connection status
3. Implement EEGService.startDaemon() — spawn `python daemon/attention_engine.py --mock` as detached process
4. Implement SessionManager.startSession(): generate 6-char ID (uppercase alphanumeric), insert Session into drift DB, send calibration command to daemon
5. Build session_start_screen.dart: calibration dot UI with 30s countdown timer, session code display after calibration
6. Wire Riverpod providers: attentionStreamProvider, sessionManagerProvider, eegServiceProvider
7. Ensure drift code generation works: `dart run build_runner build`
8. Add baseline_dao.dart if not exists, wire into drift database
9. Test session creation → verify row in SQLite → verify session code displays

**How to Test Locally:**
```bash
# Start mock daemon
python daemon/attention_engine.py --mock

# In another terminal, run Flutter app
flutter run -d windows
```
- Select "I'm a Student" on role picker
- Tap a topic card → should navigate to session start screen
- See calibration dot with 30s countdown
- After calibration: 6-char session code displayed (e.g., "ABC123")
- Check that AttentionState data is flowing (no errors in console)

**Success Criteria:**
- Flutter app connects to mock daemon WebSocket successfully
- Auto-reconnect works (kill daemon, restart — app reconnects)
- Session created in SQLite with valid 6-char ID
- Calibration runs for 30 seconds with visual countdown

**Risks:**
- Drift code generation may need regeneration after model changes → run `dart run build_runner build` after any schema change
- Process spawning on Windows may need shell: true flag

---

### Phase 3: Lesson Content + HUD + Pacing Engine — 2-3 hours

**Goal:** Student reads Periodic Table content with live focus HUD. Content pauses on drift and resumes after recovery.

**Features Completed:**
- Full-screen lesson content renderer (FR-06)
- Periodic Table curriculum content (FR-07)
- Live focus HUD with gauge + band power bars (FR-09)
- Pacing engine: pause on drift, resume on recovery (FR-08)

**Deliverables:**
- [ ] Periodic Table JSON content file with 3-4 sections of real educational text + diagram references
- [ ] Topic model and JSON parser
- [ ] Lesson screen: scrollable text content, intentionally boring design (white bg, serif font)
- [ ] Focus HUD: bottom strip with FocusGauge + BandPowerBars, updating every 1s from AttentionStream
- [ ] Pacing controller: listens to AttentionStream, pauses scroll/content on drifting/lost, resumes on focused
- [ ] 3 placeholder topic JSONs (minimal content)

**Key Tasks:**
1. Create `assets/curriculum/periodic_table.json` with 3-4 sections: history, element groups, trends, chemical properties. Real educational text, ~500 words per section.
2. Create Topic model (`lib/core/models/topic.dart`) + JSON deserialization
3. Create placeholder JSONs for chemical_bonding, cell_structure, dna_replication (title + 1 section each)
4. Build lesson_screen.dart: full-screen scrollable content, white background, serif font (Merriweather or system serif), minimal margins
5. Integrate FocusGauge + BandPowerBars as a bottom HUD strip (fixed position, ~80px height)
6. Build PacingController: StreamSubscription on AttentionStream, when level != focused → disable scroll + show "paused" overlay, when focused → resume
7. Wire lesson screen into go_router: session_start → lesson → (intervention) → session_end
8. Add section progress tracking (which section the student is on)

**How to Test Locally:**
```bash
python daemon/attention_engine.py --mock
flutter run -d windows
```
- Start a session → lesson screen loads with Periodic Table content
- HUD at bottom shows focus gauge (circular, 0-100%) and 4 band power bars updating live
- Read content — when mock daemon cycles to "drifting", content should visually pause (overlay appears)
- When mock daemon returns to "focused", content should resume
- Scroll through content sections

**Success Criteria:**
- Periodic Table content renders with readable educational text
- HUD updates every second matching daemon emissions
- Pacing engine pauses within 1-2 seconds of drift detection
- Content resumes from exact position after recovery

**Risks:**
- Scroll position preservation on pause/resume needs careful state management
- HUD performance at 1Hz updates should be fine but verify no jank

---

### Phase 4: Intervention Engine + RL Agent + 4 Formats — 4-5 hours

**Goal:** When drift detected, RL agent selects intervention format, student completes activity, EEG measures recovery, reward updates policy. All 4 formats working.

**Features Completed:**
- Intervention engine orchestration (FR-10)
- Rule-based RL agent with cascade logic (FR-18)
- Flashcard intervention (FR-13)
- Simulation intervention (FR-11)
- Gesture intervention via MediaPipe (FR-12)
- Voice challenge intervention (FR-14)
- Post-intervention recovery flow (FR-24, FR-25)
- Confirmation question after intervention (FR-43)

**Deliverables:**
- [ ] RLAgent abstract interface + RuleBasedAgent implementation
- [ ] InterventionEngine: detect drift → query RL → launch format → measure recovery → update reward → cascade or resume
- [ ] FlashcardScreen: 5-card swipeable deck with Q&A for Periodic Table
- [ ] SimulationScreen: drag-and-drop periodic table element placement
- [ ] GestureScreen: connects to MediaPipe WS :8766, finger counting questions
- [ ] VoiceChallengeScreen: TTS question, STT answer, fuzzy match, typed fallback
- [ ] `daemon/mediapipe_server.py`: camera + MediaPipe hand tracking + WS :8766
- [ ] Confirmation MCQ after each successful intervention
- [ ] Cascade logic: if not recovered in 60s, try next format

**Key Tasks:**
1. Create `lib/student/rl/rl_agent.dart`: abstract class with `String selectFormat(InterventionState state)` and `void updateReward(String format, double reward)`
2. Create `lib/student/rl/rule_based_agent.dart`: mild drift (4-8s) → flashcard, moderate (8-20s) → simulation, severe (20+s) → voice, lost → gesture
3. Create `lib/student/screens/interventions/intervention_engine.dart`: orchestrator widget/controller that listens to AttentionStream, triggers on drift, manages format selection → launch → recovery measurement → reward
4. Build FlashcardScreen: 5 Periodic Table questions (e.g., "What group is Sodium in?", "Noble gas or halogen: Chlorine?"), swipeable cards with flip animation, score display
5. Build SimulationScreen: drag elements to correct positions on periodic table grid (e.g., drag Na, Cl, Fe to correct group/period), snap-to-target, progress bar
6. Build `daemon/mediapipe_server.py`: OpenCV camera capture, MediaPipe hands solution, count raised fingers, detect pointing, emit over WS :8766
7. Build GestureScreen: connect to WS :8766, display question ("How many electrons in outer shell of Carbon? Hold up fingers"), show camera feed overlay with detected hand, validate finger count
8. Build VoiceChallengeScreen: TTS speaks question via Flutter TTS, speech_to_text listens for answer, fuzzy string match against accepted answers, typed text input as fallback button
9. Add 60-second recovery measurement timer after each intervention: subscribe to AttentionStream, if focused within 60s → reward +1, else → reward -1
10. Add confirmation MCQ screen: 1 question related to lesson content, shown after successful recovery before resuming content
11. Wire intervention engine into lesson pacing: when pacing controller detects drift → hand off to intervention engine → on completion → return to pacing controller

**How to Test Locally:**
```bash
# Terminal 1: EEG daemon
python daemon/attention_engine.py --mock

# Terminal 2: MediaPipe server (for gesture intervention)
python daemon/mediapipe_server.py

# Terminal 3: Flutter app
flutter run -d windows
```
- Start a session → read content → wait for mock drift event
- Content should pause → intervention screen appears (format selected by RL cascade)
- **Flashcard:** Swipe through 5 cards, answer questions, see score
- **Simulation:** Drag elements to correct positions, see snap feedback
- **Gesture:** Camera activates, hold up fingers to answer, see hand detection overlay
- **Voice:** Hear question spoken, speak answer (or type in fallback), see correct/incorrect
- After intervention: 60s recovery window → if mock returns to focused → confirmation MCQ → resume content
- If not recovered: next format in cascade triggers automatically

**Success Criteria:**
- All 4 intervention formats launch and complete without crashes
- RL rule-based cascade selects correct format based on drift duration
- Recovery measurement works (reward logged to intervention table)
- Cascade continues if first format fails to recover attention
- Confirmation question appears after successful recovery

**Risks:**
- MediaPipe Python + camera may need specific OpenCV build for Windows → test early, have fallback (skip gesture, use 3 formats)
- speech_to_text Windows reliability uncertain → typed fallback is critical
- 60s recovery timer needs careful lifecycle management (dispose on navigation away)

---

### Phase 5: Student Dashboard — 1-2 hours

**Goal:** Student home screen shows attention-prioritized topics and full content library.

**Features Completed:**
- Home tab with attention-prioritized topic cards (FR-21)
- Library tab with full content browser (FR-22)
- Topic card with stats and Start Session button (FR-23)

**Deliverables:**
- [ ] Dashboard home tab: topic cards sorted by worst focus score first, with drift count, avg focus %, status badge (NEEDS WORK / IN PROGRESS / STRONG)
- [ ] Dashboard library tab: topics organized by subject (Biology, Chemistry), with last focus score and estimated time
- [ ] Subject filter bar (All, Biology, Chemistry)
- [ ] Topic card detail: topic name, subject, last session stats, "Start Session" button
- [ ] Empty state for first-time user: "Start your first session to see recommendations"

**Key Tasks:**
1. Update dashboard_screen.dart: query SessionDao for all sessions, group by topic, compute per-topic stats (avg focus, drift count, status)
2. Build topic cards: show topic name, subject tag, focus %, drift count, status badge with color coding (red=NEEDS WORK, amber=IN PROGRESS, green=STRONG)
3. Sort home tab by ascending focus score (worst first)
4. Build library_screen.dart: grid/list of all topics grouped by subject
5. Add subject filter chips: All | Biology | Chemistry
6. Handle empty state: no sessions → show all topics as "Not Started" with welcome message
7. Wire "Start Session" button → navigate to session_start_screen with selected topic

**How to Test Locally:**
```bash
python daemon/attention_engine.py --mock
flutter run -d windows
```
- Fresh install: home tab shows all 4 topics as "Not Started" with welcome message
- Complete a session → return to dashboard → Periodic Table card should show focus stats
- Home tab sorts by worst focus first
- Library tab shows all topics grouped by subject
- Filter by Chemistry → only Chemistry topics visible
- Tap topic → Start Session → navigates to session start

**Success Criteria:**
- Dashboard loads with correct topic data from SQLite
- Attention-priority sorting works
- Topic cards show accurate session stats
- Navigation to session start works from both tabs

**Risks:**
- Low risk — straightforward UI work with existing drift queries

---

### Phase 6: Session End Summary — 1 hour

**Goal:** Session end screen with stats and focus timeline.

**Features Completed:**
- Session summary screen (FR-04)

**Deliverables:**
- [ ] Session end screen: topic name, duration, avg focus %, intervention count, most effective format
- [ ] Color-coded focus timeline bar (green/amber/red segments over session duration)
- [ ] SessionDao.updateSession() saves final stats
- [ ] "Done" button returns to dashboard

**Key Tasks:**
1. Build session_end_screen.dart: receives session ID, queries SessionDao + InterventionDao for stats
2. Compute most effective format: format with highest recovery rate from InterventionDao
3. Build focus timeline: horizontal bar chart from stored AttentionState history (need to buffer states during session)
4. Wire session end into go_router: lesson completion or time limit → session end → dashboard
5. Add session state buffer: collect AttentionState samples during session for timeline rendering

**How to Test Locally:**
- Complete a full session (calibrate → lesson → at least 1 intervention → content complete or 2-min timeout for testing)
- Session end screen should show: topic name, session duration, avg focus %, number of interventions, most effective format
- Focus timeline should show colored segments
- Tap "Done" → return to dashboard with updated stats

**Success Criteria:**
- All stats display correctly from SQLite data
- Focus timeline renders with color coding
- Session data persisted before showing summary

**Risks:**
- Buffering AttentionState for timeline may use memory → limit to last 10 minutes (600 samples is fine)

---

### Phase 7: Teacher Live Monitor — 1-2 hours

**Goal:** Teacher can join a student's session by code and see live focus data.

**Features Completed:**
- Session code join flow (FR-28)
- Live focus monitor (FR-27)
- Basic teacher shell navigation

**Deliverables:**
- [ ] Join session screen: text input for 6-char code, validation
- [ ] Live monitor screen: focus gauge + band power bars via AttentionStream.forSession(sessionId)
- [ ] Session duration timer
- [ ] Session ended detection + notification
- [ ] Error handling: invalid code, student not on same WiFi

**Key Tasks:**
1. Build join_session_screen.dart: 6-char code input field (uppercase, monospaced), "Join" button, validation
2. Wire AttentionStream.forSession(sessionId) to filter the broadcast stream by session code
3. Build live_monitor_screen.dart: reuse FocusGauge + BandPowerBars widgets from core, add student name/session info header, session timer
4. Listen for session end: when no AttentionState received for 10s or session marked ended → show "Session ended" overlay
5. Handle errors: invalid session code → "No active session found", WebSocket disconnected → reconnecting indicator
6. Wire into teacher_shell.dart navigation

**How to Test Locally:**
```bash
python daemon/attention_engine.py --mock
flutter run -d windows
```
- Open app → select "I'm a Teacher"
- On a second instance (or hot-restart with role switch): start a student session, note the 6-char code
- On teacher instance: enter the session code → Join
- Live monitor should show focus gauge + band power bars updating every 1s
- When student ends session: teacher sees "Session ended" notification

**Success Criteria:**
- Teacher joins via valid session code
- Live focus data streams in real-time (matching student's data)
- Invalid codes show clear error message
- Session end is detected and communicated

**Risks:**
- Two Flutter instances on same machine connecting to same daemon WebSocket — should work since WebSocket is broadcast
- Same-machine testing may need two windows or a second device

---

### Phase 8: Integration Test + Demo Rehearsal — 1-2 hours

**Goal:** End-to-end flow works smoothly for a 5-10 minute demo.

**Features Completed:**
- Full demo flow validated
- All must-have features working together

**Deliverables:**
- [ ] Full demo script written and rehearsed
- [ ] Mock daemon tuned for demo timing (predictable drift at good moments)
- [ ] All navigation paths tested
- [ ] Edge cases handled (disconnect, reconnect, cascade)

**Key Tasks:**
1. Write demo script: exact sequence of actions for 5-10 min presentation
2. Tune mock daemon timing: ensure drift occurs ~60s into reading (enough time to show lesson), recovery after intervention
3. Run full flow end-to-end: role picker → student dashboard → start session → calibrate → lesson → drift → intervention → recovery → summary → dashboard updated
4. Run teacher flow: join session → watch live monitor → see intervention events
5. Fix any integration bugs found
6. Test with real Crown if available (bonus)
7. Prepare fallback plan: if Crown fails, demo with mock; if gesture/voice fails, show flashcard + simulation

**How to Test Locally:**
- Run the exact demo flow 2-3 times end-to-end
- Time it — should be 5-10 minutes
- Test the "wow moments": drift detection → automatic intervention, teacher seeing live data

**Success Criteria:**
- Full demo runs without crashes
- Demo fits within 5-10 minute window
- Fallback paths work if any single component fails

**Risks:**
- Integration bugs between phases → budget time for this phase
- Demo timing sensitivity → tune mock daemon carefully

---

## 7. Cost Analysis

### Development Costs

| Phase | Effort | Paid Tools | Phase Cost |
|-------|--------|-----------|------------|
| Phase 1: Daemon | 2-3 hours | None (all OSS) | $0 |
| Phase 2: Core + Session | 2-3 hours | None | $0 |
| Phase 3: Lesson + HUD | 2-3 hours | None | $0 |
| Phase 4: Interventions | 4-5 hours | None | $0 |
| Phase 5: Dashboard | 1-2 hours | None | $0 |
| Phase 6: Session End | 1 hour | None | $0 |
| Phase 7: Teacher Monitor | 1-2 hours | None | $0 |
| Phase 8: Integration | 1-2 hours | None | $0 |
| **Total** | **14-21 hours** | | **$0** |

*All tools are open-source. Flutter, BrainFlow, MediaPipe, drift, Riverpod — all free.*

### Hardware Costs

| Item | Cost | Notes |
|------|------|-------|
| Neurosity Crown | $999 | Already owned. One-time purchase. |
| Windows desktop | Existing | Development machine |
| Webcam | Existing or ~$30 | For MediaPipe gesture tracking |

### Operational Costs (Post-Demo)

v1 is entirely local — no cloud infrastructure costs. Zero monthly operational cost.

| Component | v1 (local) | v2 (with Supabase) |
|-----------|-----------|-------------------|
| Compute | $0 (local) | $0 (Supabase free tier for <500 users) |
| Database | $0 (SQLite) | $25/mo (Supabase Pro for >500 users) |
| Storage | $0 (local) | ~$0.02/GB on Supabase |
| Bandwidth | $0 (WiFi) | Included in Supabase plan |
| **Monthly Total** | **$0** | **$0-$25** |

### Alternative Cost Comparison

#### Database: SQLite (chosen) vs Supabase Postgres vs Firebase

| Option | Cost | Tradeoff |
|--------|------|----------|
| **SQLite via drift (chosen)** | $0 | Local-first, privacy guarantee, no internet needed |
| Supabase Postgres | $0-$25/mo | Cloud sync, multi-device, but requires internet |
| Firebase Firestore | $0-$25/mo | Real-time sync, but Google lock-in, privacy concerns |

#### Hand Tracking: Python MediaPipe (chosen) vs Flutter ML Kit vs TFLite

| Option | Cost | Tradeoff |
|--------|------|----------|
| **Python MediaPipe subprocess (chosen)** | $0 | Proven on Windows, reuses daemon WS pattern |
| google_ml_kit Flutter | $0 | Native but Windows desktop support questionable |
| TFLite custom model | $0 | Full control but significant dev time |

---

## 8. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| BrainFlow Crown connection fails | High | Medium | Mock daemon is fully functional fallback. Demo can run entirely on synthetic data. |
| MediaPipe camera fails on Windows | Medium | Low | MediaPipe Python is well-tested on Windows. Worst case: skip gesture intervention, demo 3 formats. |
| speech_to_text unreliable on Windows desktop | Medium | Medium | Typed text fallback button always available. Can switch to "type your answer" during demo. |
| Time runs out — not all 8 phases complete | High | Medium | Phases ordered by demo priority. If Phase 4 incomplete, demo with 2 formats instead of 4. Teacher monitor (Phase 7) is last — skip if needed. |
| Flutter desktop WebSocket performance | Low | Low | web_socket_channel is mature. 1 Hz updates are trivial load. |
| Drift code generation breaks | Medium | Low | Run `dart run build_runner build` after any schema change. Keep generated files in git. |
| Crown battery dies during demo | Medium | Low | Charge fully before demo. Mock daemon as instant fallback. |
| Demo WiFi issues (teacher on different network) | Medium | Low | Demo on same machine (two windows) or hotspot. v1 requires same WiFi by design. |

---

## 9. Next Steps

1. **Start Phase 1 immediately** — build mock daemon first (unblocks all Flutter work)
2. **Test BrainFlow + Crown early** — if it works, great; if not, mock daemon is ready
3. **Build phases sequentially** — each phase delivers testable features
4. **After Phase 4, assess time** — if tight, skip should-have features and go straight to Phase 7 (teacher) + Phase 8 (rehearsal)
5. **Rehearse the demo** — at least 2 full run-throughs before Monday
6. **Post-demo:** Add contextual bandit RL, remaining 3 topic content, should-have features
