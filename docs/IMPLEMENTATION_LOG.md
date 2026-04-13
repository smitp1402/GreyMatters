# Implementation Log

> Tracks what actually happened vs. what was planned during each phase.

## Phase 1: Python Daemon (Mock + Real) — 2026-04-12
- **Status:** Complete
- **Deliverables:** 5/5 complete
  - [x] WebSocket broadcast to multiple clients (was single-client)
  - [x] Mock cycle timing tuned for demo (60s focus / 15s drift / 10s lost / 30s recovery)
  - [x] Calibration command support (`set_session`, `calibrate`)
  - [x] `daemon/mediapipe_server.py` created (real + mock hand tracking)
  - [x] Mock daemon tested end-to-end (5 messages at 1Hz, session command verified)
- **Deviations:**
  - Rewrote daemon from scratch using frozen dataclasses and proper broadcast architecture instead of patching the scaffold (minor — better code quality)
  - Added `--demo` flag for fast cycle timing separate from `--mock` (minor — additive)
  - `websockets.server.WebSocketServerProtocol` deprecation warning — cosmetic, does not affect function (minor)
- **Notes:** BrainFlow Crown connection code present but untested (no hardware). Mock daemon is the primary path for demo.
