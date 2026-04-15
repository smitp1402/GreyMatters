#!/usr/bin/env python3
"""
NeuroLearn EEG Daemon

Connects to Neurosity Crown via BrainFlow, computes real-time attention metrics,
and broadcasts AttentionState JSON over WebSocket to Flutter app.

Usage:
    python attention_engine.py              # Real Crown mode
    python attention_engine.py --mock       # Mock data for testing
    python attention_engine.py --mock --demo # Fast demo cycles (60s focus, 15s drift)
"""

from __future__ import annotations

import asyncio
import json
import logging
import math
import sys
import time
from argparse import ArgumentParser
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from enum import Enum
from typing import Optional, Set

import numpy as np
import websockets
from websockets.server import WebSocketServerProtocol

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("neurolearn.daemon")

# ── Constants ────────────────────────────────────────────────────────────

WS_PORT = 8765
SAMPLING_RATE = 256  # Crown Hz
WINDOW_SAMPLES = SAMPLING_RATE * 4  # 4-second rolling window

BANDS = {
    "delta": (2, 4),
    "theta": (4, 8),
    "alpha": (8, 13),
    "beta": (13, 30),
    "gamma": (30, 45),
}

# ── Formula V1 (active): (theta + alpha) / beta ──────────────────────
# Thresholds are now set per-student during calibration (mean + N×std).
# These are fallback defaults only used if calibration fails.
FOCUSED_THRESHOLD_DEFAULT = 1.5
LOST_THRESHOLD_DEFAULT    = 2.2
# How many std deviations from baseline mean to set thresholds:
FOCUSED_STD_MULT = 2     # mean + 2×std → drifting starts
LOST_STD_MULT    = 4     # mean + 4×std → lost starts
HYSTERESIS_WINDOWS = 2

# ── Formula V2 (inactive): composite engagement score ─────────────────
# beta/theta   — primary: active thinking vs mind-wandering (eyes-open safe)
# gamma boost  — reward for active problem-solving bursts
# alpha penalty — only extreme alpha (eyes-closed drowsiness),
#                 NOT moderate alpha which is normal during relaxed reading
# W_BETA_THETA = 0.55       # main driver
# W_GAMMA      = 0.25       # cognitive effort bonus
# W_ALPHA_PEN  = 0.20       # eyes-closed penalty (only when alpha dominates)
# ALPHA_PENALTY_ONSET = 0.35 # alpha proportion above which penalty kicks in
#
# FOCUSED_THRESHOLD_V2 = 0.45   # engagement score above this = focused
# DRIFTING_THRESHOLD_V2 = 0.30  # below this = lost, between = drifting
# HYSTERESIS_WINDOWS_V2 = 3


# ── Data Models ──────────────────────────────────────────────────────────

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

    def to_json(self) -> str:
        return json.dumps(asdict(self))


# ── Mock Data Generator ─────────────────────────────────────────────────

