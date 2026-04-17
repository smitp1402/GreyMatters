#!/usr/bin/env python3
"""
GreyMatter EEG Daemon (Neurosity SDK Transport)

Alternative to attention_engine_lsl.py. Uses Neurosity's cloud-based Python SDK
(focus() + brainwaves_power_by_band()) instead of LSL raw EEG.

Pipeline:
    1. Neurosity SDK subscribes to focus() and brainwaves_power_by_band() (~4 Hz each)
    2. Rolling-average buffer smooths focus values (configurable window)
    3. Single-baseline calibration captures user's resting focus value
    4. Per-tick classification: lost / drifting / focused (relative to resting)
    5. Emits same AttentionState JSON schema as the LSL engine on ws://localhost:8765

Why parallel to the LSL engine:
    - LSL reads Crown directly over WiFi (privacy-preserving, no cloud)
    - SDK reads from Neurosity's Firebase cloud — easier but less private
    - This engine exists as a A/B test to see if SDK-computed focus beats
      our own beta/(alpha+theta) ratio. Either engine runs independently on
      port 8765 — only one at a time.

Prerequisites:
    - Crown logged in via the Neurosity mobile app
    - Crown on the same WiFi (or cellular relay via Neurosity cloud)
    - daemon/.env contains NEUROSITY_EMAIL, NEUROSITY_PASSWORD, NEUROSITY_DEVICE_ID
    - pip install -r daemon/requirements-sdk.txt

Usage:
    python focus_engine_sdk.py                              # real Crown via SDK
    python focus_engine_sdk.py --mock                       # offline mock data
    python focus_engine_sdk.py --smooth-window=7            # 7s rolling average

Classification thresholds (derived from 30s calibration):
    lost_threshold  = clamp(resting − 0.5 × resting_std, 0.15, 0.32)
    focus_threshold = clamp(resting + 0.12,              0.30, 0.52)

Rollback: just run attention_engine_lsl.py instead. Zero state shared.
"""

from __future__ import annotations

import asyncio
import collections
import json
import logging
import math
import os
import random
import statistics
import sys
import threading
import time
from argparse import ArgumentParser
from dataclasses import asdict, dataclass, field, replace
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Optional, Set

import websockets
from websockets.server import WebSocketServerProtocol

# ── Logging ──────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("greymatter.sdk_daemon")


# ── Constants ────────────────────────────────────────────────────────────

WS_PORT = 8765  # Same port as LSL engine — run one daemon at a time.
EMIT_RATE_HZ = 1.0  # Match LSL engine's broadcast cadence.
LOG_EVERY_N_TICKS = 5  # Console logs every 5s; WebSocket broadcast stays at EMIT_RATE_HZ.

# Neurosity SDK emits focus() and brainwaves_power_by_band() at ~4 Hz.
# Used to convert smooth-window seconds → buffer sample count.
SDK_EXPECTED_HZ = 4.0

# If no fresh focus sample for this long, we treat the stream as stalled and
# keep emitting the last known state (silent reconnect per the design spec).
STALENESS_THRESHOLD_SEC = 3.0

# Defaults — all overridable via CLI flags.
DEFAULT_RESTING = 0.5
DEFAULT_RESTING_STD = 0.05
DEFAULT_SMOOTH_WINDOW_SEC = 5.0

# Threshold formula (see /implement Q1–Q6 decision notes):
#   lost_threshold  = resting − LOST_STD_MULTIPLIER × resting_std
#   focus_threshold = resting + FOCUS_OFFSET_FROM_RESTING
# Both thresholds are clamped to keep the Lost zone from collapsing when
# calibration std is tiny (SDK probability is already heavily smoothed).
LOST_STD_MULTIPLIER = 0.5
FOCUS_OFFSET_FROM_RESTING = 0.12
LOST_THRESHOLD_MIN = 0.15
LOST_THRESHOLD_MAX = 0.32
FOCUS_THRESHOLD_MIN = 0.30
FOCUS_THRESHOLD_MAX = 0.52

