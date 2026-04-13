# NeuroLearn — Product Requirements Document

> Generated on 2026-04-12

## 1. Product Overview

### Vision
NeuroLearn is an EEG-adaptive learning platform that monitors a student's real-time brain activity through the Neurosity Crown headset and automatically intervenes when cognitive drift is detected. Unlike conventional adaptive learning systems that rely on behavioral proxies (quiz scores, click patterns, time-on-task), NeuroLearn uses the actual neural signal — band power ratios from frontal EEG channels — as both the drift detector and the reinforcement learning reward. A teacher can monitor any student's focus state live from a separate device using a session code, without ever accessing raw brain data.

### Problem Statement
Students lose focus during academic content and don't realize it until they've already fallen behind. Teachers can't see attention drift happening in real time — they only discover it after a failed quiz or a blank stare. Current adaptive learning platforms (ALEKS, DreamBox, Knewton) adjust difficulty based on quiz answers, which means they detect problems *after* the student has already disengaged. There's no system that catches drift *at the neural level* and intervenes *before* the student fails.

The cost: students waste time re-reading content they absorbed nothing from. Teachers intervene too late. Students with variable attention (not necessarily ADHD — any student who zones out during dry content) fall behind systematically.

### Target Audience
- **Primary**: K-12 and university students studying STEM subjects who want to learn more effectively, paired with tutors or teachers who want real-time visibility into student engagement.
- **Secondary**: Education researchers who want objective EEG-based attention data correlated with learning outcomes.
- **Not targeting**: Clinical ADHD treatment (no medical claims), classroom-scale deployment (v1 is 1 student : 1 Crown : 1 desktop).

### Value Proposition
NeuroLearn is the only product that:
1. Uses **real-time EEG** (not quiz scores) to detect attention drift within 8 seconds
2. Deploys a **reinforcement learning agent** whose reward signal is the brain's own recovery response
3. Learns which intervention format works best **per individual student** across sessions
4. Gives teachers **live neural-level engagement data** without exposing raw brain signals
5. Runs **100% on-device** — raw EEG never leaves the student's machine

---

## 2. Competitive Landscape

| Product | Approach | Strengths | Weaknesses |
|---------|----------|-----------|------------|
| **Myndlift + Muse** | Neurofeedback training via games — focus up = game responds. 1.2M+ sessions. Clinician dashboard. | Proven neurofeedback model, FDA-cleared Muse hardware, large user base | Trains focus as a generic skill. No academic content integration. No lesson delivery. No adaptive intervention selection. |
| **ALEKS (McGraw Hill)** | Knowledge-state modeling via quiz performance. AI determines what student knows/doesn't know/is ready to learn. | Sophisticated knowledge graph, proven at scale in universities | Uses behavioral proxies only — can't detect drift before a wrong answer. Single modality (text+quiz). No EEG. |
| **DreamBox** | K-8 math with real-time difficulty adjustment based on *how* students solve problems. | Watches process, not just answers. Engaging UI for young students. | Math-only. Still behavioral signals. No cross-modality interventions. No teacher live view. |
| **BrainAccess** | Research-grade EEG platform for hyperscanning and classroom engagement monitoring. | High-quality EEG data, academic credibility, multi-student capable | Research tool, not a consumer product. No intervention engine. No RL. No adaptive content. |
| **IEEE DDQN Research** | Academic papers using Double Deep Q-Networks on EEG for attention classification (98.2% accuracy). | State-of-the-art classification accuracy on EEG attention data | Pure research — no consumer app, no intervention system, no teacher view, no content delivery. |

### Opportunity
No product combines: real-time EEG attention monitoring + adaptive content delivery + RL-selected multi-modal interventions + teacher live monitoring in a single consumer app. The $5.1B adaptive learning market (growing to $12.7B by 2030 at 20% CAGR) is entirely driven by behavioral-proxy systems. NeuroLearn introduces a fundamentally different signal source — the brain itself — making every intervention decision and personalization claim neurologically grounded rather than statistically inferred.

---

## 3. Users

| User Type | Description | Primary Goal | Key Pain Points |
|-----------|-------------|-------------|-----------------|
| **Student** | K-12 or university student studying STEM (Biology, Chemistry). Has a Neurosity Crown. Uses a Windows desktop or iPad. | Learn academic content effectively without losing focus and falling behind | Zones out during dry content and doesn't realize it. Re-reads material without retention. No feedback on *when* or *why* they lose focus. Existing tools only tell them after they get a question wrong. |
| **Teacher/Tutor** | Teacher, tutor, or parent monitoring a student's learning session from a separate device. | See real-time engagement data to know when to intervene or adjust teaching approach | Can't see attention drift in real time. Only discovers disengagement after failed assessments. No objective data on which teaching formats work for which student. |
| **Researcher** (future) | Education researcher collecting attention data correlated with learning outcomes. | Gather objective EEG-engagement metrics across students and content types | Current tools rely on self-report or behavioral proxies. No ground-truth neural engagement data paired with intervention outcomes. |

### User Journeys

