NeuroLearn

Student Side — Finalized Flow & Architecture

Smit builds student module · Felipe builds teacher module

v1.0 · April 2026

# 1. Who Builds What

One Flutter app. Two developers. Two completely independent modules that never import from each other. They connect only through the shared core layer.

Smit — student module

Felipe — teacher module

- lib/student/ — entire folder

- daemon/ — Python EEG research script

- assets/curriculum/ — lesson JSON

- RL agent (Dart) — all three phases

- Session start + code generation

- EEG service (daemon spawn)

- lib/teacher/ — entire folder

- Live focus monitor

- Session history + trends

- Multi-session switcher

- Session code join flow

- Export / report generation

Joint — lib/core/ (both agree before changing anything here)

- core/models/attention_state.dart

- core/models/session.dart

- core/services/websocket_client.dart

- core/services/attention_stream.dart

- core/services/session_manager.dart

- core/data/database.dart

- core/theme/

- main.dart + router.dart

# 2. Frozen Interface — The Contract Between Smit and Felipe

This is the only data that crosses the boundary between the two modules. Neither developer changes this without agreement from both. This is what keeps the two sides aligned.

AttentionState — the core data model

// lib/core/models/attention_state.dart// FROZEN — do not change without agreement from both developersenum AttentionLevel { focused, drifting, lost }class AttentionState {  final String         sessionId;  final double         focusScore;    // 0.0 – 1.0  final double         theta;         // 4–8 Hz  final double         alpha;         // 8–13 Hz  final double         beta;          // 13–30 Hz  final double         gamma;         // 30–45 Hz  final AttentionLevel level;         // focused | drifting | lost  final DateTime       timestamp;  factory AttentionState.fromJson(Map<String, dynamic> j) => AttentionState(    sessionId:  j['session_id'],    focusScore: (j['focus_score'] as num).toDouble(),    theta:      (j['theta'] as num).toDouble(),    alpha:      (j['alpha'] as num).toDouble(),    beta:       (j['beta']  as num).toDouble(),    gamma:      (j['gamma'] as num).toDouble(),    level:      AttentionLevel.values.byName(j['level']),    timestamp:  DateTime.fromMillisecondsSinceEpoch(                  (j['timestamp'] * 1000).toInt()),  );}

WebSocket message schema — daemon to Flutter

{  "session_id":  "abc123",  "focus_score": 0.72,  "theta":       0.41,  "alpha":       0.28,  "beta":        0.81,  "gamma":       0.45,  "level":       "focused",  "timestamp":   1712345678.123}

AttentionStream — the shared broadcast

// lib/core/services/attention_stream.dart// FROZENclass AttentionStream {  static final instance = AttentionStream._();  AttentionStream._();  final _ctrl = StreamController<AttentionState>.broadcast();  Stream<AttentionState> get stream => _ctrl.stream;  void emit(AttentionState s) => _ctrl.add(s);  // Felipe uses this — subscribe to one student's stream  Stream<AttentionState> forSession(String id) =>    stream.where((s) => s.sessionId == id);}

Session model

// lib/core/models/session.dart// FROZENclass Session {  final String   sessionId;          // 6-char code e.g. 'abc123'  final String   studentName;  final String   topic;              // e.g. 'DNA Replication'  final String   subject;            // 'Biology' | 'Chemistry'  final DateTime startedAt;  final DateTime? endedAt;  final double   avgFocusScore;  final int      interventionCount;  final int      lessonsCompleted;}

# 3. Student Dashboard Layout

Two-tab structure. Home tab is brain-prioritised. Library tab is full free browse. Both lead to the same adaptive session.

## 3.1 Home tab — attention-first

─────────────────────────────────────────────────────FILTER BAR[ All ]  [ Biology ]  [ Chemistry ]─────────────────────────────────────────────────────TOP — Today's focus"Based on your last session, start here."[ DNA Replication ]        [ Covalent Bonds ]  Biology · 3 drifts         Chemistry · 5 drifts  Avg focus: 41%             Avg focus: 38%  NEEDS WORK                 NEEDS WORK─────────────────────────────────────────────────────MIDDLE — Continue where you left off[ Cell Structure ]         [ Periodic Table ]  Biology · 68% focus        Chemistry · 81% focus  IN PROGRESS                IN PROGRESS─────────────────────────────────────────────────────BOTTOM — Strong topics (greyed out)[ Cell Division ]  Biology · 91% focus  STRONG─────────────────────────────────────────────────────

## 3.2 Library tab — full content browser