class MockGenerator:
    """Generates realistic synthetic EEG attention data."""

    def __init__(self, *, demo_mode: bool = False) -> None:
        self._tick = 0.0
        self._rng = np.random.default_rng(42)

        # Demo mode: faster cycles for 5-10 min demo
        if demo_mode:
            self._focus_dur = 60.0    # 60s focused
            self._drift_dur = 15.0    # 15s drifting
            self._lost_dur = 10.0     # 10s lost
            self._recovery_dur = 30.0 # 30s recovery
        else:
            self._focus_dur = 120.0
            self._drift_dur = 30.0
            self._lost_dur = 30.0
            self._recovery_dur = 120.0

        self._cycle = self._focus_dur + self._drift_dur + self._lost_dur + self._recovery_dur

    def next(self, session_id: str) -> AttentionState:
        self._tick += 1.0
        t = self._tick % self._cycle

        # Determine phase in cycle
        if t < self._focus_dur:
            base_focus = 0.82 + 0.08 * math.sin(self._tick * 0.1)
            level = AttentionLevel.focused
        elif t < self._focus_dur + self._drift_dur:
            # Gradual decline into drifting
            progress = (t - self._focus_dur) / self._drift_dur
            base_focus = 0.75 - 0.35 * progress
            level = AttentionLevel.drifting
        elif t < self._focus_dur + self._drift_dur + self._lost_dur:
            base_focus = 0.2 + 0.1 * math.sin(self._tick * 0.8)
            level = AttentionLevel.lost
        else:
            # Recovery — gradual return to focus
            progress = (t - self._focus_dur - self._drift_dur - self._lost_dur) / self._recovery_dur
            base_focus = 0.4 + 0.45 * progress
            level = AttentionLevel.focused if progress > 0.5 else AttentionLevel.drifting

        # Add natural noise
        focus = float(np.clip(base_focus + self._rng.normal(0, 0.03), 0.0, 1.0))

        # Band powers correlated with engagement (not just eye state)
        delta = float(np.clip(0.15 + (1 - focus) * 0.2 + self._rng.normal(0, 0.02), 0.05, 1.0))
        theta = float(np.clip(0.3 + (1 - focus) * 0.4 + self._rng.normal(0, 0.03), 0.05, 1.0))
        alpha = float(np.clip(0.25 + (1 - focus) * 0.3 + self._rng.normal(0, 0.03), 0.05, 1.0))
        beta = float(np.clip(0.35 + focus * 0.35 + self._rng.normal(0, 0.03), 0.05, 1.0))
        gamma = float(np.clip(0.1 + focus * 0.2 + self._rng.normal(0, 0.02), 0.02, 1.0))

        # Normalize to sum to 1
        total = delta + theta + alpha + beta + gamma
        delta, theta, alpha, beta, gamma = (
            delta / total, theta / total, alpha / total, beta / total, gamma / total
        )

        return AttentionState(
            session_id=session_id,
            focus_score=round(focus, 3),
            delta=round(delta, 4),
            theta=round(theta, 4),
            alpha=round(alpha, 4),
            beta=round(beta, 4),
            gamma=round(gamma, 4),
            level=level.value,
            timestamp=datetime.now(timezone.utc).timestamp(),
        )


# ── Real Crown Engine ────────────────────────────────────────────────────