#### Student — First Learning Session
1. **Discovery** — Student gets NeuroLearn app + Neurosity Crown from teacher/tutor or purchases independently
2. **Setup** — Opens app, selects "I'm a Student", puts on Crown
3. **Calibration** — 30-second focus-on-a-dot baseline calibration establishes personal attention threshold
4. **Session code** — 6-char code generated (e.g., "abc123"), shared with teacher if monitoring desired
5. **Learning** — Reads school-style content (text + diagrams) with live focus HUD at bottom
6. **Intervention** — Brain drifts → content pauses → RL picks best rescue format → student completes intervention
7. **Recovery** — Attention recovers → recap sentence → content resumes from exact pause point
8. **Session end** — Summary screen: avg focus, drift count, most effective format, focus timeline
9. **Return** — Next session, dashboard shows attention-prioritized topics (worst focus = shown first)

#### Teacher — Live Monitoring Session
1. **Discovery** — Gets NeuroLearn app, selects "I'm a Teacher"
2. **Join** — Enters 6-char session code from student
3. **Monitor** — Sees live focus score, band power bars, intervention event feed in real time
4. **Review** — After session, reviews history: focus trends, intervention effectiveness, session comparisons
5. **Export** — Downloads session report (CSV/PDF) for records

---

## 4. Functional Requirements

| ID | Domain | Requirement | Priority | User Type | Source |
|----|--------|-------------|----------|-----------|--------|
| FR-01 | EEG Daemon | Python daemon connects to Neurosity Crown via BrainFlow, computes band powers (theta/alpha/beta/gamma) using Welch PSD on frontal channels (F5, F6), calculates attention index = (theta+alpha)/beta normalized against personal baseline, classifies into focused/drifting/lost with 2-window hysteresis, emits AttentionState JSON every 1s over WebSocket port 8765 | Must-have | Student | User |
| FR-02 | EEG Daemon | Mock daemon mode that generates realistic synthetic EEG patterns (drift cycles, recovery patterns, natural variation) for testing without Crown hardware | Must-have | Student | User |
| FR-03 | Session | Session start flow: Crown signal quality check → 30s baseline calibration (focus on dot) → session ID generation (6-char) → session code display | Must-have | Student | User |
| FR-04 | Session | Session end flow: summary screen showing duration, avg focus score, intervention count, most effective format, color-coded focus timeline bar chart. Data saved to SQLite. | Must-have | Student | User |
| FR-05 | Session | Session code sharing: student sees code on-screen, teacher enters code on their device to subscribe to that student's live stream | Must-have | Both | User |
| FR-06 | Lesson | Full-screen lesson content renderer for school-style content: dense text paragraphs, static diagrams, embedded YouTube videos. Intentionally low-stimulation visual design (white background, Times New Roman, no color). | Must-have | Student | User |
| FR-07 | Lesson | Curriculum content for 4 topics (Chemical Bonding, Periodic Table, Cell Structure, DNA Replication) with real educational text, diagrams, and video links | Must-have | Student | User |
| FR-08 | Lesson | Pacing engine: content advances at natural pace while focused, pauses immediately when drifting/lost detected, resumes from exact pause point after recovery | Must-have | Student | User |
| FR-09 | HUD | Live focus heads-up display: bottom strip showing focus score gauge + theta/alpha/beta/gamma band power bars, updating every 1 second from Crown stream | Must-have | Student | User |
| FR-10 | Intervention | Intervention engine: when drifting/lost detected, pauses content, queries RL agent for best format, launches intervention screen, measures EEG for 60s post-intervention, computes reward (+1 recovered / -1 not), updates RL policy | Must-have | Student | User |
| FR-11 | Intervention | Simulation intervention: drag-and-drop interactive (Chem: drag electrons to form bonds; Bio: drag organelles into cell) | Must-have | Student | User |
| FR-12 | Intervention | Gesture intervention: hand gesture recognition via camera/MediaPipe (Chem: hold up fingers = bond count; Bio: point to organelle) | Must-have | Student | User |
| FR-13 | Intervention | Flashcard intervention: swipeable 5-card deck per topic (e.g., classify ionic vs covalent, match organelle to function) | Must-have | Student | User |
| FR-14 | Intervention | Voice challenge intervention: app speaks question, student answers aloud, speech recognition checks answer | Must-have | Student | User |
| FR-15 | Intervention | Curiosity bomb: full-screen surprising fact tied to current topic (e.g., "DNA stretched out would reach Pluto and back") | Should-have | Student | User |
| FR-16 | Intervention | Video clip intervention: 60-90s autoplay educational video (CrashCourse/Khan Academy) + 1 comprehension question after | Should-have | Student | User |
| FR-17 | Intervention | Draw-it mode: blank canvas, student draws concept from memory (e.g., draw a cell, label 3 organelles), shape recognition confirms | Won't-have | Student | User |
| FR-18 | RL Agent | Rule-based fallback (sessions 1-5): fixed cascade by drift duration — mild (4-8s) → flashcard, moderate (8-20s) → video/simulation, severe (20+s) → voice, lost → gesture | Must-have | Student | User |
| FR-19 | RL Agent | Contextual bandit (sessions 6-30): learns per-student format preferences from historical reward signals. Context: {attention_level, topic, session_number}. Action: pick format. Reward: EEG recovery in 60s. | Should-have | Student | User |
| FR-20 | RL Agent | DQN via TFLite (sessions 30+): full state-action-reward deep Q-network with input [focus_score, drift_duration, topic_id, formats_tried, session_number, time_in_session], output distribution over all formats. Runs entirely on-device. | Won't-have | Student | User |
| FR-21 | Dashboard | Student home tab: attention-prioritized topic cards showing focus score, drift count, status (needs work / in progress / strong). Worst topics surface first. Filter by subject. | Must-have | Student | User |
| FR-22 | Dashboard | Student library tab: full content browser organized by subject (Biology, Chemistry). Shows all topics with last focus score, estimated time. Filter by subject. | Must-have | Student | User |
| FR-23 | Dashboard | Topic card: shows topic name, subject, last session stats (drifts, avg focus), estimated time, "Start Session" button | Must-have | Student | User |
| FR-24 | Post-intervention | After successful recovery: 1 quick confirmation question + 1-sentence recap of where student was in the lesson + content resumes from exact timestamp | Must-have | Student | User |
| FR-25 | Post-intervention | After failed recovery (attention not recovered in 60s): RL picks next intervention immediately, cascade continues until recovered or session ends | Must-have | Student | User |
| FR-26 | Post-intervention | Section completion reward: real-world connection card (e.g., "DNA pairing errors like this cause sickle cell disease") shown when student completes a section while focused | Should-have | Student | User |
| FR-27 | Teacher Monitor | Live focus monitor: real-time focus score gauge + band power bars for a specific student, updating every 1 second via AttentionStream.forSession(sessionId) | Must-have | Teacher | User |
| FR-28 | Teacher Monitor | Session code join flow: teacher enters 6-char session code to subscribe to a student's live stream | Must-have | Teacher | User |
| FR-29 | Teacher Monitor | Intervention event feed: real-time list of intervention events (format shown, drift duration, recovery status) for the monitored session | Should-have | Teacher | User |
| FR-30 | Teacher History | Session history screen: list of all past sessions with student name, topic, avg focus, intervention count, date. Sortable and filterable. | Should-have | Teacher | User |
| FR-31 | Teacher History | Session detail screen: full session stats + focus timeline chart + intervention breakdown for a specific past session | Should-have | Teacher | User |
| FR-32 | Teacher Export | Export session data as CSV or PDF report | Could-have | Teacher | User |
| FR-33 | Teacher Multi-session | Multi-session dashboard: view multiple active students simultaneously, each showing live focus score summary | Could-have | Teacher | User |
| FR-34 | Auth | Role picker at app start: "I'm a Student" / "I'm a Teacher". No authentication in v1 — identity is local. | Must-have | Both | User |
| FR-35 | Data | All session data, intervention events, and baselines persisted to SQLite via Drift. Local-first, on-device. | Must-have | Both | User |
| FR-36 | Data | Reactive data streams: session list and intervention events watchable via Drift streams for live UI updates | Must-have | Both | Suggested |
| FR-37 | Privacy | Raw EEG data never leaves the machine running the daemon. Only derived AttentionState (focus score + band powers + level) is transmitted via WebSocket. | Must-have | Both | User |
| FR-38 | Cloud Sync | Supabase Realtime relay: daemon pushes AttentionState to Supabase channel by session_id, enabling teacher monitoring from different network. Anonymized session summaries only. | Won't-have | Both | User |
| FR-39 | Cloud Sync | Supabase Postgres: optional cloud storage for anonymized session summaries. Opt-in. No raw EEG, no raw band powers. | Won't-have | Both | User |
| FR-40 | Connectivity | WebSocket auto-reconnect: if connection to daemon drops, retry every 3 seconds with visual indicator (ErrorState widget). | Must-have | Both | Suggested |
| FR-41 | Connectivity | Connection status indicator in HUD/monitor: green = connected, yellow = reconnecting, red = disconnected | Should-have | Both | Suggested |
| FR-42 | Onboarding | First-launch tutorial overlay explaining: what the Crown does, how calibration works, what the focus HUD means, what happens during an intervention | Should-have | Student | Suggested |
| FR-43 | Lesson | Confirmation question after each intervention: 1 MCQ or short-answer question related to the content being studied, to verify re-engagement | Must-have | Student | User |
| FR-44 | Teacher Monitor | Focus timeline chart: scrolling time-series visualization of focus score over the session duration, color-coded by attention level | Should-have | Teacher | Suggested |