─────────────────────────────────────────────────────FILTER BAR[ All ]  [ Biology ]  [ Chemistry ]─────────────────────────────────────────────────────BIOLOGY                         CHEMISTRY[ Cell Structure ]              [ Chemical Bonding ]  Last focus: 68% · 8 min         Last focus: 41% · 10 min[ Cell Division ]               [ Periodic Table ]  Last focus: 91% · 6 min         Last focus: 81% · 8 min[ DNA Replication ]             [ Covalent Bonds ]  Last focus: 41% · 10 min        Last focus: 38% · 10 min[ Genetics ]                    [ Ionic Bonds ]  Not started · 8 min             Not started · 8 min─────────────────────────────────────────────────────

## 3.3 Topic card — entry point

─────────────────────────────────────────────────────[ DNA Replication ]  Biology  Last session: 3 drifts · avg focus 41%  Estimated time: 8 min  [ Start Session ]─────────────────────────────────────────────────────

# 4. Full Student Session Flow

## Step 1 — Session start

Student taps Start Session1. Crown signal quality check   → all 8 channels confirmed   → signal quality score > threshold2. 30-second baseline calibration   → student focuses on a dot on screen   → app records personal EEG baseline   → personal attention threshold established   → (theta + alpha) / beta = baseline_index3. Session ID generated (6-char code e.g. abc123)   → displayed to student as session code   → Felipe's app enters this code to subscribe4. Session begins

## Step 2 — Phase 1: school content (primary layer)

Full screen loadsVisual style (intentionally boring):  White background  Dense Times New Roman text  Static black-and-white diagram  OR: dry lecture video embedded from YouTube  No colour, no animationFocus HUD at bottom (always visible):  [ focus bar ] [ θ ] [ α ] [ β ] [ γ ]  Updates every 1 second from CrownCrown recording EEG silentlyNo intervention while focusedContent advances at natural pace

## Step 3 — EEG attention monitoring

Every 1 second:  Python daemon computes:    attention_index = (theta + alpha) / beta    normalised against personal baseline  Attention states:    focused   → index ≤ 1.5× baseline    drifting  → index 1.5–2.2× baseline                confirmed: 2 consecutive windows (8 s)    lost      → index > 2.2× baseline                confirmed: 2 consecutive windows (8 s)  AttentionState emitted via WebSocket every 1 s  Tagged with session_id  Flutter subscribes via AttentionStream  ALSO sent to Felipe's teacher view  (same stream, filtered by session_id)

## Step 4 — Phase 2: RL rescue layer triggered

