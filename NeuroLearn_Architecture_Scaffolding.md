NeuroLearn

Architecture & Scaffolding Reference

EEG-Adaptive Learning Platform — Flutter + Neurosity Crown

v1.0 · April 2026 · Internal Developer Reference

# 1. Project Overview

NeuroLearn is a Flutter-based adaptive learning platform for desktop and iPad that uses the Neurosity Crown EEG headset to monitor a student's real-time attention. When cognitive drift is detected, the system automatically intervenes — pausing content, prompting a break, or stepping down difficulty — before the student falls behind.

This document covers the complete system architecture and the full project scaffold so both developers can work independently in the same repository without blocking each other.

Key facts

Platform

Flutter desktop (Windows / macOS) + iPad

Language

Dart (Flutter app) · Python 3.11 (research daemon only)

EEG device

Neurosity Crown — 8 ch, 256 Hz, OSC/WiFi stream

Developers

Smit (student module) + Felipe (teacher module)

Repo

Single monorepo — feature branches, PR to main

Database

SQLite on-device (drift package) · Supabase optional cloud

Transport

Local WebSocket port 8765 (Option A) / Supabase Realtime (Option B)

# 2. System Architecture

The system is split into five layers. Each layer has a single responsibility and communicates with adjacent layers through a defined interface.

## Layer 1 — Neurosity Crown (hardware)

Crown specs

Channels

8 — CP3, C3, F5, PO3, PO4, F6, C4, CP4 (10-20 system)

Sample rate

256 Hz

On-device DSP

N3 chipset: bandpass 0.5–50 Hz, 60 Hz notch, artifact rejection

Stream output

Raw EEG over OSC/UDP — WiFi to any machine on same network

Built-in scores

focus (0–1) and calm (0–1) — usable as fallback before custom classifier is trained

Haptics

Vibration motors at P7, P8 — usable for tactile re-engagement nudges

Auth

Device ID + email/password via Neurosity cloud (required for official SDK path)

## Layer 2 — EEG Signal Engine

Runs on the same desktop as the Crown. This is the only layer that touches raw EEG. Everything downstream receives only derived attention state.

Week 1–2

Python daemon using BrainFlow — fast iteration, validate algorithm with real Crown data

Week 3+

Port algorithm to Dart (dart:io UDP + FFT math) — runs inside Flutter desktop app as a service, no Python needed

Signal processing steps

Connect

BrainFlow BoardShim (CROWN_BOARD) receives OSC stream from Crown over local WiFi

Filter

Bandpass 1–45 Hz, detrend, artifact removal (BrainFlow built-in or scipy)

Window

4-second rolling window at 256 Hz = 1024 samples per compute cycle

Band power

Welch PSD on frontal channels (F5, F6) → theta (4–8 Hz), alpha (8–13 Hz), beta (13–30 Hz)

Index

attention_index = (theta + alpha) / beta — higher = less focused

Normalize

Divide by personal baseline (calibrated 30 s at session start)

Classify

focused (≤1.5×) | drifting (1.5–2.2×, 2 consecutive windows) | lost (>2.2×, 2 windows)

Broadcast

Emit AttentionState JSON over WebSocket every 1 second, tagged with session_id

## Layer 3 — Session Relay

Routes attention state from the EEG engine to all subscribed devices. Two options depending on network setup.

Option A — Local WebSocket (same WiFi)

Option B — Supabase Realtime (any network)

Recommended for prototype

Python WS server on port 8765

Both iPad and desktop connect by local IP

Zero latency, no internet required

Add in: Week 1

Add in week 5 alongside session history

Daemon pushes to Supabase channel by session_id

Teacher/parent subscribe from any network

Attention state only — raw EEG never relayed

Add in: Week 5

## Layer 4 — Flutter App (one app, two roles)

One Flutter app, role selected at login. Student view and teacher view are entirely separate navigation trees within the same app. The EEG service, SQLite store, and WebSocket client are shared background services.

Student view — Smit owns

Teacher / parent view — Felipe owns