### Priority Summary
- **Must-have:** 25 requirements
- **Should-have:** 11 requirements
- **Could-have:** 2 requirements
- **Won't-have:** 4 requirements (deferred to post-demo)

### Won't-Have (Explicitly Deferred)

| ID | Requirement | Reason for Deferral |
|----|-------------|-------------------|
| FR-17 | Draw-it mode intervention | Requires shape recognition ML model — complexity too high for demo deadline |
| FR-20 | DQN agent (sessions 30+) | Requires TFLite integration + significant training data. Rule-based + bandit sufficient for demo and early launch. |
| FR-38 | Supabase Realtime relay | Week 5 feature. Demo uses local WebSocket (same WiFi). |
| FR-39 | Supabase cloud storage | Week 5 feature. Local SQLite sufficient for demo and early use. |

---

### User Story Flows

#### USF-01: EEG Daemon — Crown Connection & Attention Broadcast (FR-01)

**As a** student, **I want** the app to connect to my Crown and broadcast my attention state, **so that** the system can detect when I'm drifting.

**Precondition:** Neurosity Crown is powered on and on the same WiFi network as the desktop. Python daemon dependencies installed.

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | Student launches NeuroLearn app on desktop | App calls EEGService.startDaemon() which spawns `python daemon/attention_engine.py` as a detached process |
| 2 | — (automatic) | Daemon connects to Crown via BrainFlow BoardShim (CROWN_BOARD), receives OSC stream |
| 3 | — (automatic) | Daemon applies bandpass filter (1-45 Hz), detrend, artifact removal |
| 4 | — (automatic) | Every 1 second: daemon computes 4s rolling window (1024 samples), Welch PSD on F5/F6 → theta, alpha, beta, gamma band powers |
| 5 | — (automatic) | Daemon calculates attention_index = (theta+alpha)/beta, normalizes against personal baseline |
| 6 | — (automatic) | Daemon classifies: focused (≤1.5x) / drifting (1.5-2.2x, 2 consecutive windows) / lost (>2.2x, 2 consecutive windows) |
| 7 | — (automatic) | Daemon emits JSON `{session_id, focus_score, theta, alpha, beta, gamma, level, timestamp}` over WebSocket port 8765 |
| 8 | — (automatic) | Flutter WebSocketClient receives JSON, parses to AttentionState, pushes to AttentionStream broadcast |

