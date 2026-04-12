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
    "theta": (4, 8),
    "alpha": (8, 13),
    "beta": (13, 30),
    "gamma": (30, 45),
}

FOCUSED_THRESHOLD = 1.5
LOST_THRESHOLD = 2.2
HYSTERESIS_WINDOWS = 2


# ── Data Models ──────────────────────────────────────────────────────────

class AttentionLevel(str, Enum):
    focused = "focused"
    drifting = "drifting"
    lost = "lost"


@dataclass(frozen=True)
class AttentionState:
    session_id: str
    focus_score: float
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

        # Band powers correlated with focus
        theta = float(np.clip(0.3 + (1 - focus) * 0.4 + self._rng.normal(0, 0.03), 0.05, 1.0))
        alpha = float(np.clip(0.25 + (1 - focus) * 0.3 + self._rng.normal(0, 0.03), 0.05, 1.0))
        beta = float(np.clip(0.35 + focus * 0.35 + self._rng.normal(0, 0.03), 0.05, 1.0))
        gamma = float(np.clip(0.1 + focus * 0.2 + self._rng.normal(0, 0.02), 0.02, 1.0))

        # Normalize to sum to 1
        total = theta + alpha + beta + gamma
        theta, alpha, beta, gamma = theta / total, alpha / total, beta / total, gamma / total

        return AttentionState(
            session_id=session_id,
            focus_score=round(focus, 3),
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
        self._recent_indices: list[float] = []

    def connect(self) -> None:
        try:
            from brainflow import BoardShim, BrainFlowInputParams, BoardIds

            params = BrainFlowInputParams()
            self._board = BoardShim(BoardIds.CROWN_BOARD, params)
            self._board.prepare_session()
            self._board.start_stream()
            logger.info("Crown connected via BrainFlow")
        except Exception as e:
            logger.error(f"Failed to connect to Crown: {e}")
            raise

    def calibrate(self, duration_sec: int = 30) -> float:
        """Run calibration and return baseline index."""
        if self._board is None:
            raise RuntimeError("Crown not connected")

        logger.info(f"Calibrating for {duration_sec}s...")
        time.sleep(duration_sec)

        data = self._board.get_board_data()
        if data.shape[1] < SAMPLING_RATE:
            logger.warning("Not enough calibration data, using default baseline")
            return 1.0

        # Compute baseline from frontal channels
        band_powers = self._compute_band_powers(data[[4, 5], :])
        self._baseline_index = (band_powers["theta"] + band_powers["alpha"]) / max(band_powers["beta"], 0.001)
        logger.info(f"Baseline index: {self._baseline_index:.3f}")
        return self._baseline_index

    def compute(self, session_id: str) -> AttentionState:
        """Compute current AttentionState from live EEG."""
        if self._board is None:
            raise RuntimeError("Crown not connected")

        data = self._board.get_current_board_data(WINDOW_SAMPLES)
        if data.shape[1] < SAMPLING_RATE:
            return AttentionState(
                session_id=session_id,
                focus_score=0.5,
                theta=0.25, alpha=0.25, beta=0.25, gamma=0.25,
                level=AttentionLevel.focused.value,
                timestamp=datetime.now(timezone.utc).timestamp(),
            )

        frontal = data[[4, 5], :]
        bp = self._compute_band_powers(frontal)

        # Normalize
        total = sum(bp.values())
        norm = {k: v / total for k, v in bp.items()}

        # Attention index
        attn_index = (bp["theta"] + bp["alpha"]) / max(bp["beta"], 0.001)
        normalized = attn_index / self._baseline_index

        # Classify with hysteresis
        level = self._classify(normalized)

        focus = float(np.clip(1.0 - (normalized - 1.0) * 0.5, 0.0, 1.0))

        return AttentionState(
            session_id=session_id,
            focus_score=round(focus, 3),
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

    def _classify(self, normalized_index: float) -> AttentionLevel:
        self._recent_indices.append(normalized_index)
        if len(self._recent_indices) > HYSTERESIS_WINDOWS:
            self._recent_indices.pop(0)

        if len(self._recent_indices) < HYSTERESIS_WINDOWS:
            return AttentionLevel.focused

        avg = sum(self._recent_indices) / len(self._recent_indices)
        if avg <= FOCUSED_THRESHOLD:
            return AttentionLevel.focused
        elif avg <= LOST_THRESHOLD:
            return AttentionLevel.drifting
        return AttentionLevel.lost

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
            self._crown.connect()
            logger.info("Crown engine ready")

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
        while self._running:
            state = self._compute()
            if self._clients:
                payload = state.to_json()
                # Broadcast to all connected clients concurrently
                disconnected: list[WebSocketServerProtocol] = []
                for client in self._clients.copy():
                    try:
                        await client.send(payload)
                    except websockets.ConnectionClosed:
                        disconnected.append(client)
                for client in disconnected:
                    self._clients.discard(client)

            await asyncio.sleep(1.0)

    def _compute(self) -> AttentionState:
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