- Full-screen lesson content renderer

- Interactive question cards

- Live focus HUD (band power bars, score)

- Intervention engine: break screen, scaffold, difficulty step-down

- Pacing engine — content advances when focused

- Session start flow + session code generator

- Live focus monitor per session

- Intervention event log

- Session history + trends

- Multi-session switcher (all active sessions)

- Session code join flow

- Export / report generation

## Layer 5 — Data Store

Storage

SQLite (drift)

On-device. Sessions, lesson progress, intervention events, EEG baseline. Default for all users.

Supabase

Optional. Anonymised session summaries only. Opt-in. No raw EEG, no raw band powers.

Privacy rule

Raw EEG never leaves the machine running the EEG engine. No exceptions.

# 3. Multi-Session Design

Multiple students can run simultaneously. Each session is namespaced by a unique session_id. The WebSocket server and Supabase channels both route by session_id — no data mixing between sessions.

Session code flow:  1. Student opens app → generates session_id (e.g. 'abc123')  2. App displays 6-character session code  3. Teacher enters code on their device  4. Teacher device subscribes to channel 'session:abc123'  5. All AttentionState messages from that student flow to that teacher onlySimultaneous example:  Student A → session_id: abc123 → Teacher A sees abc123  Student B → session_id: xyz789 → Teacher B sees xyz789  No cross-contamination of data

# 4. Frozen Interface — Shared Contract

This is the only data contract that crosses the boundary between student module and teacher module. Neither developer changes this without agreement from both. All other code is fully independent.

4.1 AttentionState model

// lib/core/models/attention_state.dartenum AttentionLevel { focused, drifting, lost }class AttentionState {  final String        sessionId;  final double        focusScore;   // 0.0 – 1.0  (1 = fully focused)  final double        theta;        // 4–8 Hz band power  final double        alpha;        // 8–13 Hz band power  final double        beta;         // 13–30 Hz band power  final double        gamma;        // 30–45 Hz band power  final AttentionLevel level;       // focused | drifting | lost  final DateTime      timestamp;  const AttentionState({    required this.sessionId,    required this.focusScore,    required this.theta,    required this.alpha,    required this.beta,    required this.gamma,    required this.level,    required this.timestamp,  });  factory AttentionState.fromJson(Map<String, dynamic> j) => AttentionState(    sessionId:  j['session_id'],    focusScore: (j['focus_score'] as num).toDouble(),    theta:      (j['theta'] as num).toDouble(),    alpha:      (j['alpha'] as num).toDouble(),    beta:       (j['beta']  as num).toDouble(),    gamma:      (j['gamma'] as num).toDouble(),    level:      AttentionLevel.values.byName(j['level']),    timestamp:  DateTime.fromMillisecondsSinceEpoch(                  (j['timestamp'] * 1000).toInt()),  );}

4.2 WebSocket message schema (daemon → Flutter)

{  "session_id":  "abc123",  "focus_score": 0.72,  "theta":       0.41,  "alpha":       0.28,  "beta":        0.81,  "gamma":       0.45,  "level":       "focused",  "timestamp":   1712345678.123}

4.3 Session model

// lib/core/models/session.dartclass Session {  final String   sessionId;  final String   studentName;  final DateTime startedAt;  final DateTime? endedAt;  final double   avgFocusScore;  final int      interventionCount;  final int      lessonsCompleted;}

# 5. Project Scaffold — Full Folder Structure

Legend:

Smit

Felipe

Joint

Auto-gen

File / Folder

Purpose

Owner

neurolearn/

Flutter project root

Joint

pubspec.yaml

Dependencies declaration

Joint

pubspec.lock

Auto-generated — do not edit

analysis_options.yaml

Lint rules

Joint

.gitignore

Git ignore rules

Joint

CLAUDE.md

Persistent context for Claude Code

Joint

README.md

Project overview + setup instructions

Joint

lib/

Dart source root

core/

Shared — owned jointly, no unilateral changes

Joint

models/