**Expected Outcome:** AttentionState updates flow into the app every 1 second. HUD and teacher monitor both receive live data.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| Crown not found | Crown is off or not on WiFi | Daemon logs "Crown not found" error, app shows ErrorState widget with "Connect your Crown and retry" message |
| Crown disconnects mid-session | WiFi drop or Crown battery dies | Daemon detects BrainFlow disconnect, stops emitting. WebSocket stays open. App shows "Crown disconnected — reconnect to continue" with retry button. Session data preserved. |
| Daemon crash | Python exception | WebSocket closes. Flutter auto-reconnect triggers every 3s. After 3 failed attempts, app shows "EEG service unavailable" error with "Restart" button that calls EEGService.startDaemon() again. |

---

#### USF-02: Mock Daemon — Testing Without Crown (FR-02)

**As a** developer or demo presenter, **I want** a mock daemon that generates realistic fake EEG data, **so that** I can test and demo the full app without Crown hardware.

**Precondition:** Python installed, daemon requirements installed.

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | Run `python daemon/attention_engine.py --mock` | Daemon starts in mock mode, opens WebSocket server on port 8765 |
| 2 | — (automatic) | Mock generates realistic attention cycles: ~60s focused → ~15s gradual drift → ~10s intervention window → recovery. Natural noise variation on all band powers. |
| 3 | — (automatic) | Emits same JSON schema as real daemon every 1 second |
| 4 | Flutter app connects | App cannot distinguish mock from real — identical data flow |

**Expected Outcome:** Full app experience with realistic-looking attention data. Drift events trigger interventions naturally.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| Port 8765 already in use | Previous daemon instance still running | Mock prints "Port 8765 in use — kill existing process" and exits |

---

#### USF-03: Session Start — Calibration & Code Generation (FR-03)

**As a** student, **I want** to calibrate the Crown to my personal baseline before starting a session, **so that** drift detection is accurate for me.

**Precondition:** App is open, student selected "I'm a Student", Crown connected (or mock daemon running).

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | Student taps topic card → "Start Session" | App navigates to session start screen |
| 2 | — (automatic) | App checks Crown signal quality across all 8 channels. Shows channel status indicators (green = good, red = poor). |
| 3 | If signal poor: student adjusts Crown fit | Signal quality updates in real time until all channels green |
| 4 | Student taps "Begin Calibration" | Screen shows a fixation dot. Timer counts down from 30 seconds. "Focus on the dot and breathe normally." |
| 5 | — (automatic, 30s) | Daemon records EEG during calibration, computes personal baseline_index = mean((theta+alpha)/beta). Stores in Baselines table via Drift. |
| 6 | — (automatic) | SessionManager.startSession() generates 6-char session_id. Session inserted into Sessions table. |
| 7 | — (automatic) | Screen shows session code (e.g., "abc123") via SessionCodeDisplay widget. "Share this code with your teacher." |
| 8 | Student taps "Start Learning" | Navigation to lesson screen. Session timer begins. Daemon starts tagging all messages with this session_id. |

**Expected Outcome:** Personal baseline calibrated, session created in DB, code visible for teacher sharing, lesson begins.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| Poor signal quality | Crown not properly seated | Calibration button disabled. "Adjust your Crown — channels highlighted in red need better contact." |
| Calibration interrupted | Student navigates away during 30s | Calibration cancelled, no session created. "Calibration incomplete — try again." |
| Crown disconnects during calibration | WiFi/battery | Calibration stops, error message shown, retry from step 1 |

---

#### USF-04: Lesson — Content Delivery with Focus HUD (FR-06, FR-08, FR-09)

**As a** student, **I want** to read school content with a live focus display, **so that** I can see how engaged my brain is while learning.

**Precondition:** Session started, calibration complete, lesson content loaded for selected topic.

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | — (automatic) | Lesson screen loads full-screen content: dense text paragraphs + static diagram OR embedded YouTube video. White background, Times New Roman, minimal design. |
| 2 | Student reads content | Focus HUD at bottom shows: circular focus gauge (0-100%) + 4 band power bars (theta, alpha, beta, gamma). Updates every 1 second. |
| 3 | Student scrolls or content auto-paces | Content advances at natural reading pace while AttentionLevel == focused |
| 4 | — (when drifting detected) | Content immediately pauses at exact scroll position / video timestamp. HUD color shifts from green to amber/red. Intervention engine triggered (see USF-06). |
| 5 | — (after recovery) | Content resumes from exact pause point. Recap sentence shown: "You were learning about [concept]." |
| 6 | Student completes section | Section complete screen: real-world connection card (if focused) OR summary card. Progress saved to SQLite. |