# Crown 8-channel layout: CP3, C3, F5, PO3, PO4, F6, C4, CP4.
# SDK power-by-band payloads arrive as 8-element lists in this order.
CROWN_CHANNEL_LABELS = ["CP3", "C3", "F5", "PO3", "PO4", "F6", "C4", "CP4"]
BAND_NAMES = ("delta", "theta", "alpha", "beta", "gamma")


# ── Data Models (same schema as LSL engine) ──────────────────────────────

class AttentionLevel(str, Enum):
    focused = "focused"
    drifting = "drifting"
    lost = "lost"


@dataclass(frozen=True)
class AttentionState:
    session_id: str
    focus_score: float
    delta: float
    theta: float
    alpha: float
    beta: float
    gamma: float
    level: str
    timestamp: float
    theta_alpha: float
    beta_theta: float
    beta_alpha_theta: float
    signal_quality: dict[str, float]
    baseline_ratio: float = 0.0
    focused_threshold: float = 0.0
    lost_threshold: float = 0.0
    band_powers_absolute: dict[str, float] = field(default_factory=dict)

    def to_json(self) -> str:
        return json.dumps(asdict(self))


# ── SDK Producer ─────────────────────────────────────────────────────────

class SDKProducer:
    """Wraps the Neurosity SDK. Subscribes to focus() and brainwaves_power_by_band().

    SDK callbacks fire on the SDK's internal thread — all shared state is
    guarded by a single lock. The asyncio broadcast loop reads values via
    the get_* methods without blocking.
    """

    def __init__(self, smooth_window_samples: int) -> None:
        self._focus_buffer: collections.deque[float] = collections.deque(
            maxlen=smooth_window_samples
        )
        # Latest raw band payload: one 8-channel list per band name.
        self._band_powers_latest: dict[str, list[float]] = {
            name: [0.0] * len(CROWN_CHANNEL_LABELS) for name in BAND_NAMES
        }
        self._lock = threading.Lock()
        self._last_focus_wallclock: float = 0.0
        self._last_bands_wallclock: float = 0.0

        self._sdk: Optional[object] = None
        self._unsubscribe_focus: Optional[object] = None
        self._unsubscribe_bands: Optional[object] = None

        # Calibration buffering — when active, every focus() sample is ALSO
        # appended to this list. Drained by stop_calibration().
        self._calibrating = False
        self._calibration_samples: list[float] = []

    # ── Connection lifecycle ─────────────────────────────────────────

    def connect(self) -> None:
        """Load .env, init SDK, log in, subscribe to both streams."""
        try:
            from neurosity import NeurositySDK
        except ImportError as exc:
            raise RuntimeError(
                "neurosity SDK not installed. Run:\n"
                "  pip install -r daemon/requirements-sdk.txt"
            ) from exc

        try:
            from dotenv import load_dotenv
        except ImportError as exc:
            raise RuntimeError(
                "python-dotenv not installed. Run:\n"
                "  pip install -r daemon/requirements-sdk.txt"
            ) from exc

        env_path = Path(__file__).parent / ".env"
        if env_path.exists():
            load_dotenv(env_path)
            logger.info("Loaded credentials from %s", env_path)
        else:
            logger.warning(
                "No .env at %s — falling back to OS environment variables", env_path
            )

        email = os.getenv("NEUROSITY_EMAIL")
        password = os.getenv("NEUROSITY_PASSWORD")
        device_id = os.getenv("NEUROSITY_DEVICE_ID")

        missing = [
            name
            for name, val in (
                ("NEUROSITY_EMAIL", email),
                ("NEUROSITY_PASSWORD", password),
                ("NEUROSITY_DEVICE_ID", device_id),
            )
            if not val
        ]
        if missing:
            raise RuntimeError(
                f"Missing credential(s): {', '.join(missing)}. "
                f"Set them in {env_path} or the OS environment."
            )

        logger.info("Initializing Neurosity SDK (device_id=%s...)", device_id[:8])
        self._sdk = NeurositySDK({"device_id": device_id})

        logger.info("Logging in as %s...", email)
        self._sdk.login({"email": email, "password": password})

        logger.info("Subscribing to focus() stream...")
        self._unsubscribe_focus = self._sdk.focus(self._on_focus)

        logger.info("Subscribing to brainwaves_power_by_band() stream...")
        self._unsubscribe_bands = self._sdk.brainwaves_power_by_band(self._on_bands)

        logger.info(
            "SDK producer ready (smoothing=%d samples ≈ %.1fs)",
            self._focus_buffer.maxlen,
            self._focus_buffer.maxlen / SDK_EXPECTED_HZ,
        )

    def disconnect(self) -> None:
        for unsub in (self._unsubscribe_focus, self._unsubscribe_bands):
            if unsub is None:
                continue
            try:
                unsub()
            except Exception as exc:
                logger.debug("Unsubscribe error (ignored): %s", exc)
        self._unsubscribe_focus = None
        self._unsubscribe_bands = None

    # ── SDK callbacks (run on SDK thread) ────────────────────────────

    def _on_focus(self, data: dict) -> None:
        try:
            prob = float(data.get("probability", 0.0))
        except (TypeError, ValueError):
            return
        prob = max(0.0, min(1.0, prob))

        with self._lock:
            self._focus_buffer.append(prob)
            self._last_focus_wallclock = time.time()
            if self._calibrating:
                self._calibration_samples.append(prob)

    def _on_bands(self, data: dict) -> None:
        # SDK sometimes nests payload under "data", sometimes flat. Handle both.
        payload = data.get("data") if isinstance(data.get("data"), dict) else data

        try:
            with self._lock:
                for band in BAND_NAMES:
                    values = payload.get(band)
                    if isinstance(values, list) and values:
                        self._band_powers_latest[band] = [float(v) for v in values]
                self._last_bands_wallclock = time.time()
        except (TypeError, ValueError):
            return

    # ── Read accessors (for asyncio loop) ────────────────────────────

    def get_smoothed_focus(self) -> Optional[float]:
        with self._lock:
            if not self._focus_buffer:
                return None
            return sum(self._focus_buffer) / len(self._focus_buffer)

    def get_band_snapshot(self) -> tuple[dict[str, float], dict[str, float]]:
        """Return (normalized_bands, absolute_bands).

        absolute_bands: mean power across 8 channels, per band (raw SDK values).
        normalized_bands: each band's share of total power (sums to 1.0).
        """
        with self._lock:
            absolute = {
                name: (sum(vals) / len(vals) if vals else 0.0)
                for name, vals in self._band_powers_latest.items()
            }

        total = sum(absolute.values())
        if total <= 0:
            normalized = {name: 0.0 for name in BAND_NAMES}
        else:
            normalized = {name: val / total for name, val in absolute.items()}
        return normalized, absolute

    def is_stream_fresh(self) -> bool:
        with self._lock:
            age = time.time() - self._last_focus_wallclock
        return age < STALENESS_THRESHOLD_SEC

    # ── Calibration API ──────────────────────────────────────────────

    def start_calibration(self) -> None:
        with self._lock:
            self._calibration_samples.clear()
            self._calibrating = True

    def stop_calibration(self) -> list[float]:
        with self._lock:
            self._calibrating = False
            samples = list(self._calibration_samples)
            self._calibration_samples.clear()
        return samples