Data classes

Joint

attention_state.dart

AttentionState + AttentionLevel enum

Joint

session.dart

Session model

Joint

user.dart

User/role model

Joint

services/

Background services

Joint

websocket_client.dart

WS connect, subscribe, reconnect logic

Joint

eeg_service.dart

Spawns Python daemon subprocess (desktop)

Joint

session_manager.dart

Session code generation + join

Joint

attention_stream.dart

StreamController — broadcasts AttentionState

Joint

data/

SQLite persistence

Joint

database.dart

Drift database definition

Joint

session_dao.dart

Session CRUD operations

Joint

intervention_dao.dart

Intervention event log

Joint

theme/

Design system

Joint

app_theme.dart

ThemeData, colors, typography

Joint

app_colors.dart

Color constants

Joint

app_spacing.dart

Spacing scale

Joint

widgets/

Shared UI components

Joint

focus_gauge.dart

Circular focus score widget

Joint

band_power_bars.dart

θ α β γ bar chart widget

Joint

session_code_display.dart

6-char code display widget

Joint

error_state.dart

Connection lost / error UI

Joint

student/

Student module — Smit owns entirely

Smit

student_shell.dart

Root widget, role entry point

Smit

lesson/

Learning content layer

Smit

lesson_screen.dart

Full-screen lesson container

Smit

content_renderer.dart

Renders text, image, video content

Smit

question_card.dart

Interactive MCQ / short answer card

Smit

lesson_controller.dart

Pacing engine + progress state

Smit

curriculum_model.dart

Lesson/question data structures

Smit

intervention/

Re-engagement layer

Smit

intervention_engine.dart

Classifies level → picks intervention

Smit

break_screen.dart

30-60 s micro-break overlay

Smit

scaffold_screen.dart

Simplified content re-scaffold view

Smit

difficulty_adapter.dart

Steps difficulty up/down by state

Smit

hud/

Focus heads-up display

Smit

focus_hud.dart

Bottom strip: score + band bars

Smit

hud_controller.dart

Subscribes to attention_stream

Smit

session/

Session start/end flow

Smit

session_start_screen.dart

Crown check + code generation

Smit

session_end_screen.dart

Summary + progress recap

Smit

teacher/

Teacher module — Felipe owns entirely

Felipe

teacher_shell.dart

Root widget, role entry point

Felipe

monitor/

Live session monitoring

Felipe

monitor_screen.dart

Live focus + intervention feed

Felipe

focus_timeline.dart

Scrolling focus chart over time

Felipe

intervention_feed.dart

Real-time intervention event list

Felipe

monitor_controller.dart

Subscribes to attention_stream by session

Felipe

sessions/

Multi-session management

Felipe

session_list_screen.dart

All active sessions grid

Felipe

join_session_screen.dart

Enter session code to subscribe

Felipe

session_tile.dart

Per-student summary card

Felipe

history/

Past session analytics

Felipe

history_screen.dart

Session log list

Felipe

session_detail_screen.dart

Full session replay + stats

Felipe

export_service.dart

CSV / PDF session export

Felipe

main.dart

App entry — spawns daemon, role router

Joint

router.dart

GoRouter routes for all screens

Joint

daemon/

Python EEG research daemon (not shipped)

Smit

attention_engine.py

BrainFlow → attention index → WebSocket

Smit

requirements.txt

pip dependencies

Smit

build.sh

PyInstaller freeze script (future)

Smit

test/

Test files

core/

Shared model + service tests

Joint

student/

Student module unit tests

Smit

teacher/

Teacher module unit tests

Felipe

assets/

Static assets

Joint

curriculum/

Lesson JSON files

Smit

images/

UI images

Joint

# 6. Key File Stubs

These are the starting-point implementations for the most important shared files. Both developers should agree on these before branching.

## 6.1 main.dart

