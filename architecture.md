# GreyMatters / NeuroLearn — Architecture Reference

Reference for planning new content and new topic modules outside the repo. Reflects the post-Supabase rewrite (smit branch, commit 25e1315 onward). Curriculum is now split into three JSON families per topic, with a master catalog plus an optional bespoke "activity" per topic.

---

## Tech stack

| Layer | Language / Runtime | Key libraries |
|---|---|---|
| UI | **Dart / Flutter 3.3+** | `flutter_riverpod` + `riverpod` (state), `go_router` (nav), `speech_to_text` + `flutter_tts` (voice intervention), `url_launcher` (YouTube) |
| Local persistence | SQLite via `drift` | Tables: sessions, interventions, baselines, activity_progress |
| Cloud persistence | **Supabase** (`supabase_flutter`) | profiles, sessions, attention_snapshots, interventions, baselines, teacher_monitors + computed views |
| EEG daemon | **Python 3.11** | `brainflow` (Crown board, OSC/UDP:9000), `websockets`, `numpy`. All 8 channels, 5 bands (delta/theta/alpha/beta/gamma), 2–45 Hz bandpass, median across channels, beta/theta focus metric, per-channel signal quality |
| Transport | WebSocket JSON | `ws://0.0.0.0:8765` |
| Realtime broadcast | Supabase Realtime (pub/sub) | Enables teacher to watch any student across any network |
| Hardware | Neurosity Crown — 8 dry electrodes at CP3/C3/F5/PO3/PO4/F6/C4/CP4, T7 ref, T8 bias, 256 Hz, Ag/AgCl, 0.25 µVrms noise floor |

Platforms: Windows desktop (primary), macOS desktop, iPad, Android, web.

---

## Curriculum file layout

```
assets/curriculum/
├── index.json                                ← master catalog (subjects → topics → prereqs)
├── {subject_id}/
│   ├── course.json                           ← subject metadata (name, icon, topicOrder, unlockMode)
│   └── {topic_id}/
│       ├── lesson.json                       ← the lesson content (text, videos, checkpoints)
│       ├── interventions.json                ← generic intervention content (flashcard / sim / gesture / voice)
│       └── activities.json                   ← (optional) declares a topic-specific bespoke activity
```

Example:
```
assets/curriculum/
├── index.json
├── chemistry/
│   ├── course.json
│   ├── periodic_table/
│   │   ├── lesson.json
│   │   ├── interventions.json
│   │   └── activities.json                   ← registers Synthetic Alchemist for this topic
│   ├── chemical_bonding/
│   │   ├── lesson.json
│   │   └── interventions.json
│   └── covalent_bonds/…
└── biology/
    ├── course.json
    └── cell_structure/…
```

Every subject folder and every topic folder must be declared in `pubspec.yaml` under `flutter.assets` — Flutter bundles only the paths it's told about. Adding a new subject means adding those paths, not just dropping files.

---

## The three JSON files per topic

### 1. `lesson.json` — Topic + Section[] (the content)

Drives [`lesson_screen.dart`](lib/student/screens/lesson_screen.dart). Rendered reader with sidebar section navigation, progress bar, checkpoints, section locking.

```jsonc
{
  "id": "periodic_table",                    // must match folder name and index.json
  "name": "The Periodic Table",
  "subject": "chemistry",                    // lowercase subject id
  "grade": "Grade 11-12",                    // optional display string
  "estimatedMinutes": 10,
  "curiosityBomb": "A single closing fact revealed when the lesson completes.",
  "sections": [ /* Section objects */ ]
}
```