# ── Real Crown Engine (Neurosity SDK) ────────────────────────────────────

class CrownEngineSDK:
    """Drives the SDK producer and produces AttentionState per broadcast tick."""

    def __init__(
        self,
        *,
        smooth_window_sec: float,
    ) -> None:
        self._producer: Optional[SDKProducer] = None
        self._resting: float = DEFAULT_RESTING
        self._resting_std: float = DEFAULT_RESTING_STD
        self._smooth_window_sec = smooth_window_sec
        # Keeps last successful emission so disconnects can re-broadcast it
        # instead of going silent (per Q8 design decision).
        self._last_state: Optional[AttentionState] = None

    def connect(self) -> None:
        samples = max(1, int(round(self._smooth_window_sec * SDK_EXPECTED_HZ)))
        self._producer = SDKProducer(smooth_window_samples=samples)
        self._producer.connect()

    def disconnect(self) -> None:
        if self._producer is not None:
            self._producer.disconnect()
            self._producer = None

    def compute(self, session_id: str) -> Optional[AttentionState]:
        if self._producer is None:
            return None

        smoothed = self._producer.get_smoothed_focus()

        # No data yet at all — emit nothing until the SDK has spoken once.
        if smoothed is None:
            if self._last_state is not None:
                return replace(self._last_state, timestamp=_now_ts())
            return None

        # Stream went stale (disconnect / WiFi drop) — re-emit last state with
        # a refreshed timestamp so the Flutter UI does not freeze visually.
        if not self._producer.is_stream_fresh() and self._last_state is not None:
            return replace(self._last_state, timestamp=_now_ts())

        bands_normalized, bands_absolute = self._producer.get_band_snapshot()

        lost_threshold, focused_threshold = _compute_thresholds(
            self._resting, self._resting_std
        )

        if smoothed < lost_threshold:
            level = AttentionLevel.lost
        elif smoothed >= focused_threshold:
            level = AttentionLevel.focused
        else:
            level = AttentionLevel.drifting

        state = AttentionState(
            session_id=session_id,
            focus_score=round(smoothed, 3),
            delta=round(bands_normalized["delta"], 4),
            theta=round(bands_normalized["theta"], 4),
            alpha=round(bands_normalized["alpha"], 4),
            beta=round(bands_normalized["beta"], 4),
            gamma=round(bands_normalized["gamma"], 4),
            level=level.value,
            timestamp=_now_ts(),
            # SDK doesn't expose ratio-based focus metrics — zero these so
            # the schema stays identical without fabricating fake values.
            theta_alpha=0.0,
            beta_theta=0.0,
            beta_alpha_theta=0.0,
            # SDK doesn't expose per-channel signal quality via these streams.
            # Report 100 (good) so the UI doesn't flag a false problem.
            signal_quality={label: 100.0 for label in CROWN_CHANNEL_LABELS},
            baseline_ratio=round(self._resting, 3),
            focused_threshold=round(focused_threshold, 3),
            lost_threshold=round(lost_threshold, 3),
            band_powers_absolute={
                name: round(val, 4) for name, val in bands_absolute.items()
            },
        )
        self._last_state = state
        return state

    def calibrate(self, duration_sec: int = 30) -> float:
        """Collect SDK focus values for duration_sec, set resting = mean.

        Blocking — callers should run this in a thread executor so the asyncio
        event loop keeps broadcasting during calibration.
        """
        if self._producer is None:
            logger.warning("calibrate() called before connect()")
            return self._resting

        logger.info("Calibration: sit relaxed for %ds...", duration_sec)
        self._producer.start_calibration()
        time.sleep(float(duration_sec))
        samples = self._producer.stop_calibration()

        if not samples:
            logger.warning("No calibration samples collected — keeping default resting")
            return self._resting

        mean = sum(samples) / len(samples)
        # Clamp to a sane range in case the SDK emitted weird values.
        self._resting = float(max(0.05, min(0.95, mean)))
        # Population std dev (samples ARE the population for this calibration).
        self._resting_std = (
            float(statistics.pstdev(samples)) if len(samples) >= 2 else 0.0
        )
        lost_th, focus_th = _compute_thresholds(self._resting, self._resting_std)
        logger.info(
            "Calibration done: %d samples, resting=%.3f std=%.3f "
            "(lost<%.3f, focused≥%.3f)",
            len(samples),
            self._resting,
            self._resting_std,
            lost_th,
            focus_th,
        )
        return self._resting