// lib/main.dartimport 'package:flutter/material.dart';import 'core/services/eeg_service.dart';import 'router.dart';void main() async {  WidgetsFlutterBinding.ensureInitialized();  if (isDesktop()) await EEGService.instance.startDaemon();  runApp(const NeuroLearnApp());}class NeuroLearnApp extends StatelessWidget {  const NeuroLearnApp({super.key});  @override  Widget build(BuildContext context) =>    MaterialApp.router(routerConfig: appRouter);}

## 6.2 router.dart

// lib/router.dartimport 'package:go_router/go_router.dart';import 'student/student_shell.dart';import 'teacher/teacher_shell.dart';final appRouter = GoRouter(  initialLocation: '/login',  routes: [    GoRoute(path: '/login',   builder: (_, __) => const LoginScreen()),    GoRoute(path: '/student', builder: (_, __) => const StudentShell()),    GoRoute(path: '/teacher', builder: (_, __) => const TeacherShell()),  ],);// Login screen routes to /student or /teacher based on role selection.// StudentShell and TeacherShell are completely separate nav trees.// Neither imports anything from the other.

## 6.3 attention_stream.dart

// lib/core/services/attention_stream.dartimport 'dart:async';import '../models/attention_state.dart';class AttentionStream {  AttentionStream._();  static final instance = AttentionStream._();  final _controller = StreamController<AttentionState>.broadcast();  Stream<AttentionState> get stream => _controller.stream;  // Called by WebSocketClient when a new message arrives  void emit(AttentionState state) => _controller.add(state);  // Filter by session — used by teacher monitor  Stream<AttentionState> forSession(String sessionId) =>    stream.where((s) => s.sessionId == sessionId);}

## 6.4 websocket_client.dart

// lib/core/services/websocket_client.dartimport 'dart:convert';import 'package:web_socket_channel/web_socket_channel.dart';import '../models/attention_state.dart';import 'attention_stream.dart';class WebSocketClient {  WebSocketClient._();  static final instance = WebSocketClient._();  WebSocketChannel? _channel;  Future<void> connect(String url) async {    _channel = WebSocketChannel.connect(Uri.parse(url));    _channel!.stream.listen(      (raw) {        final json = jsonDecode(raw as String);        AttentionStream.instance.emit(AttentionState.fromJson(json));      },      onError: (e) => _reconnect(url),      onDone:  () => _reconnect(url),    );  }  Future<void> _reconnect(String url) async {    await Future.delayed(const Duration(seconds: 3));    await connect(url);  }  void dispose() => _channel?.sink.close();}

## 6.5 student_shell.dart (stub)

// lib/student/student_shell.dart// Smit owns this file and everything under lib/student/import 'package:flutter/material.dart';class StudentShell extends StatelessWidget {  const StudentShell({super.key});  @override  Widget build(BuildContext context) {    // TODO: Smit — implement lesson screen, HUD, interventions    return const Scaffold(      body: Center(child: Text('Student view — coming soon')),    );  }}

## 6.6 teacher_shell.dart (stub)

// lib/teacher/teacher_shell.dart// Felipe owns this file and everything under lib/teacher/import 'package:flutter/material.dart';class TeacherShell extends StatelessWidget {  const TeacherShell({super.key});  @override  Widget build(BuildContext context) {    // TODO: Felipe — implement monitor, session list, history    return const Scaffold(      body: Center(child: Text('Teacher view — coming soon')),    );  }}

# 7. pubspec.yaml — Dependencies

name: neurolearndescription: EEG-adaptive learning platformversion: 1.0.0+1environment:  sdk: '>=3.3.0 <4.0.0'dependencies:  flutter:    sdk: flutter  # Navigation  go_router: ^13.0.0  # WebSocket  web_socket_channel: ^2.4.0  # State management  riverpod: ^2.5.0  flutter_riverpod: ^2.5.0  # Local database  drift: ^2.18.0  sqlite3_flutter_libs: ^0.5.0  path_provider: ^2.1.0  path: ^1.9.0  # Optional cloud  supabase_flutter: ^2.3.0  # Utilities  uuid: ^4.3.0  intl: ^0.19.0dev_dependencies:  flutter_test:    sdk: flutter  build_runner: ^2.4.0  drift_dev: ^2.18.0  flutter_lints: ^3.0.0