**Expected Outcome:** Student reads content with real-time focus feedback. Content pauses automatically on drift and resumes after intervention.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| WebSocket disconnects | Network issue | HUD shows "Reconnecting..." in yellow. Content continues but no drift detection. Auto-reconnect every 3s. |
| YouTube video fails to load | No internet or broken link | Fallback to text-only content for that section. "Video unavailable — read the text version below." |

---

#### USF-05: Student Dashboard — Topic Selection (FR-21, FR-22, FR-23)

**As a** student, **I want** to see my topics prioritized by how much I struggled, **so that** I focus on what needs the most work.

**Precondition:** Student has selected "I'm a Student". At least one prior session exists (or showing fresh state for first-time user).

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | App loads student shell | Two-tab layout: Home (default) and Library tabs |
| 2 | — (Home tab) | Topics sorted by attention priority: worst focus score first. Cards show: topic name, subject, drift count, avg focus %, status badge (NEEDS WORK / IN PROGRESS / STRONG). Filter bar: All, Biology, Chemistry. |
| 3 | — (Library tab) | All topics organized by subject columns. Each card shows: topic name, last focus %, session duration. Not-started topics shown at bottom. Same filter bar. |
| 4 | Student taps a topic card | Card expands or navigates to topic detail: subject, last session stats, estimated time, "Start Session" button |
| 5 | Student taps "Start Session" | Navigate to session start screen (USF-03) |

**Expected Outcome:** Student sees personalized, attention-driven topic recommendations. Can freely browse all content. One-tap to start a session.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| No prior sessions | First-time user | Home tab shows all topics as "Not Started" with equal priority. Friendly message: "Start your first session to see personalized recommendations." |
| Database read error | Corrupt SQLite | Error screen with "Unable to load your data. Try restarting the app." |

---

#### USF-06: Intervention — RL-Selected Rescue (FR-10, FR-18, FR-24, FR-25)

**As a** student, **I want** the app to automatically help me re-engage when my brain drifts, **so that** I don't waste time unfocused.

**Precondition:** Student is in a lesson. AttentionLevel changes to drifting or lost (confirmed by 2 consecutive windows = 8 seconds).

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | — (automatic) | Intervention engine detects drifting/lost. Lesson content pauses at exact position. |
| 2 | — (automatic) | RL agent observes state: {attention_level, drift_duration, topic, subject, formats_tried, session_number, time_in_session, student_history}. Selects best intervention format. |
| 3 | — (automatic) | Intervention screen launches (flashcard / simulation / gesture / voice — see USF-07 through USF-10). InterventionDao.insertIntervention() logs the event. |
| 4 | Student completes intervention activity | Intervention screen closes. 60-second EEG measurement window begins. |
| 5a | — (if recovered: focus score returns to focused within 60s) | Reward = +1. InterventionDao.updateIntervention(recovered: true, reward: 1.0). Show confirmation question (1 MCQ). Show recap: "You were learning about [concept]." Content resumes from exact pause point. |
| 5b | — (if NOT recovered: still drifting/lost after 60s) | Reward = -1. InterventionDao.updateIntervention(recovered: false, reward: -1.0). RL picks NEXT intervention format immediately. Cascade continues. |
| 6 | — (cascade exhausts all formats OR session time limit) | If all formats tried without recovery: show "Take a break" screen with timer. Session can end or continue after break. |

**Expected Outcome:** Drift triggers intervention within 4 seconds of confirmation. RL learns per-student preferences. Content resumes seamlessly after recovery.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| EEG signal lost during intervention | Crown disconnects | Intervention continues without reward measurement. Logged as "no reward" (neutral). Content resumes after completion. |
| All formats tried, no recovery | Severe sustained inattention | "Let's take a 2-minute break" screen with breathing animation. After break, student can continue or end session. |

---

#### USF-07: Flashcard Intervention (FR-13)

**As a** student, **I want** to do a quick flashcard quiz related to my topic when I drift, **so that** I re-engage through active recall.

**Precondition:** RL agent selected "flashcard" as intervention format.

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | — (automatic) | Flashcard deck loads: 5 cards for current topic. Card front shows question (e.g., "Ionic or covalent: H₂O?"). |
| 2 | Student taps/swipes to answer | Card flips to reveal correct answer with brief explanation. Green check or red X feedback. |
| 3 | Student completes all 5 cards | Score shown: "4/5 correct". Deck closes. Return to intervention engine for recovery measurement. |

**Expected Outcome:** 5-card active recall exercise takes ~60-90 seconds. Quick, tactile, low-pressure.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| No flashcards for topic | Missing content | Fallback to curiosity bomb for that topic |

---

#### USF-08: Simulation Intervention (FR-11)

**As a** student, **I want** to do a hands-on drag-and-drop activity, **so that** I re-engage through interactive manipulation.