# ── Mock Generator (offline testing) ─────────────────────────────────────

class MockGenerator:
    """Plausible synthetic focus+band data for running without a Crown.

    Cycles through focused → drifting → lost → recovering phases so you can
    eyeball the Flutter UI and WebSocket format end-to-end.
    """

    def __init__(self, *, demo_mode: bool) -> None:
        self._tick = 0.0
        self._rng = random.Random(42)

        if demo_mode:
            self._focus_dur = 60.0
            self._drift_dur = 15.0
            self._lost_dur = 10.0
            self._recovery_dur = 30.0
        else:
            self._focus_dur = 120.0
            self._drift_dur = 30.0
            self._lost_dur = 30.0
            self._recovery_dur = 120.0

        self._cycle = (
            self._focus_dur + self._drift_dur + self._lost_dur + self._recovery_dur
        )

    def next(
        self,
        session_id: str,
        resting: float,
        lost_threshold: float,
        focused_threshold: float,
    ) -> AttentionState:
        self._tick += 1.0
        t = self._tick % self._cycle

        if t < self._focus_dur:
            base = 0.80 + 0.05 * math.sin(self._tick * 0.1)
        elif t < self._focus_dur + self._drift_dur:
            progress = (t - self._focus_dur) / self._drift_dur
            base = 0.80 - progress * 0.45
        elif t < self._focus_dur + self._drift_dur + self._lost_dur:
            base = 0.22 + 0.08 * math.sin(self._tick * 0.8)
        else:
            progress = (
                (t - self._focus_dur - self._drift_dur - self._lost_dur)
                / self._recovery_dur
            )
            base = 0.35 + progress * 0.50

        focus = max(0.0, min(1.0, base + self._rng.gauss(0, 0.03)))

        if focus < lost_threshold:
            level = AttentionLevel.lost
        elif focus >= focused_threshold:
            level = AttentionLevel.focused
        else:
            level = AttentionLevel.drifting

        delta = max(0.02, 0.15 + (1 - focus) * 0.2 + self._rng.gauss(0, 0.02))
        theta = max(0.05, 0.30 + (1 - focus) * 0.4 + self._rng.gauss(0, 0.03))
        alpha = max(0.05, 0.25 + (1 - focus) * 0.3 + self._rng.gauss(0, 0.03))
        beta = max(0.05, 0.35 + focus * 0.35 + self._rng.gauss(0, 0.03))
        gamma = max(0.02, 0.10 + focus * 0.2 + self._rng.gauss(0, 0.02))

        abs_scale = 4.0
        bp_abs = {
            "delta": round(delta * abs_scale, 4),
            "theta": round(theta * abs_scale, 4),
            "alpha": round(alpha * abs_scale, 4),
            "beta": round(beta * abs_scale, 4),
            "gamma": round(gamma * abs_scale, 4),
        }

        total = delta + theta + alpha + beta + gamma
        bp_norm = {
            "delta": round(delta / total, 4),
            "theta": round(theta / total, 4),
            "alpha": round(alpha / total, 4),
            "beta": round(beta / total, 4),
            "gamma": round(gamma / total, 4),
        }

        signal_quality = {
            label: round(max(60.0, min(100.0, 88 + self._rng.gauss(0, 5))), 1)
            for label in CROWN_CHANNEL_LABELS
        }

        return AttentionState(
            session_id=session_id,
            focus_score=round(focus, 3),
            delta=bp_norm["delta"],
            theta=bp_norm["theta"],
            alpha=bp_norm["alpha"],
            beta=bp_norm["beta"],
            gamma=bp_norm["gamma"],
            level=level.value,
            timestamp=_now_ts(),
            theta_alpha=0.0,
            beta_theta=0.0,
            beta_alpha_theta=0.0,
            signal_quality=signal_quality,
            baseline_ratio=round(resting, 3),
            focused_threshold=round(focused_threshold, 3),
            lost_threshold=round(lost_threshold, 3),
            band_powers_absolute=bp_abs,
        )