**Section object** — same shape as the old schema (the rewrite kept the section structure):
```jsonc
{
  "id": "pt_s1",
  "title": "I. History & Organisation",
  "subtitle": "Groups, periods, Mendeleev",
  "paragraphs": ["...", "..."],              // preferred
  // "content": "... \n\n ..."               // legacy single-string fallback still accepted
  "keyTerms": ["atomic number", "groups", "periods"],
  "diagram": {
    "type": "periodic_table",                // NEW: named diagram renderer. "generic" is default
    "title": "Structure of the Periodic Table",
    "description": "Text describing the diagram.",
    "interactiveHint": "Tap any region to see details"
  },
  "video":       { /* VideoEmbed */ },
  "driftVideo":  { /* VideoEmbed — shown if student was drifting on this section */ },
  "callout":     { "type": "did_you_know|real_world|remember|common_mistake", "content": "..." },
  "checkpoint":  { "question": "...", "options": ["A","B","C","D"], "correctIndex": 2,
                   "onCorrect": "...", "onWrong": "..." },
  "interventionMap": {
    "mild":     { "format": "flashcard|simulation|gesture|voice|activity", "description": "..." },
    "moderate": { "format": "...", "description": "..." },
    "severe":   { "format": "...", "description": "..." }
  },
  "recapOnReturn": "You were learning: …"
}
```

`VideoEmbed`: `{ title, youtubeId, startTime ("M:SS"), endTime, duration, description? }`.

**What changed vs. old schema:** the lesson JSON now contains *only* lesson content. Top-level `flashcards`, `simulation`, `gestureQuestions`, `voiceQuestions` arrays are REMOVED — they live in `interventions.json` now. The `diagram` block gained a `type` field so specific named renderers (e.g., `periodic_table`, `cell_structure`) can be matched by widgets.

### 2. `interventions.json` — InterventionPack (the drift rescue content)

Loaded by each of the four generic intervention screens independently when they're invoked.

```jsonc
{
  "topicId": "periodic_table",               // must match folder
  "flashcards": [
    { "question": "...", "answer": "...", "explanation": "..." }
  ],
  "simulation": {
    "type": "element_placement",
    "instructions": "Drag each element to its correct position on the grid.",
    "elements": [
      { "symbol": "H", "name": "Hydrogen", "group": 1, "period": 1 }
    ]
  },
  "gestureQuestions": [
    { "question": "How many groups are in the periodic table?", "answer": 18, "hint": "Top of table." }
  ],
  "voiceQuestions": [
    { "question": "What is the atomic number of Hydrogen?", "acceptedAnswers": ["1", "one"] }
  ]
}
```

All four arrays are optional. The intervention screen for each format shows a "No X available" fallback if its array is missing or empty — it won't crash.

The `SimulationConfig` is still hardcoded to the chemistry-style `symbol/name/group/period` fields. If a topic needs a different simulation shape (phases, timeline, branching), **use an activity instead** — don't try to shoehorn it into the generic simulation.

### 3. `activities.json` — topic-specific bespoke experiences (optional)

```jsonc
{
  "topicId": "periodic_table",
  "activities": [
    {
      "id": "synthetic_alchemist",           // must match a registered case in ActivityRegistry
      "name": "Synthetic Alchemist",
      "description": "Catch falling elements in atomic number order",
      "driftTrigger": "moderate"             // which drift severity should launch this
    }
  ]
}
```

Activities are referenced by `id` from the JSON; the actual widget is hand-built Dart in `lib/student/screens/activities/` and registered in [`activity_registry.dart`](lib/student/screens/activities/activity_registry.dart). **The JSON only declares that the activity exists for this topic and at what drift level.** The UI/mechanic lives in the widget, not in JSON.

Existing example: [`synthetic_alchemist_screen.dart`](lib/student/screens/activities/synthetic_alchemist_screen.dart) (~567 lines) is a Tetris-style "catch falling elements in atomic number order" game for the Periodic Table topic.

---

## `index.json` — master catalog

Drives the library screen, subject filters, and prerequisite unlock logic.