class CrownEngine:
    """Connects to Neurosity Crown via BrainFlow and computes attention."""

    def __init__(self) -> None:
        self._board: Optional[object] = None
        self._baseline_index: float = 1.0
        self._baseline_bt: float = 1.0  # baseline beta/theta ratio
        self._recent_indices: list[float] = []
        # Per-student thresholds — set during calibration
        self._focused_threshold: float = FOCUSED_THRESHOLD_DEFAULT
        self._lost_threshold: float = LOST_THRESHOLD_DEFAULT

    def connect(self) -> None:
        try:
            from brainflow import BoardShim, BrainFlowInputParams, BoardIds

            # Enable BrainFlow debug logging for troubleshooting
            BoardShim.enable_dev_board_logger()

            params = BrainFlowInputParams()
            board_id = BoardIds.CROWN_BOARD.value
            logger.info("Searching for Neurosity Crown (board_id=%d)...", board_id)
            logger.info("Make sure Crown is ON, on same WiFi, and OSC is enabled")

            self._board = BoardShim(board_id, params)
            self._board.prepare_session()
            logger.info("Session prepared — starting stream...")
            self._board.start_stream()
            logger.info("Crown connected via BrainFlow")
        except Exception as e:
            logger.error(f"Failed to connect to Crown: {e}")
            raise

    def calibrate(self, duration_sec: int = 30) -> float:
        """Run calibration: compute baseline mean AND std, set per-student thresholds."""
        if self._board is None:
            raise RuntimeError("Crown not connected")

        logger.info(f"Calibrating for {duration_sec}s...")

        # Collect per-second index samples during calibration
        cal_indices: list[float] = []

        for elapsed in range(duration_sec):
            time.sleep(1)
            # Grab last 1 second of data
            chunk = self._board.get_current_board_data(SAMPLING_RATE)
            if chunk.shape[1] >= SAMPLING_RATE // 2:
                bp = self._compute_band_powers(chunk[[4, 5], :])
                idx = (bp["theta"] + bp["alpha"]) / max(bp["beta"], 0.001)
                cal_indices.append(idx)

            if elapsed % 5 == 4:
                n_ch, n_samp = chunk.shape
                logger.info(
                    f"[CAL {elapsed+1}s] channels={n_ch} samples={n_samp} | "
                    f"indices so far: {len(cal_indices)} | "
                    f"F5 last5=[{', '.join(f'{v:.1f}' for v in chunk[4, -5:])}] | "
                    f"F6 last5=[{', '.join(f'{v:.1f}' for v in chunk[5, -5:])}]"
                )

        if len(cal_indices) < 5:
            logger.warning("Not enough calibration samples, using default thresholds")
            return 1.0

        # Compute mean and std of attention index during focused calibration
        cal_mean = float(np.mean(cal_indices))
        cal_std = float(np.std(cal_indices))

        # Set per-student thresholds based on their natural variability
        self._baseline_index = cal_mean
        self._focused_threshold = cal_mean + FOCUSED_STD_MULT * cal_std
        self._lost_threshold = cal_mean + LOST_STD_MULT * cal_std

        # Also compute beta/theta baseline for V2 formula (kept for reference)
        data = self._board.get_board_data()
        if data.shape[1] >= SAMPLING_RATE:
            bp = self._compute_band_powers(data[[4, 5], :])
            self._baseline_bt = bp["beta"] / max(bp["theta"], 0.001)

        logger.info(
            f"[CAL DONE] samples={len(cal_indices)} "
            f"mean={cal_mean:.3f} std={cal_std:.3f}"
        )
        logger.info(
            f"[CAL THRESHOLDS] focused ≤ {self._focused_threshold:.3f} "
            f"(mean+{FOCUSED_STD_MULT}×std) | "
            f"lost > {self._lost_threshold:.3f} "
            f"(mean+{LOST_STD_MULT}×std)"
        )
        return self._baseline_index

    def compute(self, session_id: str) -> Optional[AttentionState]:
        """Compute current AttentionState from live EEG."""
        if self._board is None:
            raise RuntimeError("Crown not connected")

        data = self._board.get_current_board_data(WINDOW_SAMPLES)

        # Print raw data summary so we can verify Crown is streaming
        n_channels, n_samples = data.shape
        if n_samples == 0:
            logger.warning("[RAW] No samples received — Crown not streaming")
            return None

        logger.info(
            f"[RAW] channels={n_channels} samples={n_samples} | "
            f"ch0 range=[{data[0].min():.1f}, {data[0].max():.1f}] | "
            f"ch4(F5)=[{data[4].min():.1f}, {data[4].max():.1f}] | "
            f"ch5(F6)=[{data[5].min():.1f}, {data[5].max():.1f}]"
        )

        if data.shape[1] < SAMPLING_RATE:
            logger.warning(f"[RAW] Not enough samples ({n_samples} < {SAMPLING_RATE}), skipping computation")
            return AttentionState(
                session_id=session_id,
                focus_score=0.5,
                theta=0.25, alpha=0.25, beta=0.25, gamma=0.25,
                level=AttentionLevel.focused.value,
                timestamp=datetime.now(timezone.utc).timestamp(),
            )

        frontal = data[[4, 5], :]
        bp = self._compute_band_powers(frontal)
        logger.info(
            f"[BAND] raw: δ={bp['delta']:.4f} θ={bp['theta']:.4f} "
            f"α={bp['alpha']:.4f} β={bp['beta']:.4f} γ={bp['gamma']:.4f}"
        )

        # Normalize band powers to proportions (sum to 1)
        total = sum(bp.values())
        norm = {k: v / total for k, v in bp.items()} if total > 0 else bp

        # ── V1 (active): (theta + alpha) / beta ──────────────
        # Thresholds are on raw index scale (set during calibration as mean + N×std)
        attn_index = (bp["theta"] + bp["alpha"]) / max(bp["beta"], 0.001)
        level = self._classify(attn_index)
        # Focus score: 1.0 at baseline mean, 0.0 at lost threshold
        focus_range = max(self._lost_threshold - self._baseline_index, 0.001)
        focus = float(np.clip(1.0 - (attn_index - self._baseline_index) / focus_range, 0.0, 1.0))

        logger.info(
            f"[ATTN] index={attn_index:.3f} thresholds=[{self._focused_threshold:.3f},{self._lost_threshold:.3f}] "
            f"→ focus={focus:.3f} level={level.value}"
        )

        # ── V2 (inactive): composite engagement score ──────────
        # bt_ratio = bp["beta"] / max(bp["theta"], 0.001)
        # bt_baseline = self._baseline_bt if hasattr(self, '_baseline_bt') else 1.0
        # bt_norm = min(bt_ratio / max(bt_baseline, 0.001), 2.0) / 2.0
        # gamma_norm = min(norm["gamma"] / 0.15, 1.0)
        # alpha_excess = max(norm["alpha"] - ALPHA_PENALTY_ONSET, 0.0) / (1.0 - ALPHA_PENALTY_ONSET)
        # alpha_pen = alpha_excess
        # engagement = W_BETA_THETA * bt_norm + W_GAMMA * gamma_norm - W_ALPHA_PEN * alpha_pen
        # engagement = float(np.clip(engagement, 0.0, 1.0))
        # level = self._classify_v2(engagement)
        # focus = engagement

        return AttentionState(
            session_id=session_id,
            focus_score=round(focus, 3),
            delta=round(norm.get("delta", 0), 4),
            theta=round(norm["theta"], 4),
            alpha=round(norm["alpha"], 4),
            beta=round(norm["beta"], 4),
            gamma=round(norm["gamma"], 4),
            level=level.value,
            timestamp=datetime.now(timezone.utc).timestamp(),
        )

    def _compute_band_powers(self, frontal_data: np.ndarray) -> dict[str, float]:
        from scipy.signal import welch as welch_psd

        powers: dict[str, float] = {}
        for band, (lo, hi) in BANDS.items():
            ch_powers = []
            for ch in range(frontal_data.shape[0]):
                freqs, psd = welch_psd(
                    frontal_data[ch],
                    fs=SAMPLING_RATE,
                    nperseg=min(1024, frontal_data.shape[1]),
                )
                mask = (freqs >= lo) & (freqs <= hi)
                ch_powers.append(float(np.sum(psd[mask])))
            powers[band] = float(np.mean(ch_powers))
        return powers

    # ── V1 classifier (active): per-student thresholds from calibration ──
    def _classify(self, raw_index: float) -> AttentionLevel:
        self._recent_indices.append(raw_index)
        if len(self._recent_indices) > HYSTERESIS_WINDOWS:
            self._recent_indices.pop(0)
        if len(self._recent_indices) < HYSTERESIS_WINDOWS:
            return AttentionLevel.focused
        avg = sum(self._recent_indices) / len(self._recent_indices)
        if avg <= self._focused_threshold:
            return AttentionLevel.focused
        elif avg <= self._lost_threshold:
            return AttentionLevel.drifting
        return AttentionLevel.lost

    # ── V2 classifier (inactive): higher engagement = more focused ──
    # def _classify_v2(self, engagement_score: float) -> AttentionLevel:
    #     self._recent_indices.append(engagement_score)
    #     if len(self._recent_indices) > 3:
    #         self._recent_indices.pop(0)
    #     if len(self._recent_indices) < 3:
    #         return AttentionLevel.focused
    #     avg = sum(self._recent_indices) / len(self._recent_indices)
    #     if avg >= 0.45:
    #         return AttentionLevel.focused
    #     elif avg >= 0.30:
    #         return AttentionLevel.drifting
    #     return AttentionLevel.lost

    def disconnect(self) -> None:
        if self._board is not None:
            try:
                self._board.stop_stream()
                self._board.release_session()
            except Exception:
                pass
            self._board = None