# ── WebSocket Server ─────────────────────────────────────────────────────

class AttentionServer:
    """Accepts Flutter clients on port 8765 and broadcasts AttentionState.

    Accepts the same WebSocket commands as the LSL engine:
      - {"command": "set_session", "session_id": "..."}
      - {"command": "calibrate", "duration": 30}
    """

    def __init__(
        self,
        *,
        mock: bool,
        demo: bool,
        session_id: str,
        smooth_window_sec: float,
    ) -> None:
        self._mock = mock
        self._demo = demo
        self._smooth_window_sec = smooth_window_sec

        self._clients: Set[WebSocketServerProtocol] = set()
        self._session_id = session_id
        self._running = True

        self._mock_gen: Optional[MockGenerator] = None
        self._crown: Optional[CrownEngineSDK] = None

        # Mock-mode resting value (updated by mock-mode "calibrate" command).
        self._mock_resting: float = DEFAULT_RESTING
        self._mock_resting_std: float = DEFAULT_RESTING_STD

    async def start(self) -> None:
        if self._mock:
            self._mock_gen = MockGenerator(demo_mode=self._demo)
            logger.info("Mock engine ready (demo=%s)", self._demo)
        else:
            self._crown = CrownEngineSDK(
                smooth_window_sec=self._smooth_window_sec,
            )
            try:
                self._crown.connect()
                logger.info("Crown engine ready (Neurosity SDK)")
            except Exception as exc:
                self._log_connection_failure(exc)
                sys.exit(1)

        async with websockets.serve(
            self._on_connect,
            "localhost",
            WS_PORT,
            ping_interval=20,
            ping_timeout=10,
        ):
            logger.info("WebSocket server listening on ws://localhost:%d", WS_PORT)
            await self._broadcast_loop()

    def _log_connection_failure(self, exc: Exception) -> None:
        logger.error("")
        logger.error("=" * 60)
        logger.error("  SDK NOT CONNECTED")
        logger.error("=" * 60)
        logger.error("")
        logger.error("  %s", exc)
        logger.error("")
        logger.error("  Checklist:")
        logger.error("   1. daemon/.env has NEUROSITY_EMAIL / _PASSWORD / _DEVICE_ID")
        logger.error("   2. pip install -r daemon/requirements-sdk.txt")
        logger.error("   3. Crown is ON and logged in via the Neurosity mobile app")
        logger.error("   4. Internet is reachable (SDK uses Firebase cloud)")
        logger.error("")
        logger.error("  Fall back: python daemon/focus_engine_sdk.py --mock")
        logger.error("  Or switch to LSL: python daemon/attention_engine_lsl.py")
        logger.error("=" * 60)

    async def _on_connect(self, ws: WebSocketServerProtocol) -> None:
        self._clients.add(ws)
        remote = ws.remote_address
        logger.info("Client connected: %s (%d total)", remote, len(self._clients))

        try:
            async for message in ws:
                await self._handle_command(ws, message)
        except websockets.ConnectionClosed:
            pass
        finally:
            self._clients.discard(ws)
            logger.info(
                "Client disconnected: %s (%d remaining)", remote, len(self._clients)
            )

    async def _handle_command(
        self, ws: WebSocketServerProtocol, raw: str
    ) -> None:
        try:
            cmd = json.loads(raw)
        except json.JSONDecodeError:
            logger.warning("Invalid JSON from client: %s", raw[:100])
            return

        action = cmd.get("command", "")

        if action == "set_session":
            self._session_id = cmd.get("session_id", self._session_id)
            logger.info("Session ID set to: %s", self._session_id)
            await ws.send(
                json.dumps({"status": "ok", "session_id": self._session_id})
            )

        elif action == "calibrate":
            duration = int(cmd.get("duration", 30))
            if self._crown is not None:
                loop = asyncio.get_running_loop()
                baseline = await loop.run_in_executor(
                    None, self._crown.calibrate, duration
                )
                await ws.send(
                    json.dumps({"status": "ok", "baseline": round(baseline, 3)})
                )
            else:
                # Mock calibration: no-op (keep default resting).
                self._mock_resting = DEFAULT_RESTING
                await ws.send(
                    json.dumps({"status": "ok", "baseline": self._mock_resting})
                )

        else:
            logger.warning("Unknown command: %s", action)

    async def _broadcast_loop(self) -> None:
        emit_interval = 1.0 / EMIT_RATE_HZ
        tick = 0
        while self._running:
            state = self._compute()
            if state is None:
                await asyncio.sleep(emit_interval)
                continue
            tick += 1

            # Log every 5s to keep console readable; broadcast still runs at EMIT_RATE_HZ.
            if tick % LOG_EVERY_N_TICKS == 0:
                level_color = {
                    "focused": "\033[92m",
                    "drifting": "\033[93m",
                    "lost": "\033[91m",
                }
                reset = "\033[0m"
                c = level_color.get(state.level, "")
                logger.info(
                    "%4d | %s%8s%s | focus=%.3f | resting=%.3f  lost<%.3f  focused>%.3f",
                    tick,
                    c,
                    state.level,
                    reset,
                    state.focus_score,
                    state.baseline_ratio,
                    state.lost_threshold,
                    state.focused_threshold,
                )

            if self._clients:
                payload = state.to_json()
                disconnected: list[WebSocketServerProtocol] = []
                for client in self._clients.copy():
                    try:
                        await client.send(payload)
                    except websockets.ConnectionClosed:
                        disconnected.append(client)
                for client in disconnected:
                    self._clients.discard(client)

            await asyncio.sleep(emit_interval)

    def _compute(self) -> Optional[AttentionState]:
        if self._mock_gen is not None:
            lost_th, focus_th = _compute_thresholds(
                self._mock_resting, self._mock_resting_std
            )
            return self._mock_gen.next(
                self._session_id,
                self._mock_resting,
                lost_th,
                focus_th,
            )
        if self._crown is not None:
            return self._crown.compute(self._session_id)
        return None