# 8. Collaboration Rules

## 8.1 Branching strategy

- main — always deployable, protected branch

- feature/smit/xxx — Smit's feature branches

- feature/friend/xxx — Felipe's feature branches

- PR required to merge to main — at least one approval

- Never commit directly to main

## 8.2 Module boundaries

- lib/student/ — Smit owns entirely. Felipe never touches.

- lib/teacher/ — Felipe owns entirely. Smit never touches.

- lib/core/ — Joint ownership. Discuss before changing.

- No direct imports between student/ and teacher/

- Both modules consume core/ through its public interfaces only

## 8.3 Frozen interface rule

RULE

AttentionState, Session, and the WebSocket JSON schema are frozen. Neither developer changes them without written agreement from both. These are the load-bearing interfaces — a breaking change here breaks both modules.

## 8.4 Adding to core/

- Create a GitHub issue first describing the change

- Both developers agree before any PR is raised

- New additions (new fields, new services) are lower risk than modifications

- Deletions from core/ require both developers to confirm no usages in their module

## 8.5 Git workflow

# Start a new featuregit checkout main && git pullgit checkout -b feature/smit/intervention-engine# Work, commit, pushgit add lib/student/intervention/git commit -m 'feat(student): add intervention engine cascade'git push origin feature/smit/intervention-engine# Open PR → request review → merge to main# Delete branch after merge

# 9. Implementation Roadmap

Week

Owner

Smit (student)

Felipe (teacher)

1–2

Smit

Python daemon — validate attention index with real Crown data. Confirm window, channels, thresholds.

—

1–2

Felipe

—

Flutter project scaffold. Implement core/models, core/services, WebSocket client, SQLite drift setup, router, app theme.

3

Smit

Port attention algorithm to Dart. Lesson screen + content renderer + question cards.

Teacher live monitor screen. Session code join flow. Multi-session routing.

4

Smit

Intervention engine: break screen, scaffold, difficulty step-down. Focus HUD.

Session history screen. Intervention event log. Basic focus trend chart.

5

Both

Supabase Realtime relay. Cross-network session support.

Supabase session history sync. End-to-end multi-device test.

6

Both

iPad layout polish. Connection-lost state. Crown signal quality checks.

Export/report generation. Multi-session dashboard. Demo-ready build.

# 10. Setup Instructions

## 10.1 Flutter app setup (both developers)

# 1. Clone repogit clone https://github.com/your-org/neurolearn.gitcd neurolearn# 2. Install Flutter dependenciesflutter pub get# 3. Generate drift database codedart run build_runner build# 4. Run on desktopflutter run -d macos   # or -d windows# 5. Run on iPad (requires mac + Xcode)flutter run -d <your-ipad-udid>

## 10.2 Python daemon setup (Smit — weeks 1–2)

cd daemon/pip install -r requirements.txt# Ensure Crown is on same WiFi# Enable OSC streaming in Neurosity apppython attention_engine.py# Output: WebSocket server on ws://0.0.0.0:8765# Flutter app connects to ws://localhost:8765 (desktop)# iPad connects to ws://<desktop-local-ip>:8765

## 10.3 CLAUDE.md — persistent context for Claude Code

# neurolearn/CLAUDE.md## ProjectNeuroLearn — EEG adaptive learning Flutter app## Module ownership- lib/student/  → Smit- lib/teacher/  → Felipe- lib/core/     → joint (discuss before changing)## Frozen interface- lib/core/models/attention_state.dart — do not modify without agreement- WebSocket JSON schema — do not modify without agreement## Tech stackFlutter 3.x / Dart, go_router, riverpod, drift, SupabasePython 3.11 / BrainFlow (daemon research only)## Run commandsflutter pub get && dart run build_runner buildflutter run -d macos

NeuroLearn — Architecture & Scaffolding Reference v1.0 — April 2026