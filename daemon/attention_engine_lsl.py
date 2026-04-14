#!/usr/bin/env python3
"""
GreyMatter EEG Daemon (LSL Transport)

Connects to Neurosity Crown via LSL (Lab Streaming Layer), computes real-time
attention metrics, and broadcasts AttentionState JSON over WebSocket to Flutter app.

LSL uses TCP unicast — far more reliable than BrainFlow's OSC/UDP broadcast,
which suffered 22-65% packet loss on WiFi.

Prerequisites:
    - Enable LSL in Neurosity Developer Console (Settings → Lab Streaming Layer)
    - Crown on same WiFi as this computer
    - pip install pylsl

Usage:
    python attention_engine_lsl.py              # Real Crown mode (LSL)
    python attention_engine_lsl.py --mock       # Mock data for testing
    python attention_engine_lsl.py --mock --demo # Fast demo cycles
"""

from __future__ import annotations

import asyncio
import json
import logging
import math
import sys
import time
import threading
import queue
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
logger = logging.getLogger("greymatter.daemon")

# ── Constants ────────────────────────────────────────────────────────────

WS_PORT = 8765
SAMPLING_RATE = 256  # Crown Hz
WINDOW_SAMPLES = SAMPLING_RATE * 4  # 4-second rolling window
RING_BUFFER_S = 10  # seconds of data to keep in ring buffer

BANDS = {
    "theta": (4, 8),
    "alpha": (8, 13),
    "beta": (13, 30),
    "gamma": (30, 45),
}

# Channel indices in Crown's 8-channel layout: CP3, C3, F5, PO3, PO4, F6, C4, CP4
# Frontal channels: F5 (index 2) and F6 (index 5)
FRONTAL_CHANNELS = [2, 5]

FOCUSED_THRESHOLD = 1.5
LOST_THRESHOLD = 2.2
HYSTERESIS_WINDOWS = 2

LSL_DISCOVERY_TIMEOUT = 10  # seconds to wait for Crown LSL stream


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

        self._cycle = self._focus_dur + self._drift_dur + self._lost_dur + self._recovery_dur

    def next(self, session_id: str) -> AttentionState:
        self._tick += 1.0
        t = self._tick % self._cycle

        if t < self._focus_dur:
            base_focus = 0.82 + 0.08 * math.sin(self._tick * 0.1)
            level = AttentionLevel.focused
        elif t < self._focus_dur + self._drift_dur:
            progress = (t - self._focus_dur) / self._drift_dur
            base_focus = 0.75 - 0.35 * progress
            level = AttentionLevel.drifting
        elif t < self._focus_dur + self._drift_dur + self._lost_dur:
            base_focus = 0.2 + 0.1 * math.sin(self._tick * 0.8)
            level = AttentionLevel.lost
        else:
            progress = (t - self._focus_dur - self._drift_dur - self._lost_dur) / self._recovery_dur
            base_focus = 0.4 + 0.45 * progress
            level = AttentionLevel.focused if progress > 0.5 else AttentionLevel.drifting

        focus = float(np.clip(base_focus + self._rng.normal(0, 0.03), 0.0, 1.0))

        theta = float(np.clip(0.3 + (1 - focus) * 0.4 + self._rng.normal(0, 0.03), 0.05, 1.0))
        alpha = float(np.clip(0.25 + (1 - focus) * 0.3 + self._rng.normal(0, 0.03), 0.05, 1.0))
        beta = float(np.clip(0.35 + focus * 0.35 + self._rng.normal(0, 0.03), 0.05, 1.0))
        gamma = float(np.clip(0.1 + focus * 0.2 + self._rng.normal(0, 0.02), 0.02, 1.0))

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


# ── LSL Producer Thread ─────────────────────────────────────────────────