```jsonc
{
  "subjects": [
    {
      "id": "chemistry",
      "name": "Chemistry",
      "icon": "science",                     // Material icon name
      "color": "#6C5CE7",                    // hex — used on library cards
      "topics": [
        {
          "id": "periodic_table",
          "name": "The Periodic Table",
          "grade": "Grade 11-12",            // optional
          "estimatedMinutes": 10,
          "prereqs": []                      // topicIds that must be done first
        },
        {
          "id": "chemical_bonding",
          "name": "Chemical Bonding",
          "estimatedMinutes": 12,
          "prereqs": ["periodic_table"]
        }
      ]
    }
  ]
}
```

Adding a new subject/topic here + creating the matching folder structure + updating `pubspec.yaml` is the minimum to get a topic into the app.

---

## `course.json` — per-subject metadata (inside each subject folder)

```jsonc
{
  "id": "chemistry",
  "name": "Chemistry",
  "icon": "science",
  "topicOrder": ["periodic_table", "chemical_bonding", "covalent_bonds"],
  "unlockMode": "sequential"                 // "sequential" | "open" (all unlocked)
}
```

`topicOrder` defines display/unlock order; `unlockMode` controls whether later topics gate behind earlier ones.

---

## Intervention flow (drift → rescue)

Sequence is unchanged from before; only the format list grew to include `activity`.

1. **Daemon streams attention** — WebSocket → Flutter — beta/theta ratio + signal quality.
2. **Drift confirmed** — rolling window (≥5 of last 10 readings below threshold).
3. **`LessonScreen` pauses** and spins up `InterventionEngine`.
4. **RL agent picks format** — one of: `flashcard`, `simulation`, `gesture`, `voice`, `activity`.
5. **`InterventionEngine.buildFormatScreen`** routes to the right widget. If format is `activity`, it consults `ActivityRegistry.activityForTopic(subject, topicId)` — if a custom widget is registered, it's used; otherwise falls through to generic formats.
6. **Student does the thing.** `onComplete` fires.
7. **Reward updated** — if attention recovered (state is `focused`), reward +1, cascade ends. Otherwise cascade to next format (up to 4 total).

Generic intervention widgets live in [`lib/student/screens/interventions/`](lib/student/screens/interventions/):
- [`flashcard_screen.dart`](lib/student/screens/interventions/flashcard_screen.dart) — loads `interventions.json` → `flashcards[]`
- [`simulation_screen.dart`](lib/student/screens/interventions/simulation_screen.dart) — loads `simulation`
- [`gesture_screen.dart`](lib/student/screens/interventions/gesture_screen.dart) — loads `gestureQuestions[]`
- [`voice_challenge_screen.dart`](lib/student/screens/interventions/voice_challenge_screen.dart) — loads `voiceQuestions[]`

Each intervention screen now takes both `subject` and `topicId` (the path needs both to resolve `assets/curriculum/{subject}/{topicId}/interventions.json`).

---

## Supabase data layer (cloud sync, teacher, profiles)

Tables (see [`docs/SUPABASE_SCHEMA.md`](docs/SUPABASE_SCHEMA.md), schema in [`supabase/migrations/001_full_schema.sql`](supabase/migrations/001_full_schema.sql)):
- `profiles` — device/user profile (role, name, device_id)
- `sessions` — one session = one student × one topic × one sitting
- `attention_snapshots` — periodic EEG-derived state writes
- `interventions` — each drift rescue logged
- `baselines` — per-student baseline metrics per topic
- `teacher_monitors` — realtime subscription metadata for teacher dashboards
- Plus 4 computed views (performance aggregates for the student and teacher dashboards)

Runtime services:
- [`profile_manager.dart`](lib/core/services/profile_manager.dart) — device-local + Supabase sync
- [`session_manager.dart`](lib/core/services/session_manager.dart) — session lifecycle, writes snapshots + interventions
- [`realtime_broadcast.dart`](lib/core/services/realtime_broadcast.dart) — pub/sub so teacher dashboards update live without polling
- [`supabase_db.dart`](lib/core/data/supabase_db.dart) — table/view access wrappers