**Precondition:** RL agent selected "simulation" as intervention format.

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | — (automatic) | Simulation loads for current topic. Chemistry: blank atom diagram with draggable electrons. Biology: blank cell with draggable organelles. |
| 2 | Student drags elements to correct positions | Visual feedback: snap-to-target when correct, bounce-back when wrong. Progress indicator fills. |
| 3 | Student completes simulation (all elements placed) | "Well done!" animation. Simulation closes. Return to intervention engine. |

**Expected Outcome:** Interactive, spatial activity that re-engages through touch/mouse manipulation. ~60-120 seconds.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| Student stuck for >90s | Can't figure out placement | Hint button appears: shows one correct placement as a guide |

---

#### USF-09: Gesture Intervention (FR-12)

**As a** student, **I want** to use hand gestures to answer questions, **so that** I physically re-engage with the material.

**Precondition:** RL agent selected "gesture" as intervention format. Camera permission granted.

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | — (automatic) | Camera activates. MediaPipe hand tracking initializes. Question appears: "How many bonds in CH₄? Hold up that many fingers." or "Point to the mitochondria." |
| 2 | Student holds up fingers or points | MediaPipe detects hand landmarks, counts fingers or tracks pointing direction. Visual overlay shows detected hand. |
| 3 | System recognizes correct gesture | Green confirmation animation. Next question (3-5 total). |
| 4 | Student completes all gesture questions | Camera deactivates. "Great job!" Gesture screen closes. Return to intervention engine. |

**Expected Outcome:** Physical, embodied interaction that breaks the passive reading pattern. ~60-90 seconds.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| Camera permission denied | OS-level block | Skip gesture, RL picks next format. "Camera access needed for gesture activities — you can enable it in Settings." |
| Poor lighting / detection failure | MediaPipe can't track hand | "Having trouble seeing your hand. Try better lighting or move closer." After 15s: auto-skip to next format. |

---

#### USF-10: Voice Challenge Intervention (FR-14)

**As a** student, **I want** to answer questions by speaking aloud, **so that** I re-engage through verbal articulation.

**Precondition:** RL agent selected "voice" as intervention format. Microphone permission granted.

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | — (automatic) | App speaks question aloud via text-to-speech: "What type of bond forms when electrons are shared?" |
| 2 | Student speaks answer aloud | Microphone captures audio. Speech recognition converts to text. |
| 3 | — (automatic) | Answer checked against accepted responses (fuzzy matching). Visual feedback: correct/incorrect. |
| 4 | Student completes 3-5 voice questions | Voice screen closes. Return to intervention engine. |

**Expected Outcome:** Verbal articulation forces active processing of material. ~60-90 seconds.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| Microphone permission denied | OS-level block | Skip voice, RL picks next format. "Microphone needed for voice challenges." |
| Speech recognition fails | Unclear audio, accent, noise | "Didn't catch that — try again?" After 2 retries: show text input fallback. |

---

#### USF-11: Session End — Summary & Stats (FR-04)

**As a** student, **I want** to see a summary of my learning session, **so that** I understand how focused I was and what helped.

**Precondition:** Session ends via content completion or time limit (10 min).

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | — (automatic) | Session end screen loads with: topic name, duration, avg focus score (%), intervention count, most effective format (highest recovery rate). |
| 2 | — (automatic) | Color-coded focus timeline: horizontal bar chart showing focused (green) / drifting (amber) / lost (red) over session duration. |
| 3 | — (automatic) | SessionDao.updateSession() saves final avg focus score and intervention count. SessionManager.endSession() marks session as complete. |
| 4 | Student taps "Done" | Navigate back to dashboard. Home tab refreshes with updated attention data for the topic. |

**Expected Outcome:** Student sees clear, honest feedback on their session. Data persisted for future dashboard rankings.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| No interventions triggered | Student stayed focused entire session | Summary shows "No interventions needed — great focus!" with high focus score |

---

#### USF-12: Teacher Join Session (FR-27, FR-28)

**As a** teacher, **I want** to join a student's session by code, **so that** I can monitor their focus in real time.

**Precondition:** Teacher selected "I'm a Teacher". Student has an active session with a known 6-char code.

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | Teacher taps "Join Session" | Text input field for 6-char session code |
| 2 | Teacher enters code (e.g., "abc123") | App calls AttentionStream.forSession("abc123") to subscribe to that student's filtered stream |
| 3 | — (automatic) | Live monitor screen loads: focus gauge + band power bars + student name + session duration timer. Updates every 1 second. |
| 4 | Teacher watches session | Real-time focus data streams in. Intervention events appear in feed as they happen (format, duration, recovery). |
| 5 | Student ends session | Teacher sees "Session ended" notification. Final summary stats displayed. |

**Expected Outcome:** Teacher sees live neural engagement data for a specific student, filtered by session code. No raw EEG exposed.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| Invalid session code | Typo or expired code | "No active session found for this code. Check with the student." |
| Student not on same WiFi (v1) | Different networks | "Cannot connect — make sure you're on the same WiFi as the student." (Supabase relay in v2 removes this limitation.) |

---

#### USF-13: Teacher Session History (FR-30, FR-31)

**As a** teacher, **I want** to review past sessions, **so that** I can track student progress over time.

**Precondition:** Teacher selected "I'm a Teacher". At least one completed session exists in local SQLite.

