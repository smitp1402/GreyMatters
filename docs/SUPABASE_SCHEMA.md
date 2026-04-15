# Supabase Schema Design

> GreyMatters EEG-adaptive learning platform — database schema for Supabase (PostgreSQL)

## Design Principles

1. **Local-first, cloud-synced** — SQLite on-device is primary, Supabase syncs completed sessions
2. **Privacy** — raw EEG never stored in cloud, only derived AttentionState snapshots
3. **Compute in Postgres** — analytics views pre-compute dashboard stats, Flutter just reads
4. **Realtime for live monitoring** — Supabase Broadcast channels relay AttentionState to teacher
5. **No auth in v1** — role picker with name, no email/password login

---

## Tables

### `profiles`

Single table for both students and teachers. Role determines what they see.

```sql
CREATE TABLE profiles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  role        TEXT NOT NULL CHECK (role IN ('student', 'teacher')),
  grade_level TEXT,                          -- e.g., '10th', 'university', NULL for teachers
  avatar_url  TEXT,                          -- optional profile picture URL
  subjects    TEXT[] DEFAULT '{}',           -- student: subjects of interest ['chemistry', 'biology']
  device_id   TEXT NOT NULL,                 -- unique device identifier for local-cloud linking
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX idx_profiles_device_id ON profiles(device_id);
```

### `sessions`

One row per learning session. Created at session start, updated at end.

```sql
CREATE TABLE sessions (
  id                  TEXT PRIMARY KEY,       -- 6-char uppercase code (e.g., 'ABC123')
  student_id          UUID NOT NULL REFERENCES profiles(id),
  topic_id            TEXT NOT NULL,          -- e.g., 'periodic_table'
  topic_name          TEXT NOT NULL,          -- e.g., 'The Periodic Table'
  subject             TEXT NOT NULL,          -- e.g., 'chemistry'
  started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at            TIMESTAMPTZ,
  duration_sec        INT,                   -- computed on end
  avg_focus_score     DOUBLE PRECISION,      -- computed on end
  min_focus_score     DOUBLE PRECISION,
  max_focus_score     DOUBLE PRECISION,
  drift_count         INT DEFAULT 0,         -- number of drift/lost events
  intervention_count  INT DEFAULT 0,
  sections_completed  INT DEFAULT 0,
  total_sections      INT,
  baseline_ratio      DOUBLE PRECISION,      -- beta/theta calibration baseline
  status              TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'abandoned')),
  created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_sessions_student ON sessions(student_id);
CREATE INDEX idx_sessions_topic ON sessions(topic_id);
CREATE INDEX idx_sessions_status ON sessions(status);
```

### `attention_snapshots`

Sampled AttentionState readings during a session. NOT every 1-second tick — sampled at key moments (drift events, recovery, every 10s for timeline). Keeps storage manageable.

```sql
CREATE TABLE attention_snapshots (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  focus_score     DOUBLE PRECISION NOT NULL,
  delta           DOUBLE PRECISION NOT NULL,
  theta           DOUBLE PRECISION NOT NULL,
  alpha           DOUBLE PRECISION NOT NULL,
  beta            DOUBLE PRECISION NOT NULL,
  gamma           DOUBLE PRECISION NOT NULL,
  level           TEXT NOT NULL CHECK (level IN ('focused', 'drifting', 'lost')),
  beta_theta      DOUBLE PRECISION,         -- primary focus ratio
  theta_alpha     DOUBLE PRECISION,
  beta_alpha_theta DOUBLE PRECISION,
  recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_snapshots_session ON attention_snapshots(session_id);
CREATE INDEX idx_snapshots_time ON attention_snapshots(recorded_at);
```

### `interventions`

Every intervention triggered during a session.

```sql
CREATE TABLE interventions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  student_id      UUID NOT NULL REFERENCES profiles(id),
  format          TEXT NOT NULL CHECK (format IN ('flashcard', 'simulation', 'gesture', 'voice', 'curiosity_bomb', 'video')),
  trigger_level   TEXT NOT NULL CHECK (trigger_level IN ('drifting', 'lost')),
  drift_duration_sec INT,                   -- how long student was drifting before trigger
  recovered       BOOLEAN,                  -- did student return to focused?
  reward          DOUBLE PRECISION,         -- +1.0 or -1.0
  focus_before    DOUBLE PRECISION,         -- focus score when triggered
  focus_after     DOUBLE PRECISION,         -- focus score 60s after completion
  triggered_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at    TIMESTAMPTZ
);

CREATE INDEX idx_interventions_session ON interventions(session_id);
CREATE INDEX idx_interventions_student ON interventions(student_id);
CREATE INDEX idx_interventions_format ON interventions(format);
```

### `baselines`

Calibration baselines per session.

```sql
CREATE TABLE baselines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  student_id      UUID NOT NULL REFERENCES profiles(id),
  baseline_ratio  DOUBLE PRECISION NOT NULL, -- beta/theta during calibration
  delta           DOUBLE PRECISION,
  theta           DOUBLE PRECISION,
  alpha           DOUBLE PRECISION,
  beta            DOUBLE PRECISION,
  gamma           DOUBLE PRECISION,
  calibrated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_baselines_student ON baselines(student_id);
```