Teacher UI: [`teacher_dashboard_screen.dart`](lib/teacher/screens/teacher_dashboard_screen.dart), [`student_detail_screen.dart`](lib/teacher/screens/student_detail_screen.dart), [`live_monitor_screen.dart`](lib/teacher/screens/live_monitor_screen.dart).

For content authoring, Supabase is usually irrelevant — the content lives in `assets/curriculum/`, period.

---

## Where new topic content plugs in — the short form

Dropping a new topic into the app is **four** file/config changes, plus optionally a fifth for a bespoke activity:

1. **Create the folder tree:**
   ```
   assets/curriculum/{subject}/{topicId}/lesson.json
   assets/curriculum/{subject}/{topicId}/interventions.json
   assets/curriculum/{subject}/{topicId}/activities.json      ← optional
   ```
2. **If the subject is new,** create `assets/curriculum/{subject}/course.json`.
3. **Register in** `assets/curriculum/index.json` — add the subject (if new) and the topic entry with its prereqs.
4. **Declare the new paths in `pubspec.yaml`** under `flutter.assets` — one line per folder (subject and each topic). Skip this and Flutter won't bundle the files.
5. **Optional — build a custom activity widget:**
   - Create `lib/student/screens/activities/{activity_id}_screen.dart`
   - Add a `case` in [`activity_registry.dart`](lib/student/screens/activities/activity_registry.dart) `build()` switch
   - Add a mapping in `activityForTopic()` so the registry knows which topic uses which activity
   - Reference the `{activity_id}` from your `activities.json`

No changes to `library_screen.dart`, `intervention_engine.dart`, or any routing are needed for content-only additions — the catalog is driven by `index.json`.

---

## Conventions

- **Subject IDs:** lowercase snake_case (`chemistry`, `biology`, `astronomy`).
- **Topic IDs:** lowercase snake_case, must match the folder name AND the `id` inside `lesson.json` AND the entry in `index.json`.
- **Activity IDs:** lowercase snake_case, must match the case in `ActivityRegistry.build()`.
- **Section IDs:** `<topic_abbr>_s1`, `<topic_abbr>_s2`, etc.
- **Paragraphs:** prose, grade-appropriate, 3–5 per section.
- **Key terms:** 4–6 per section.
- **Checkpoints:** 4 options; always include both `onCorrect` and `onWrong` feedback.
- **Videos:** YouTube IDs only, no full URLs. `startTime`/`endTime` as `M:SS` strings.
- **Callout types:** one of `did_you_know`, `real_world`, `remember`, `common_mistake`.
- **Drift trigger levels on activities/interventions:** `mild`, `moderate`, `severe`.

---

## Authoring checklist (offline-ready)

When planning a new topic:

- [ ] Pick subject (existing or new) and topic id (snake_case)
- [ ] Draft 3–5 sections: title, 3–5 paragraphs, 4–6 key terms each
- [ ] For each section: describe the diagram in prose, pick a YouTube id + start/end, write one callout, write a 4-option checkpoint with correct + wrong feedback
- [ ] Per-section `interventionMap`: which of `flashcard|simulation|gesture|voice|activity` fires at mild/moderate/severe drift, plus a one-line description of the content
- [ ] Decide: does this topic need a bespoke activity? If yes, sketch the mechanic in prose (what the student sees, does, and when it ends) — that becomes the spec for the Dart widget
- [ ] Assemble interventions: 5+ flashcards, optional simulation (chemistry-shape only), 1–3 gesture questions, 1–3 voice questions
- [ ] Write closing `curiosityBomb`
- [ ] Pick display name, estimated minutes, grade, prereqs (topicIds)
- [ ] If new subject: pick name, Material icon, hex color

Once the JSONs are drafted, the only code tasks are:
- Append the topic to `index.json` and (if new subject) add `course.json`
- Declare the new asset folders in `pubspec.yaml`
- Build the activity widget (only if you chose to have one)

Everything else — library rendering, intervention routing, drift detection, session logging, teacher dashboards — picks up the new topic automatically.