| Step | User Action | System Response |
|------|-------------|-----------------|
| 1 | Teacher navigates to History tab | List of all past sessions: student name, topic, date, avg focus, intervention count. Sortable by date, focus score. Filterable by student or subject. |
| 2 | Teacher taps a session | Detail screen: full stats, focus timeline chart, intervention breakdown (format → count → recovery rate). |
| 3 | Teacher taps "Export" (if available) | CSV or PDF download of session data |

**Expected Outcome:** Teacher has full historical view of all sessions with drill-down capability.

**Error Scenarios:**

| Scenario | Trigger | Expected Behavior |
|----------|---------|-------------------|
| No sessions yet | Fresh install | Empty state: "No sessions recorded yet. Join a student's session to start collecting data." |

---

## 5. Non-Functional Requirements

| ID | Category | Requirement | Target | Priority |
|----|----------|-------------|--------|----------|
| NFR-01 | Latency | Time from EEG drift detection to intervention screen appearing | < 4 seconds (2 confirmation windows + render) | Must-have |
| NFR-02 | Latency | AttentionState broadcast frequency | 1 emission per second (1 Hz) | Must-have |
| NFR-03 | Latency | WebSocket message delivery (daemon → Flutter) | < 100ms on local network | Must-have |
| NFR-04 | Privacy | Raw EEG data containment | Never leaves the machine running the daemon. Zero exceptions. | Must-have |
| NFR-05 | Privacy | Data transmitted to teacher | Only AttentionState (derived scores + level). No raw EEG, no band power timestamps that could reconstruct raw signal. | Must-have |
| NFR-06 | Storage | Session data retention | All sessions stored indefinitely in local SQLite. User can delete individual sessions. | Must-have |
| NFR-07 | Performance | App frame rate during lesson + HUD | Consistent 60fps on Windows desktop with HUD updating every 1s | Should-have |
| NFR-08 | Performance | Memory usage during 10-min session | < 500MB RAM including Flutter app + Python daemon | Should-have |
| NFR-09 | Reliability | WebSocket auto-reconnect | Reconnect within 3 seconds of disconnect, up to infinite retries | Must-have |
| NFR-10 | Reliability | Session data persistence | No data loss on unexpected app close — SQLite writes on every intervention event and session update | Must-have |
| NFR-11 | Usability | Crown calibration time | 30 seconds (fixed, scientifically justified for baseline stability) | Must-have |
| NFR-12 | Usability | Session code readability | 6-character alphanumeric, uppercase, monospaced, large font, tap-to-copy | Must-have |
| NFR-13 | Compatibility | Crown connection method | BrainFlow BoardShim via OSC/WiFi. Fallback to Crown's built-in focus score if band powers unavailable. | Should-have |
| NFR-14 | Offline | Full functionality without internet | App + daemon + SQLite all work offline. Only Supabase sync (deferred) requires internet. | Must-have |
| NFR-15 | Accessibility | Minimum text contrast ratio | WCAG AA (4.5:1) for lesson content and UI text | Should-have |

---

## 6. Platform & Constraints

### Platforms
| Platform | Required | Notes |
|----------|----------|-------|
| Windows Desktop | Yes (primary) | Primary development and demo platform. Python daemon runs as subprocess. |
| macOS Desktop | Yes | Secondary desktop target. Same architecture as Windows. |
| iPad (iOS) | Yes | Student and teacher use. Connects to daemon on desktop via local WiFi WebSocket. No daemon on iPad. |
| Android | Yes (stretch) | Same as iPad — connects to desktop daemon via WebSocket. Lower priority than iPad. |
| Web | No | Not targeted. Flutter desktop + mobile covers all use cases. |
| API | No | No public API. All communication via WebSocket + SQLite. |

### Constraints
- **Hardware dependency**: Requires Neurosity Crown ($999) per student. One Crown = one student = one desktop.
- **Network**: v1 requires student device and teacher device on same WiFi (WebSocket). Supabase relay (v2) removes this.
- **Team**: Solo developer (Smit) building both modules for Monday April 13 demo. Originally designed for 2 developers.
- **Timeline**: Capstone demo on Monday April 13, 2026 (1 day from PRD creation). Production launch planned after.
- **Tech stack locked**: Flutter 3.x/Dart, Python 3.11/BrainFlow, go_router, flutter_riverpod, drift (SQLite). No changes.
- **Privacy non-negotiable**: Raw EEG never transmitted. This is a hard architectural constraint, not a feature toggle.

---

## 7. Success Metrics

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Drift-to-intervention latency | < 4 seconds from confirmed drift to intervention screen | Timestamp delta: AttentionState(level=drifting, 2nd consecutive) → Intervention.triggeredAt |
| Intervention recovery rate | > 50% of interventions result in attention recovery within 60s | InterventionDao: count(recovered=true) / count(all) per session |
| RL personalization signal | By session 10, agent selects different formats for different students | Compare format distribution across 3+ students — should diverge from uniform/rule-based |
| Session completion rate | > 80% of started sessions reach content completion or 10-min mark | SessionDao: count(endedAt != null) / count(all) |
| Focus score improvement | Avg focus score improves across a student's first 5 sessions | SessionDao: trend of avgFocusScore for same student, same topic |
| Demo readiness | All Must-have features functional on demo day | Manual checklist against FR Must-have items |
| Teacher monitoring accuracy | Teacher sees focus changes within 2 seconds of student experiencing them | Timestamp comparison: AttentionState.timestamp vs teacher UI render |