# ── WebSocket Server ─────────────────────────────────────────────────────

class AttentionServer:
    """Broadcasts AttentionState to all connected WebSocket clients."""

    def __init__(self, *, mock: bool, demo: bool) -> None:
        self._mock = mock
        self._demo = demo
        self._clients: Set[WebSocketServerProtocol] = set()
        self._session_id = "demo"
        self._running = True

        # Engine
        self._mock_gen: Optional[MockGenerator] = None
        self._crown: Optional[CrownEngine] = None

    async def start(self) -> None:
        # Initialize engine
        if self._mock:
            self._mock_gen = MockGenerator(demo_mode=self._demo)
            logger.info("Mock engine ready (demo=%s)", self._demo)
        else:
            self._crown = CrownEngine()
            max_retries = 5
            for attempt in range(1, max_retries + 1):
                try:
                    self._crown.connect()
                    logger.info("Crown engine ready")
                    break
                except Exception as e:
                    logger.warning(f"Attempt {attempt}/{max_retries} failed: {e}")
                    self._crown.disconnect()
                    if attempt < max_retries:
                        wait = 5 * attempt
                        logger.info(f"Retrying in {wait}s... (put Crown on head, check WiFi)")
                        await asyncio.sleep(wait)
                    else:
                        logger.error("")
                        logger.error("=" * 60)
                        logger.error("  CROWN NOT CONNECTED after %d attempts", max_retries)
                        logger.error("=" * 60)
                        logger.error("")
                        logger.error("  Checklist:")
                        logger.error("  1. Crown headset is ON (green LED)")
                        logger.error("  2. Crown is on the SAME WiFi as this computer")
                        logger.error("  3. OSC is ENABLED in Neurosity Developer Console")
                        logger.error("  4. Windows Firewall allows UDP port 9000")
                        logger.error("")
                        logger.error("  Or use: python daemon/attention_engine.py --mock")
                        logger.error("=" * 60)
                        sys.exit(1)

        # Start WebSocket server
        async with websockets.serve(
            self._on_connect,
            "localhost",
            WS_PORT,
            ping_interval=20,
            ping_timeout=10,
        ):
            logger.info("WebSocket server listening on ws://localhost:%d", WS_PORT)
            await self._broadcast_loop()

    async def _on_connect(self, ws: WebSocketServerProtocol) -> None:
        """Handle new client connection."""
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
            logger.info("Client disconnected: %s (%d remaining)", remote, len(self._clients))

    async def _handle_command(self, ws: WebSocketServerProtocol, raw: str) -> None:
        """Handle commands from Flutter app."""
        try:
            cmd = json.loads(raw)
            action = cmd.get("command", "")

            if action == "set_session":
                self._session_id = cmd.get("session_id", self._session_id)
                logger.info("Session ID set to: %s", self._session_id)
                await ws.send(json.dumps({"status": "ok", "session_id": self._session_id}))

            elif action == "calibrate":
                if self._crown is not None:
                    duration = cmd.get("duration", 30)
                    baseline = self._crown.calibrate(duration)
                    await ws.send(json.dumps({"status": "ok", "baseline": baseline}))
                else:
                    # Mock calibration — instant
                    await ws.send(json.dumps({"status": "ok", "baseline": 1.0}))

            else:
                logger.warning("Unknown command: %s", action)

        except json.JSONDecodeError:
            logger.warning("Invalid JSON from client: %s", raw[:100])

    async def _broadcast_loop(self) -> None:
        """Main loop — compute attention every 1s and broadcast to all clients."""
        tick = 0
        while self._running:
            state = self._compute()
            if state is None:
                await asyncio.sleep(1.0)
                continue
            tick += 1

            # Print live data to terminal
            level_color = {"focused": "\033[92m", "drifting": "\033[93m", "lost": "\033[91m"}
            reset = "\033[0m"
            c = level_color.get(state.level, "")
            logger.info(
                f"{tick:4d} | {c}{state.level:8s}{reset} | "
                f"focus={state.focus_score:.3f} | "
                f"θ={state.theta:.3f} α={state.alpha:.3f} "
                f"β={state.beta:.3f} γ={state.gamma:.3f}"
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

            await asyncio.sleep(1.0)

    def _compute(self) -> Optional[AttentionState]:
        if self._mock_gen is not None:
            return self._mock_gen.next(self._session_id)
        elif self._crown is not None:
            return self._crown.compute(self._session_id)
        else:
            raise RuntimeError("No engine available")


# ── Entry Point ──────────────────────────────────────────────────────────

def main() -> None:
    parser = ArgumentParser(description="NeuroLearn EEG Daemon")
    parser.add_argument("--mock", action="store_true", help="Mock mode (no Crown)")
    parser.add_argument("--demo", action="store_true", help="Fast demo cycles (60s/15s/10s)")
    parser.add_argument("--session-id", default="demo", help="Initial session ID")
    args = parser.parse_args()

    server = AttentionServer(mock=args.mock, demo=args.demo)
    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        logger.info("Daemon stopped")


if __name__ == "__main__":
    main()