### `teacher_monitors`

Tracks which sessions a teacher has monitored. Builds teacher's student history.

```sql
CREATE TABLE teacher_monitors (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id      UUID NOT NULL REFERENCES profiles(id),
  session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  student_id      UUID NOT NULL REFERENCES profiles(id),
  joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at         TIMESTAMPTZ,
  UNIQUE(teacher_id, session_id)
);

CREATE INDEX idx_monitors_teacher ON teacher_monitors(teacher_id);
CREATE INDEX idx_monitors_student ON teacher_monitors(student_id);
```

---

## Computed Views

### `student_topic_stats`

Powers the student dashboard — per-topic stats from all sessions.

```sql
CREATE VIEW student_topic_stats AS
SELECT
  s.student_id,
  s.topic_id,
  s.topic_name,
  s.subject,
  COUNT(*)                                          AS total_sessions,
  ROUND(AVG(s.avg_focus_score)::numeric, 3)         AS avg_focus,
  ROUND(MAX(s.avg_focus_score)::numeric, 3)         AS best_focus,
  ROUND(AVG(s.avg_focus_score) FILTER (
    WHERE s.started_at > now() - INTERVAL '7 days'
  )::numeric, 3)                                    AS avg_focus_7d,
  SUM(s.drift_count)                                AS total_drifts,
  SUM(s.intervention_count)                         AS total_interventions,
  MAX(s.started_at)                                 AS last_session_at,
  -- Progress: latest session's sections_completed / total_sections
  (ARRAY_AGG(s.sections_completed ORDER BY s.started_at DESC))[1]  AS last_sections_completed,
  (ARRAY_AGG(s.total_sections ORDER BY s.started_at DESC))[1]      AS last_total_sections,
  -- Status classification
  CASE
    WHEN COUNT(*) = 0 THEN 'not_started'
    WHEN AVG(s.avg_focus_score) >= 0.85 AND COUNT(*) >= 3 THEN 'mastered'
    WHEN AVG(s.avg_focus_score) >= 0.70 THEN 'strong'
    WHEN AVG(s.avg_focus_score) >= 0.50 THEN 'review_priority'
    ELSE 'needs_work'
  END                                               AS mastery_status,
  -- Consistency: stddev of focus scores (lower = more consistent)
  ROUND(
    CASE WHEN COUNT(*) >= 2 THEN 1.0 - LEAST(STDDEV(s.avg_focus_score), 0.5) / 0.5
         ELSE NULL
    END::numeric, 3
  )                                                 AS consistency_score
FROM sessions s
WHERE s.status = 'completed'
GROUP BY s.student_id, s.topic_id, s.topic_name, s.subject;
```

### `student_summary`

Powers the header greeting and overall stats.

```sql
CREATE VIEW student_summary AS
SELECT
  p.id AS student_id,
  p.name,
  COUNT(DISTINCT s.id)                              AS total_sessions,
  ROUND(AVG(s.avg_focus_score)::numeric, 3)         AS overall_avg_focus,
  -- Best subject today
  (
    SELECT sub.subject
    FROM sessions sub
    WHERE sub.student_id = p.id
      AND sub.status = 'completed'
      AND sub.started_at::date = CURRENT_DATE
    GROUP BY sub.subject
    ORDER BY AVG(sub.avg_focus_score) DESC
    LIMIT 1
  )                                                 AS best_subject_today,
  -- Worst topic (lowest avg focus, needs attention)
  (
    SELECT sub.topic_name
    FROM sessions sub
    WHERE sub.student_id = p.id AND sub.status = 'completed'
    GROUP BY sub.topic_id, sub.topic_name
    ORDER BY AVG(sub.avg_focus_score) ASC
    LIMIT 1
  )                                                 AS weakest_topic,
  -- Last session
  MAX(s.started_at)                                 AS last_session_at
FROM profiles p
LEFT JOIN sessions s ON s.student_id = p.id AND s.status = 'completed'
WHERE p.role = 'student'
GROUP BY p.id, p.name;
```

### `intervention_efficacy`

Powers RL insights — which format works best per student per topic.

```sql
CREATE VIEW intervention_efficacy AS
SELECT
  i.student_id,
  s.topic_id,
  i.format,
  COUNT(*)                                          AS times_used,
  ROUND(AVG(CASE WHEN i.recovered THEN 1.0 ELSE 0.0 END)::numeric, 3)
                                                    AS recovery_rate,
  ROUND(AVG(i.reward)::numeric, 3)                  AS avg_reward,
  ROUND(AVG(i.focus_after - i.focus_before)::numeric, 3)
                                                    AS avg_focus_lift,
  -- Rank: best format per student+topic
  ROW_NUMBER() OVER (
    PARTITION BY i.student_id, s.topic_id
    ORDER BY AVG(CASE WHEN i.recovered THEN 1.0 ELSE 0.0 END) DESC,
             AVG(i.reward) DESC
  )                                                 AS format_rank
FROM interventions i
JOIN sessions s ON s.id = i.session_id
GROUP BY i.student_id, s.topic_id, i.format;
```