---

## 8. Key Decisions

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| EEG processing location | Python daemon on desktop (not in Flutter) | BrainFlow has mature Python bindings. Fast iteration for signal processing research. Port to Dart later if needed. |
| RL reward signal | EEG attention recovery at 60s post-intervention (not quiz score) | This is the core differentiator. Brain signal is ground truth for cognitive engagement — quiz scores are a lagging proxy. |
| Intervention formats for demo | Simulation, gesture, flashcard, voice (4 working). Curiosity bomb + video = should-have. Draw-it = deferred. | Balance between demo impressiveness and build feasibility in 1 day. Simulation + gesture are the most visually striking. |
| Crown availability | Build both real daemon and mock daemon | Mock daemon enables testing and demo without hardware. Real daemon validates with actual Crown. |
| Teacher module scope for demo | Basic live monitor + session code join. History = should-have. | 80/20 split — student module is the core product. Teacher needs to work but doesn't need to be deep. |
| State management | Riverpod (not Bloc, not Provider) | Already scaffolded. StreamProvider.family pattern fits the session-filtered attention stream perfectly. |
| Database | SQLite via Drift (not Supabase, not Hive) | Local-first privacy guarantee. Drift gives type-safe queries + reactive streams. Supabase added as optional cloud layer later. |
| Module isolation | Student and teacher modules never import from each other | Enables parallel development, prevents coupling. Both consume core/ only. |
| Attention classification | 2-window hysteresis (8s confirmation before drifting/lost) | Prevents false positives from momentary distractions. 8 seconds is the minimum time to confirm genuine cognitive disengagement per EEG literature. |
| Content design | Intentionally boring school-style (white background, dense text) | The product's value is demonstrated when content is unstimulating. If content were already engaging, drift detection would be less impactful. |
| Target audience | General students (K-12, university) studying STEM. Not clinical ADHD. | Broader market. No medical claims needed. ADHD students may benefit but that's not the positioning. |
| Monetization | Deferred — focus on product quality first | Premature monetization decisions constrain product design. Revisit after demo feedback and early user testing. |

---

## 9. Open Questions

- **Crown availability for demo**: Is a physical Crown confirmed for Monday, or will demo use mock daemon only?
- **Curriculum content depth**: Are 4 topics sufficient for demo? Should a 5th topic be added for variety?
- **RL bandit implementation**: Should the contextual bandit (FR-19) be included in demo scope (sessions 6-30), or is rule-based (sessions 1-5) sufficient for a 10-minute demo?
- **iPad testing**: Will the demo include an iPad showing teacher view, or desktop-only for both roles?
- **MediaPipe Flutter**: Is there a stable Flutter plugin for MediaPipe hand tracking on Windows/macOS, or does gesture intervention need a custom implementation?
- **Speech recognition**: Which Flutter speech-to-text package for voice intervention? `speech_to_text` package or platform channels?
- **Video embedding**: YouTube iframe in Flutter desktop — webview_flutter or platform-specific solution?
- **Post-demo launch timeline**: When is the target launch date? This affects whether Should-have items need to be built immediately or can wait.

---

## 10. Next Steps

1. **Run `/presearch` on this PRD** to generate a `PROJECT_PLAN.md` with phased implementation schedule
2. **Prioritize for Monday demo**: Focus build order on Must-have features only — daemon, session flow, lesson+HUD, 4 intervention formats, dashboard, basic teacher monitor
3. **Resolve open questions**: Especially MediaPipe availability, speech recognition package choice, and Crown hardware status
4. **Build mock daemon first**: Unblocks all Flutter development without needing Crown hardware
5. **Test end-to-end flow**: Crown/mock → daemon → WebSocket → Flutter → intervention → recovery → session end

---

### Appendix: Feature Count Summary

| Priority | Count | Notes |
|----------|-------|-------|
| Must-have | 25 | Core product — all needed for demo |
| Should-have | 11 | Enhance the experience — build if time permits |
| Could-have | 2 | Nice-to-have — post-demo |
| Won't-have | 4 | Explicitly deferred (Supabase, DQN, draw-it) |
| **Total** | **42** | |

### Appendix: Competitive Research Sources

- [EEG-Based Attention Classification — MDPI Applied Sciences](https://www.mdpi.com/2076-3417/15/15/8668)
- [Consumer EEG Hardware Predictions — Arctop](https://arctop.com/deep-dives/consumer-eeg-hardware)
- [EEG Student Engagement Monitoring — Nature Scientific Reports](https://www.nature.com/articles/s41598-022-09578-y)
- [Deep Q-Learning for Student Attention — IEEE Xplore](https://ieeexplore.ieee.org/document/10816329/)
- [EEG + Deep RL for Student Attention — ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S095741742500048X)
- [Neurosity Crown — Official Site](https://neurosity.co/)
- [Myndlift Neurofeedback Platform](https://www.myndlift.com/)
- [Adaptive Learning Market Report — Mordor Intelligence](https://www.mordorintelligence.com/industry-reports/adaptive-learning-market)
- [Top Adaptive Learning Platforms 2025 — WalkMe](https://www.walkme.com/blog/best-adaptive-learning-platforms/)
- [BCIs in STEM Learning — IntechOpen](https://www.intechopen.com/online-first/1234026)