[EEG: drifting or lost detected]School content PAUSES at exact timestampRL agent observes current state:  {    attention_level,      // focused | drifting | lost    drift_duration,       // seconds    topic,                // 'DNA Replication'    subject,              // 'Biology'    formats_tried,        // [flashcard, video] already shown    session_number,       // 1 = cold start, 20+ = trained    time_in_session,      // seconds elapsed    student_history       // per-format success rates  }RL picks best intervention format

## Step 5 — RL agent decision policy

SESSION 1–5: Cold start — rule-based fallback  Mild drift   (4–8 s)   → Flashcard deck  Moderate     (8–20 s)  → Short video clip  Moderate alt (8–20 s)  → Interactive simulation  Severe       (20+ s)   → Voice challenge  Lost                   → Hand gesture game─────────────────────────────────────────────────SESSION 6–30: Contextual bandit policy  Context:  { attention_level, topic, session_number }  Action:   pick best format from history  Reward:   +1 if attention recovers in 60 s            -1 if attention does not recover  Example learned behaviour:  This student: flashcard → rarely recovers  This student: simulation → always recovers  Agent: stops showing flashcards, goes to simulation─────────────────────────────────────────────────SESSION 30+: DQN via TFLite  Input:  [focus_score, drift_duration, topic_id,           formats_tried, session_number, time_in_session]  Output: [flashcard, video, simulation,           voice, gesture, curiosity_bomb]  Runs entirely on device — no cloud ML

## Step 6 — Intervention formats

Format

Input modality

What the student does

Flashcard deck

Tap / swipe / mouse

Swipe cards — ionic or covalent? Which organelle? 5 cards per topic.

Short video clip

Passive + 1 tap

60–90 s autoplay clip (CrashCourse / Khan Academy). 1 question after.

Interactive simulation

Touch / mouse drag

Chem: drag electrons between atoms. Bio: drag organelles into blank cell.

Voice challenge

Microphone

App speaks question. Student answers aloud. Speech recognition checks.

Hand gesture game

Camera + MediaPipe

Chem: hold up fingers = number of bonds. Bio: point to organelle on screen.

Curiosity bomb

Passive

Full-screen surprising fact tied to topic. E.g. DNA would reach Pluto and back.

Draw it mode

Touch / stylus (iPad)

Blank canvas. Draw a cell and label 3 organelles. Shape recognition confirms.

## Step 7 — After each intervention

App measures EEG for 60 seconds after interventionIF attention recovered:  RL reward → +1  Agent remembers: this format worked for this student  Show 1 quick confirmation question  Show 1-sentence recap:    'You were learning how electrons are shared     in covalent bonds.'  School content resumes from EXACT timestampIF attention did not recover:  RL reward → -1  Agent remembers: this format failed  Agent picks next intervention immediately  Cascade continues until recovered or session endsIF student completes section while focused:  Real-world connection card appears (reward):    Bio:  'DNA pairing errors like this cause sickle cell.'    Chem: 'This bond type is how aspirin works in the body.'

## Step 8 — Session end

School content section completedOR session time limit reached (10 min)Session summary screen:─────────────────────────────────────────────  Session complete  Topic:          DNA Replication  Duration:       8 min  Avg focus:      67%  Interventions:  3  Most effective: Simulation  [Focus timeline — colour bar chart]  [ Done ]─────────────────────────────────────────────Data saved to SQLite locallyRL policy updated for this studentHome dashboard refreshed with new attention data

# 5. Content Structure — What Smit Builds

## 5.1 Subjects and topics

Subject

Topic

School content (primary layer)

Chemistry

Chemical Bonding

3 paragraphs on ionic vs covalent bonds + static bond diagram OR dry YouTube lecture

Chemistry

Periodic Table

3 paragraphs on groups, periods, reactivity + static periodic table image

Biology

Cell Structure

3 paragraphs on organelles + labelled cell diagram OR dry YouTube lecture

Biology

DNA Replication

3 paragraphs on base pairs, replication, double helix + static DNA diagram

## 5.2 Adaptive rescue content per topic

20 pieces total: 4 topics × 5 formats each. The 6th format (curiosity bomb) is generated dynamically per topic.

Format

Chemistry example

Biology example

Flashcard deck

Classify H₂O, NaCl, CO₂ — ionic or covalent?

Organelle → function: mitochondria, nucleus, ribosome

Short video clip

CrashCourse: electron sharing in covalent bonds (90 s)

Khan Academy: how organelles work together (90 s)

Simulation

Drag electrons between atoms to form stable bonds

Drag organelles into correct positions in blank cell

Voice challenge

'What type of bond forms in H₂O?' → student speaks

'Which organelle produces energy?' → student speaks

Hand gesture game

Hold up fingers = number of bonds in CH₄

Point to correct organelle shown on screen

# 6. Folder Structure — Student Side

Legend: Smit owns green · Felipe owns purple · Joint = amber · Auto-generated = plain

File / Folder

Purpose

Owner

lib/core/

Shared — frozen interfaces, services, data

Joint

models/attention_state.dart

AttentionState + AttentionLevel enum

Joint

models/session.dart

Session data model

Joint

models/user.dart

Student / teacher role model

Joint

services/websocket_client.dart

WS connect, reconnect, parse JSON

Joint

services/attention_stream.dart

Broadcast stream, forSession() filter

Joint

services/session_manager.dart

Session ID generation, join flow

Joint

services/eeg_service.dart

Spawns Python daemon subprocess

Joint

data/database.dart

Drift SQLite schema

Joint

data/session_dao.dart

Session CRUD

Joint

data/intervention_dao.dart

Intervention event log

Joint

theme/

Colors, typography, spacing

Joint

widgets/focus_gauge.dart

Circular focus score widget

Joint

widgets/band_power_bars.dart

θ α β γ bar widget

Joint

lib/student/

Smit owns entirely — Felipe never touches

Smit

student_shell.dart

Root widget, student role entry point

Smit

dashboard/

Home + Library tabs

Smit

home_tab.dart

Attention-prioritised topic cards

Smit

library_tab.dart

Full subject browser, free choice

Smit

topic_card.dart

Topic card with focus score + start button

Smit

lesson/

Primary school content layer

Smit

lesson_screen.dart

Full-screen lesson container

Smit

content_renderer.dart

Renders text, diagram, video

Smit

question_card.dart

MCQ / short answer interactive card

Smit

lesson_controller.dart

Pacing engine + progress state

Smit

curriculum_model.dart

Lesson / question data structures

Smit

intervention/

RL rescue layer

Smit

intervention_engine.dart

RL agent — picks format, measures reward

Smit

rule_router.dart

Cold-start fallback rules (session 1–5)

Smit

bandit_agent.dart

Contextual bandit (session 6–30)

Smit

dqn_agent.dart

DQN via TFLite (session 30+)

Smit

flashcard_screen.dart

Swipeable flashcard intervention

Smit

video_screen.dart

Embedded video player intervention

Smit

simulation_screen.dart

Drag-and-build interactive intervention

Smit

voice_screen.dart

Speech recognition intervention

Smit

gesture_screen.dart

MediaPipe hand tracking intervention

Smit

curiosity_bomb.dart

Full-screen surprising fact overlay

Smit

draw_screen.dart

Canvas draw-it-from-memory intervention

Smit

hud/

Focus heads-up display

Smit

focus_hud.dart

Bottom strip: score bar + band powers

Smit

hud_controller.dart

Subscribes to AttentionStream

Smit

session/

Session lifecycle screens

Smit

session_start_screen.dart

Crown check + baseline calibration

Smit

session_end_screen.dart

Summary, focus timeline, stats

Smit

lib/teacher/

Felipe owns entirely — Smit never touches

Felipe

teacher_shell.dart

Root widget, teacher role entry point

Felipe

monitor/

Live session monitoring

Felipe

sessions/

Multi-session switcher + join flow

Felipe

history/

Past session analytics + export

Felipe

main.dart

App entry — spawns daemon, role router

Joint

router.dart

GoRouter routes for all screens

Joint

daemon/attention_engine.py

Python BrainFlow script — research only

Smit

daemon/requirements.txt

pip dependencies

Smit

assets/curriculum/

Lesson JSON files per topic

Smit

# 7. How Smit's Side Connects to Felipe's Side

They never import from each other. The connection happens entirely through core/ shared services. Here is exactly what flows between them.

## 7.1 The data flow

Crown (WiFi/OSC)  ↓Python daemon (Smit's daemon/)  computes AttentionState  broadcasts over WebSocket port 8765  tags every message with session_id  ↓WebSocketClient (core/ — Joint)  receives JSON  parses to AttentionState  pushes to AttentionStream  ↓AttentionStream (core/ — Joint)  ┌─────────────────────────────────────┐  │                                     │  ↓                                     ↓HudController                    Teacher monitor(lib/student/ — Smit)            (lib/teacher/ — Felipe)  updates focus HUD               shows live focus score  ↓                               ↓InterventionEngine               InterventionFeed(lib/student/ — Smit)            (lib/teacher/ — Felipe)  RL decides rescue format         logs intervention events

## 7.2 Session linking — the session code

Smit's side (student):  SessionManager.generateSessionId()  → returns 'abc123'  → displayed on session start screen  → daemon tags all messages with 'abc123'Felipe's side (teacher):  Teacher enters 'abc123' in join screen  AttentionStream.forSession('abc123')  → filters stream to only that student  → Felipe's monitor shows that student's dataMultiple sessions simultaneously:  Student A → session 'abc123' → Teacher A  Student B → session 'xyz789' → Teacher B  No data mixing — session_id is the namespace

## 7.3 Network options

Option

Option A — same WiFi

Option B — different networks

How

Python WS server on port 8765. Both devices connect by local IP.

Daemon pushes to Supabase Realtime channel. Any network works.

When

Prototype — Week 1. Simplest setup.

Week 5 alongside session history feature.

What syncs

AttentionState only — no raw EEG ever transmitted.

AttentionState only — no raw EEG ever transmitted.

# 8. RL Agent — Three-Phase Progression

Sessions

Agent

How it decides

ML model

1–5

Rules

Fixed if/else cascade based on drift duration

None — pure Dart logic

6–30

Contextual bandit

Learns per-student format preferences from reward signal

Lightweight bandit — Dart, on device

30+

DQN

Full state-action-reward deep Q-network, generalises across topics

TFLite neural net — on device, no cloud

The reward signal is the EEG attention score measured 60 seconds after each intervention. This is what makes NeuroLearn's RL unique — the reward is not a proxy like quiz score or click pattern. It is the actual cognitive signal, direct from the brain.

// Swappable interface — rest of app never changesContentFormat selectFormat(AttentionState s, StudentProfile p) {  if (p.sessionCount <= 5)  return RuleRouter.select(s);  if (p.sessionCount <= 30) return BanditAgent.select(s, p);  return DQNAgent.select(s, p);}

# 9. Definition of Done — v1 Demo

1

Crown connects, signal quality confirms, 30 s baseline calibration completes

2

Home dashboard shows attention-prioritised topics from last session

3

Library tab shows all content — free browse by subject

4

School-style content plays (text + diagram OR YouTube video) with focus HUD

5

EEG drift triggers intervention within 4 seconds of confirmed drift

6

All 7 intervention formats work: flashcard, video, simulation, voice, gesture, curiosity bomb, draw-it

7

After intervention: attention measured, RL reward recorded, recap shown, content resumes from exact timestamp

8

Session summary shows focus timeline, drift count, most effective format

9

RL policy updates after each session — session 6+ makes different decisions than session 1

10

Felipe's teacher view connects via session code, sees live focus score in real time

11

Two simultaneous sessions run without data mixing

12

Session data persists in SQLite — dashboard reflects history on next open

NeuroLearn — Student Side Flow v1.0 · April 2026 · Smit builds student module · Felipe builds teacher module