class LSLProducer(threading.Thread):
    """Background thread: pulls EEG chunks from Crown via LSL and writes
    them into a shared ring buffer."""

    def __init__(self, inlet: object, ring_buffer: np.ndarray) -> None:
        super().__init__(daemon=True, name="LSLProducer")
        self.inlet = inlet
        self.ring_buffer = ring_buffer  # shape: (n_channels, buffer_samples)
        self.write_pos = 0
        self.total_samples = 0
        self.stop_event = threading.Event()
        self.lock = threading.Lock()
        self.last_error: Optional[Exception] = None

    def run(self) -> None:
        from pylsl.util import LostError

        buf_len = self.ring_buffer.shape[1]

        while not self.stop_event.is_set():
            try:
                samples, timestamps = self.inlet.pull_chunk(
                    timeout=0.1, max_samples=256
                )
                if samples:
                    chunk = np.array(samples).T  # (n_channels, n_samples)
                    n_samples = chunk.shape[1]

                    with self.lock:
                        # Write into ring buffer (circular)
                        end_pos = self.write_pos + n_samples
                        if end_pos <= buf_len:
                            self.ring_buffer[:, self.write_pos:end_pos] = chunk
                        else:
                            # Wrap around
                            first = buf_len - self.write_pos
                            self.ring_buffer[:, self.write_pos:] = chunk[:, :first]
                            self.ring_buffer[:, :n_samples - first] = chunk[:, first:]
                        self.write_pos = end_pos % buf_len
                        self.total_samples += n_samples

            except LostError:
                logger.warning("LSL stream lost, waiting for auto-reconnect...")
                time.sleep(0.25)
            except Exception as exc:
                self.last_error = exc
                logger.error(f"LSL producer error: {exc}")
                break

    def get_current_data(self, n_samples: int) -> np.ndarray:
        """Get the last n_samples from the ring buffer."""
        with self.lock:
            available = min(n_samples, self.total_samples, self.ring_buffer.shape[1])
            if available == 0:
                return np.zeros((self.ring_buffer.shape[0], 0))

            end = self.write_pos
            start = (end - available) % self.ring_buffer.shape[1]

            if start < end:
                return self.ring_buffer[:, start:end].copy()
            else:
                return np.hstack([
                    self.ring_buffer[:, start:],
                    self.ring_buffer[:, :end]
                ]).copy()

    def stop(self) -> None:
        self.stop_event.set()


# ── Real Crown Engine (LSL) ─────────────────────────────────────────────

class CrownEngineLSL:
    """Connects to Neurosity Crown via LSL and computes attention."""

    def __init__(self) -> None:
        self._producer: Optional[LSLProducer] = None
        self._inlet: Optional[object] = None
        self._baseline_index: float = 1.0
        self._recent_indices: list[float] = []
        self._channel_count: int = 8

    def connect(self) -> None:
        from pylsl import StreamInlet, resolve_streams

        logger.info("Discovering LSL streams on local network (timeout=%ds)...", LSL_DISCOVERY_TIMEOUT)
        all_streams = resolve_streams(wait_time=LSL_DISCOVERY_TIMEOUT)

        if not all_streams:
            raise RuntimeError(
                "No LSL streams found. Check:\n"
                "  1. LSL is enabled in Neurosity Developer Console\n"
                "  2. Crown is ON and on same WiFi\n"
                "  3. Crown has power"
            )

        # Log all discovered streams
        for i, s in enumerate(all_streams):
            logger.info(
                "  [%d] name='%s' type='%s' channels=%d rate=%.0f",
                i, s.name(), s.type(), s.channel_count(), s.nominal_srate()
            )

        # Pick the EEG stream
        eeg_streams = [s for s in all_streams if s.type().lower() == "eeg"]
        if not eeg_streams:
            raise RuntimeError("No EEG-type LSL stream found")

        info = eeg_streams[0]
        self._channel_count = info.channel_count()
        nominal_rate = info.nominal_srate() or SAMPLING_RATE

        logger.info("Selected stream: '%s' (%d channels @ %.0f Hz)",
                     info.name(), self._channel_count, nominal_rate)

        # Extract channel labels if available
        try:
            desc = info.desc()
            channels_elem = desc.child("channels")
            if not channels_elem.empty():
                labels = []
                ch = channels_elem.child("channel")
                while not ch.empty():
                    labels.append(ch.child_value("label") or "?")
                    ch = ch.next_sibling()
                if labels:
                    logger.info("Channel labels: %s", labels)
        except Exception:
            pass

        # Open inlet
        self._inlet = StreamInlet(
            info,
            max_buflen=int(RING_BUFFER_S) + 5,
            recover=True,
        )

        # Create ring buffer and start producer thread
        buf_samples = int(RING_BUFFER_S * SAMPLING_RATE)
        ring_buffer = np.zeros((self._channel_count, buf_samples))
        self._producer = LSLProducer(self._inlet, ring_buffer)
        self._producer.start()

        # Wait a moment for data to start flowing
        logger.info("Waiting for EEG data...")
        time.sleep(2)

        if self._producer.total_samples > 0:
            logger.info("Crown connected via LSL — receiving data (%d samples so far)",
                        self._producer.total_samples)
        else:
            logger.warning("Connected but no samples yet — Crown may need a moment")

    def calibrate(self, duration_sec: int = 30) -> float:
        """Run calibration and return baseline index."""
        if self._producer is None:
            raise RuntimeError("Crown not connected")

        logger.info("Calibrating for %ds...", duration_sec)

        for elapsed in range(duration_sec):
            time.sleep(1)
            if elapsed % 5 == 4:
                data = self._producer.get_current_data(SAMPLING_RATE)
                logger.info(
                    "[CAL %ds] samples=%d total_received=%d",
                    elapsed + 1, data.shape[1], self._producer.total_samples
                )

        data = self._producer.get_current_data(SAMPLING_RATE * duration_sec)
        logger.info("[CAL DONE] samples available: %d", data.shape[1])

        if data.shape[1] < SAMPLING_RATE:
            logger.warning("Not enough calibration data, using default baseline")
            return 1.0

        frontal = data[FRONTAL_CHANNELS, :]
        band_powers = self._compute_band_powers(frontal)
        logger.info(
            "[CAL BANDS] θ=%.4f α=%.4f β=%.4f γ=%.4f",
            band_powers["theta"], band_powers["alpha"],
            band_powers["beta"], band_powers["gamma"]
        )
        self._baseline_index = (band_powers["theta"] + band_powers["alpha"]) / max(band_powers["beta"], 0.001)
        logger.info("Baseline index: %.3f", self._baseline_index)
        return self._baseline_index

    def compute(self, session_id: str) -> Optional[AttentionState]:
        """Compute current AttentionState from live EEG."""
        if self._producer is None:
            raise RuntimeError("Crown not connected")

        data = self._producer.get_current_data(WINDOW_SAMPLES)
        n_channels, n_samples = data.shape

        if n_samples == 0:
            logger.warning("[RAW] No samples in buffer — Crown not streaming")
            return None

        logger.info(
            "[RAW] channels=%d samples=%d | "
            "F5 range=[%.1f, %.1f] | F6 range=[%.1f, %.1f]",
            n_channels, n_samples,
            data[FRONTAL_CHANNELS[0]].min(), data[FRONTAL_CHANNELS[0]].max(),
            data[FRONTAL_CHANNELS[1]].min(), data[FRONTAL_CHANNELS[1]].max(),
        )

        if n_samples < SAMPLING_RATE:
            logger.warning("[RAW] Not enough samples (%d < %d), waiting...", n_samples, SAMPLING_RATE)
            return None

        frontal = data[FRONTAL_CHANNELS, :]
        bp = self._compute_band_powers(frontal)
        logger.info(
            "[BAND] θ=%.4f α=%.4f β=%.4f γ=%.4f",
            bp["theta"], bp["alpha"], bp["beta"], bp["gamma"]
        )

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
        if self._producer is not None:
            self._producer.stop()
            self._producer = None
        if self._inlet is not None:
            try:
                self._inlet.close_stream()
            except Exception:
                pass
            self._inlet = None