# ── Helpers ──────────────────────────────────────────────────────────────

def _now_ts() -> float:
    return datetime.now(timezone.utc).timestamp()


def _compute_thresholds(resting: float, resting_std: float) -> tuple[float, float]:
    """Derive (lost_threshold, focus_threshold) from a calibrated baseline."""
    raw_lost = resting - LOST_STD_MULTIPLIER * resting_std
    raw_focus = resting + FOCUS_OFFSET_FROM_RESTING
    lost = max(LOST_THRESHOLD_MIN, min(LOST_THRESHOLD_MAX, raw_lost))
    focus = max(FOCUS_THRESHOLD_MIN, min(FOCUS_THRESHOLD_MAX, raw_focus))
    return lost, focus


# ── Entry Point ──────────────────────────────────────────────────────────

def main() -> None:
    parser = ArgumentParser(description="GreyMatter EEG Daemon (Neurosity SDK)")
    parser.add_argument(
        "--mock", action="store_true", help="Mock mode (no SDK, no Crown)"
    )
    parser.add_argument(
        "--demo", action="store_true", help="Fast demo cycles (mock only)"
    )
    parser.add_argument(
        "--session-id", default="demo", help="Initial session ID"
    )
    parser.add_argument(
        "--smooth-window",
        type=float,
        default=DEFAULT_SMOOTH_WINDOW_SEC,
        help=f"Rolling-average window in seconds (default {DEFAULT_SMOOTH_WINDOW_SEC})",
    )
    args = parser.parse_args()

    server = AttentionServer(
        mock=args.mock,
        demo=args.demo,
        session_id=args.session_id,
        smooth_window_sec=args.smooth_window,
    )
    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        logger.info("Daemon stopped")


if __name__ == "__main__":
    main()