### `teacher_student_overview`

Powers teacher's student list — all students they've monitored.

```sql
CREATE VIEW teacher_student_overview AS
SELECT
  tm.teacher_id,
  p.id AS student_id,
  p.name AS student_name,
  p.grade_level,
  COUNT(DISTINCT tm.session_id)                     AS sessions_monitored,
  MAX(tm.joined_at)                                 AS last_monitored_at,
  ROUND(AVG(s.avg_focus_score)::numeric, 3)         AS avg_focus_across_sessions
FROM teacher_monitors tm
JOIN profiles p ON p.id = tm.student_id
JOIN sessions s ON s.id = tm.session_id
GROUP BY tm.teacher_id, p.id, p.name, p.grade_level;
```

---

## Row Level Security (RLS)

```sql
-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attention_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE interventions ENABLE ROW LEVEL SECURITY;
ALTER TABLE baselines ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_monitors ENABLE ROW LEVEL SECURITY;

-- For v1 (no auth), use device_id based policies.
-- The app sends device_id as a custom header or JWT claim.
-- These policies will be tightened when real auth is added.

-- Profiles: users can only read/write their own profile
CREATE POLICY profiles_own ON profiles
  FOR ALL USING (device_id = current_setting('app.device_id', true));

-- Sessions: students see their own, teachers see sessions they've monitored
CREATE POLICY sessions_student ON sessions
  FOR ALL USING (
    student_id IN (SELECT id FROM profiles WHERE device_id = current_setting('app.device_id', true))
  );

CREATE POLICY sessions_teacher ON sessions
  FOR SELECT USING (
    id IN (
      SELECT session_id FROM teacher_monitors
      WHERE teacher_id IN (SELECT id FROM profiles WHERE device_id = current_setting('app.device_id', true))
    )
  );

-- Attention snapshots: same as sessions
CREATE POLICY snapshots_access ON attention_snapshots
  FOR ALL USING (
    session_id IN (
      SELECT id FROM sessions WHERE student_id IN (
        SELECT id FROM profiles WHERE device_id = current_setting('app.device_id', true)
      )
    )
  );
```

---

## Realtime (Live Monitoring)

For live teacher monitoring across networks, use **Supabase Realtime Broadcast**:

```dart
// Student side — publish AttentionState to channel
final channel = supabase.channel('session:ABC123');
channel.sendBroadcastMessage(
  event: 'attention_state',
  payload: attentionState.toJson(),
);

// Teacher side — subscribe to student's session
final channel = supabase.channel('session:ABC123');
channel.onBroadcast(event: 'attention_state', callback: (payload) {
  final state = AttentionState.fromJson(payload);
  // update UI
});
await channel.subscribe();
```

No database writes for live data — Broadcast is pure pub/sub through Supabase's WebSocket infrastructure. AttentionState flows at 1Hz without touching Postgres.

---

## Sync Strategy

### What syncs to Supabase (after session ends)

| Data | When | How |
|------|------|-----|
| Profile | On first launch | Upsert by device_id |
| Session summary | On session end | Insert with final stats |
| Attention snapshots | On session end | Batch insert (sampled, not every tick) |
| Interventions | On session end | Batch insert all interventions from session |
| Baseline | On calibration complete | Insert |

### What stays local only

| Data | Why |
|------|-----|
| Raw EEG band powers at 1Hz | Privacy — too granular for cloud |
| Real-time AttentionState stream | Goes through Broadcast, not stored |
| RL agent policy weights | Per-device, not meaningful cross-device |

### Sampling strategy for attention_snapshots

To avoid storing 600 rows per 10-minute session:
- Sample every **10 seconds** during focused periods (1 row per 10s)
- Sample every **1 second** during drift/lost periods (capture the full event)
- Always capture: first reading, last reading, level transitions

This gives ~100-150 rows per 10-min session instead of 600.

---

## Migration Order

1. Create `profiles` table
2. Create `sessions` table
3. Create `attention_snapshots` table
4. Create `interventions` table
5. Create `baselines` table
6. Create `teacher_monitors` table
7. Create views: `student_topic_stats`, `student_summary`, `intervention_efficacy`, `teacher_student_overview`
8. Enable RLS + create policies
9. Enable Realtime on Broadcast channels

---

## Flutter Integration Points

| Flutter file | Supabase interaction |
|---|---|
| `session_manager.dart` | Insert session on start, update on end, batch insert snapshots + interventions |
| `dashboard_screen.dart` | Query `student_topic_stats` + `student_summary` views |
| `session_end_screen.dart` | Query `intervention_efficacy` for "most effective format" |
| `live_monitor_screen.dart` | Subscribe to Broadcast channel `session:{code}` |
| `lesson_screen.dart` | Publish AttentionState to Broadcast channel |
| `calibration_screen.dart` | Insert baseline |
| `join_session_screen.dart` | Query active session by code, insert teacher_monitor |