# ── WebSocket Server ─────────────────────────────────────────────────────

class AttentionServer:
    """Broadcasts AttentionState to all connected WebSocket clients."""

    def __init__(self, *, mock: bool, demo: bool) -> None:
        self._mock = mock
        self._demo = demo
        self._clients: Set[WebSocketServerProtocol] = set()
        self._session_id = "demo"
        self._running = True

        self._mock_gen: Optional[MockGenerator] = None
        self._crown: Optional[CrownEngineLSL] = None

    async def start(self) -> None:
        if self._mock:
            self._mock_gen = MockGenerator(demo_mode=self._demo)
            logger.info("Mock engine ready (demo=%s)", self._demo)
        else:
            self._crown = CrownEngineLSL()
            try:
                self._crown.connect()
                logger.info("Crown engine ready (LSL)")
            except Exception as e:
                logger.error("")
                logger.error("=" * 60)
                logger.error("  CROWN NOT CONNECTED")
                logger.error("=" * 60)
                logger.error("")
                logger.error("  %s", e)
                logger.error("")
                logger.error("  Checklist:")
                logger.error("  1. Crown headset is ON (green LED)")
                logger.error("  2. Crown is on the SAME WiFi as this computer")
                logger.error("  3. LSL is ENABLED in Neurosity Developer Console")
                logger.error("     (Settings → Lab Streaming Layer → ON)")
                logger.error("")
                logger.error("  Or use: python daemon/attention_engine_lsl.py --mock")
                logger.error("=" * 60)
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
            logger.info("Client disconnected: %s (%d remaining)", remote, len(self._clients))

    async def _handle_command(self, ws: WebSocketServerProtocol, raw: str) -> None:
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
                    await ws.send(json.dumps({"status": "ok", "baseline": 1.0}))

            else:
                logger.warning("Unknown command: %s", action)

        except json.JSONDecodeError:
            logger.warning("Invalid JSON from client: %s", raw[:100])

    async def _broadcast_loop(self) -> None:
        tick = 0
        while self._running:
            state = self._compute()
            if state is None:
                await asyncio.sleep(1.0)
                continue
            tick += 1

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
    parser = ArgumentParser(description="GreyMatter EEG Daemon (LSL)")
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
