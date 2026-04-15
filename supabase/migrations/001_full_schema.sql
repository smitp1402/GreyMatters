-- GreyMatters Supabase Schema
-- Run this in Supabase SQL Editor (https://supabase.com/dashboard → SQL Editor)
-- WARNING: Drops existing tables. All data will be lost.

-- ============================================================
-- 1. DROP EXISTING TABLES
-- ============================================================

DROP VIEW IF EXISTS teacher_student_overview CASCADE;
DROP VIEW IF EXISTS intervention_efficacy CASCADE;
DROP VIEW IF EXISTS student_summary CASCADE;
DROP VIEW IF EXISTS student_topic_stats CASCADE;

DROP TABLE IF EXISTS teacher_monitors CASCADE;
DROP TABLE IF EXISTS baselines CASCADE;
DROP TABLE IF EXISTS interventions CASCADE;
DROP TABLE IF EXISTS attention_snapshots CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- ============================================================
-- 2. TABLES
-- ============================================================

-- Profiles: students and teachers
CREATE TABLE profiles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  role        TEXT NOT NULL CHECK (role IN ('student', 'teacher')),
  grade_level TEXT,
  avatar_url  TEXT,
  subjects    TEXT[] DEFAULT '{}',
  device_id   TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX idx_profiles_device_id ON profiles(device_id);
CREATE INDEX idx_profiles_role ON profiles(role);

-- Sessions: one row per learning session
CREATE TABLE sessions (
  id                  TEXT PRIMARY KEY,
  student_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  topic_id            TEXT NOT NULL,
  topic_name          TEXT NOT NULL,
  subject             TEXT NOT NULL,
  started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at            TIMESTAMPTZ,
  duration_sec        INT,
  avg_focus_score     DOUBLE PRECISION,
  min_focus_score     DOUBLE PRECISION,
  max_focus_score     DOUBLE PRECISION,
  drift_count         INT DEFAULT 0,
  intervention_count  INT DEFAULT 0,
  sections_completed  INT DEFAULT 0,
  total_sections      INT,
  baseline_ratio      DOUBLE PRECISION,
  status              TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'abandoned')),
  created_at          TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_sessions_student ON sessions(student_id);
CREATE INDEX idx_sessions_topic ON sessions(topic_id);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_sessions_started ON sessions(started_at DESC);

-- Attention snapshots: sampled readings during session
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
  beta_theta      DOUBLE PRECISION,
  theta_alpha     DOUBLE PRECISION,
  beta_alpha_theta DOUBLE PRECISION,
  recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_snapshots_session ON attention_snapshots(session_id);
CREATE INDEX idx_snapshots_time ON attention_snapshots(recorded_at);

-- Interventions: every intervention triggered
CREATE TABLE interventions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id          TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  student_id          UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  format              TEXT NOT NULL CHECK (format IN ('flashcard', 'simulation', 'gesture', 'voice', 'curiosity_bomb', 'video')),
  trigger_level       TEXT NOT NULL CHECK (trigger_level IN ('drifting', 'lost')),
  drift_duration_sec  INT,
  recovered           BOOLEAN,
  reward              DOUBLE PRECISION,
  focus_before        DOUBLE PRECISION,
  focus_after         DOUBLE PRECISION,
  triggered_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at        TIMESTAMPTZ
);

CREATE INDEX idx_interventions_session ON interventions(session_id);
CREATE INDEX idx_interventions_student ON interventions(student_id);
CREATE INDEX idx_interventions_format ON interventions(format);

-- Baselines: calibration data per session
CREATE TABLE baselines (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  student_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  baseline_ratio  DOUBLE PRECISION NOT NULL,
  delta           DOUBLE PRECISION,
  theta           DOUBLE PRECISION,
  alpha           DOUBLE PRECISION,
  beta            DOUBLE PRECISION,
  gamma           DOUBLE PRECISION,
  calibrated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_baselines_student ON baselines(student_id);
CREATE INDEX idx_baselines_session ON baselines(session_id);

-- Teacher monitors: which teacher watched which session
CREATE TABLE teacher_monitors (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id  UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  session_id  TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  student_id  UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at     TIMESTAMPTZ,
  UNIQUE(teacher_id, session_id)
);

CREATE INDEX idx_monitors_teacher ON teacher_monitors(teacher_id);
CREATE INDEX idx_monitors_student ON teacher_monitors(student_id);

-- ============================================================
-- 3. COMPUTED VIEWS
-- ============================================================

-- Per-topic stats for student dashboard
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
  (ARRAY_AGG(s.sections_completed ORDER BY s.started_at DESC))[1]  AS last_sections_completed,
  (ARRAY_AGG(s.total_sections ORDER BY s.started_at DESC))[1]      AS last_total_sections,
  CASE
    WHEN COUNT(*) = 0 THEN 'not_started'
    WHEN AVG(s.avg_focus_score) >= 0.85 AND COUNT(*) >= 3 THEN 'mastered'
    WHEN AVG(s.avg_focus_score) >= 0.70 THEN 'strong'
    WHEN AVG(s.avg_focus_score) >= 0.50 THEN 'review_priority'
    ELSE 'needs_work'
  END                                               AS mastery_status,
  ROUND(
    CASE WHEN COUNT(*) >= 2 THEN 1.0 - LEAST(STDDEV(s.avg_focus_score), 0.5) / 0.5
         ELSE NULL
    END::numeric, 3
  )                                                 AS consistency_score
FROM sessions s
WHERE s.status = 'completed'
GROUP BY s.student_id, s.topic_id, s.topic_name, s.subject;

-- Student summary for header greeting
CREATE VIEW student_summary AS
SELECT
  p.id AS student_id,
  p.name,
  COUNT(DISTINCT s.id)                              AS total_sessions,
  ROUND(AVG(s.avg_focus_score)::numeric, 3)         AS overall_avg_focus,
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
  (
    SELECT sub.topic_name
    FROM sessions sub
    WHERE sub.student_id = p.id AND sub.status = 'completed'
    GROUP BY sub.topic_id, sub.topic_name
    ORDER BY AVG(sub.avg_focus_score) ASC
    LIMIT 1
  )                                                 AS weakest_topic,
  MAX(s.started_at)                                 AS last_session_at
FROM profiles p
LEFT JOIN sessions s ON s.student_id = p.id AND s.status = 'completed'
WHERE p.role = 'student'
GROUP BY p.id, p.name;

-- Intervention efficacy for RL insights
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
  ROW_NUMBER() OVER (
    PARTITION BY i.student_id, s.topic_id
    ORDER BY AVG(CASE WHEN i.recovered THEN 1.0 ELSE 0.0 END) DESC,
             AVG(i.reward) DESC
  )                                                 AS format_rank
FROM interventions i
JOIN sessions s ON s.id = i.session_id
GROUP BY i.student_id, s.topic_id, i.format;

-- Teacher's student overview
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

-- ============================================================
-- 4. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attention_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE interventions ENABLE ROW LEVEL SECURITY;
ALTER TABLE baselines ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_monitors ENABLE ROW LEVEL SECURITY;

-- For v1 (no auth): allow all operations via anon key.
-- Tighten these when real auth is added.

CREATE POLICY "Allow all on profiles" ON profiles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on sessions" ON sessions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on attention_snapshots" ON attention_snapshots FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on interventions" ON interventions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on baselines" ON baselines FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all on teacher_monitors" ON teacher_monitors FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- 5. UPDATED_AT TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 6. ENABLE REALTIME
-- ============================================================

-- Enable realtime for tables that need live subscriptions
ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE interventions;
