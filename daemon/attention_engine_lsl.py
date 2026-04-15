#!/usr/bin/env python3
"""
GreyMatter EEG Daemon (LSL Transport)

Connects to Neurosity Crown via LSL (Lab Streaming Layer), computes real-time
attention metrics, and broadcasts AttentionState JSON over WebSocket to Flutter app.

LSL uses TCP unicast — far more reliable than BrainFlow's OSC/UDP broadcast,
which suffered 22-65% packet loss on WiFi.

Signal processing pipeline:
    1. All 8 Crown channels captured via LSL ring buffer
    2. Bandpass filter (2-45 Hz) + 50/60 Hz notch removes drift & mains hum
    3. Welch PSD → 5 band powers (delta, theta, alpha, beta, gamma)
    4. Median across channels (robust to single noisy electrode)
    5. Focus score from beta/(alpha+theta) ratio — combined focus index
    6. Per-channel signal quality (RMS-based, 0-100%)
    7. Three focus ratios: theta/alpha, beta/theta, beta/(alpha+theta)

Prerequisites:
    - Enable LSL in Neurosity Developer Console (Settings → Lab Streaming Layer)
    - Crown on same WiFi as this computer
    - pip install pylsl scipy

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
from argparse import ArgumentParser
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from enum import Enum
from typing import Optional, Set

import numpy as np
import websockets
from websockets.server import WebSocketServerProtocol
from scipy.signal import butter, iirnotch, sosfiltfilt, tf2sos, welch

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("greymatter.daemon")

# ── Constants ────────────────────────────────────────────────────────────

WS_PORT = 8765
SAMPLING_RATE = 256  # Crown Hz
WINDOW_SAMPLES = SAMPLING_RATE * 4  # 4-second data window
WELCH_NPERSEG = SAMPLING_RATE * 2   # 2-second Welch segment (0.5 Hz resolution)
RING_BUFFER_S = 10  # seconds of data to keep in ring buffer

# EEG band definitions.
# Delta starts at 2.0 Hz (not 0.5 Hz) because sub-2 Hz on dry electrodes
# is dominated by cardiac pulsation, sweat drift, and motion artifacts.
BANDS: dict[str, tuple[float, float]] = {
    "delta": (2.0, 4.0),
    "theta": (4.0, 8.0),
    "alpha": (8.0, 12.0),
    "beta": (12.0, 30.0),
    "gamma": (30.0, 45.0),
}

# Crown 8-channel layout: CP3, C3, F5, PO3, PO4, F6, C4, CP4
CROWN_CHANNEL_LABELS = ["CP3", "C3", "F5", "PO3", "PO4", "F6", "C4", "CP4"]

# Preprocessing filter parameters
HIGHPASS_CUTOFF_HZ = 2.0
LOWPASS_CUTOFF_HZ = 45.0
MAINS_NOTCH_HZ = (50.0, 60.0)
MAINS_NOTCH_Q = 30.0

# Classification: thresholds are personalized during calibration.
# Defaults used only if calibration fails.
DEFAULT_FOCUSED_THRESHOLD = 1.0
DEFAULT_LOST_THRESHOLD = 0.5
HYSTERESIS_WINDOWS = 2

# Signal quality thresholds (RMS of filtered signal)
SQ_RMS_FLOOR = 1.0
SQ_RMS_GOOD_LOW = 5.0
SQ_RMS_GOOD_HIGH = 50.0
SQ_RMS_CEILING = 120.0
SQ_WINDOW_S = 2.0

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

    def to_json(self) -> str:
        return json.dumps(asdict(self))


# ── Signal Processing ───────────────────────────────────────────────────

def build_filter(fs: float) -> np.ndarray:
    """Build cascaded SOS filter: bandpass + 50/60 Hz notch."""
    bp_sos = butter(
        N=4, Wn=[HIGHPASS_CUTOFF_HZ, LOWPASS_CUTOFF_HZ],
        btype="bandpass", fs=fs, output="sos"
    )
    sections = [bp_sos]
    for notch_hz in MAINS_NOTCH_HZ:
        b, a = iirnotch(w0=notch_hz, Q=MAINS_NOTCH_Q, fs=fs)
        sections.append(tf2sos(b, a))
    return np.vstack(sections)


def apply_filter(sos: np.ndarray, data: np.ndarray) -> np.ndarray:
    """Apply the display filter to a (n_channels, n_samples) buffer."""
    return sosfiltfilt(sos, data, axis=-1)


def compute_band_powers(
    filtered: np.ndarray, fs: float, nperseg: int
) -> dict[str, float]:
    """Compute band powers using median across all channels.

    Median is robust to a single noisy channel dominating the result.
    """
    n_channels, n_samples = filtered.shape
    seg = min(nperseg, n_samples)
    if seg < 16:
        return {name: 0.0 for name in BANDS}

    freqs, psd = welch(filtered, fs=fs, nperseg=seg, axis=-1)

    powers: dict[str, float] = {}
    for name, (low, high) in BANDS.items():
        mask = (freqs >= low) & (freqs < high)
        if not mask.any():
            powers[name] = 0.0
            continue
        band_psd = psd[:, mask]
        band_freqs = freqs[mask]
        per_channel_power = np.trapezoid(band_psd, band_freqs, axis=-1)
        powers[name] = float(np.median(per_channel_power))
    return powers


def compute_signal_quality(filtered: np.ndarray, labels: list[str]) -> dict[str, float]:
    """Compute per-channel signal quality as 0-100% from filtered EEG.

    Uses a plateau curve calibrated to the Crown's actual signal levels.
    """
    qualities: dict[str, float] = {}
    for ch in range(filtered.shape[0]):
        rms = float(np.sqrt(np.mean(filtered[ch] ** 2)))
        if rms <= SQ_RMS_FLOOR:
            q = 0.0
        elif rms <= SQ_RMS_GOOD_LOW:
            q = 80.0 * (rms - SQ_RMS_FLOOR) / (SQ_RMS_GOOD_LOW - SQ_RMS_FLOOR)
        elif rms <= SQ_RMS_GOOD_HIGH:
            midpoint = (SQ_RMS_GOOD_LOW + SQ_RMS_GOOD_HIGH) / 2.0
            half_range = (SQ_RMS_GOOD_HIGH - SQ_RMS_GOOD_LOW) / 2.0
            dist_from_mid = abs(rms - midpoint) / half_range
            q = 80.0 + 20.0 * (1.0 - dist_from_mid)
        elif rms <= SQ_RMS_CEILING:
            q = 80.0 * (1.0 - (rms - SQ_RMS_GOOD_HIGH) / (SQ_RMS_CEILING - SQ_RMS_GOOD_HIGH))
        else:
            q = 0.0
        label = labels[ch] if ch < len(labels) else f"ch{ch}"
        qualities[label] = round(max(0.0, min(100.0, q)), 1)
    return qualities


def compute_ratios(band_powers: dict[str, float]) -> dict[str, float]:
    """Compute three focus-related band ratios."""
    theta = band_powers.get("theta", 0.0)
    alpha = band_powers.get("alpha", 0.0)
    beta = band_powers.get("beta", 0.0)
    eps = 1e-9
    return {
        "theta_alpha": round(theta / (alpha + eps), 4),
        "beta_theta": round(beta / (theta + eps), 4),
        "beta_alpha_theta": round(beta / (alpha + theta + eps), 4),
    }


# ── Mock Data Generator ─────────────────────────────────────────────────

class MockGenerator:
    """Generates realistic synthetic EEG attention data with all fields."""

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

        # Generate band powers correlated with focus
        delta = float(np.clip(0.15 + (1 - focus) * 0.2 + self._rng.normal(0, 0.02), 0.02, 1.0))
        theta = float(np.clip(0.3 + (1 - focus) * 0.4 + self._rng.normal(0, 0.03), 0.05, 1.0))
        alpha = float(np.clip(0.25 + (1 - focus) * 0.3 + self._rng.normal(0, 0.03), 0.05, 1.0))
        beta = float(np.clip(0.35 + focus * 0.35 + self._rng.normal(0, 0.03), 0.05, 1.0))
        gamma = float(np.clip(0.1 + focus * 0.2 + self._rng.normal(0, 0.02), 0.02, 1.0))

        # Compute ratios before normalizing
        eps = 1e-9
        theta_alpha = round(theta / (alpha + eps), 4)
        beta_theta = round(beta / (theta + eps), 4)
        beta_alpha_theta = round(beta / (alpha + theta + eps), 4)

        # Normalize to sum to 1
        total = delta + theta + alpha + beta + gamma
        delta, theta, alpha, beta, gamma = (
            delta / total, theta / total, alpha / total, beta / total, gamma / total
        )

        # Mock signal quality — all channels good with slight variation
        signal_quality = {
            label: round(float(np.clip(85 + self._rng.normal(0, 5), 60, 100)), 1)
            for label in CROWN_CHANNEL_LABELS
        }

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
            theta_alpha=theta_alpha,
            beta_theta=beta_theta,
            beta_alpha_theta=beta_alpha_theta,
            signal_quality=signal_quality,
        )


# ── LSL Producer Thread ─────────────────────────────────────────────────

class LSLProducer(threading.Thread):
    """Background thread: pulls EEG chunks from Crown via LSL and writes
    them into a shared ring buffer."""

    def __init__(self, inlet: object, ring_buffer: np.ndarray) -> None:
        super().__init__(daemon=True, name="LSLProducer")
        self.inlet = inlet
        self.ring_buffer = ring_buffer
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
                    chunk = np.array(samples).T
                    n_samples = chunk.shape[1]

                    with self.lock:
                        end_pos = self.write_pos + n_samples
                        if end_pos <= buf_len:
                            self.ring_buffer[:, self.write_pos:end_pos] = chunk
                        else:
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
                logger.error("LSL producer error: %s", exc)
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
        self._baseline_ratio: float = 1.0  # beta/(alpha+theta) baseline from calibration
        self._focused_threshold: float = DEFAULT_FOCUSED_THRESHOLD
        self._lost_threshold: float = DEFAULT_LOST_THRESHOLD
        self._recent_ratios: list[float] = []
        self._channel_count: int = 8
        self._channel_labels: list[str] = list(CROWN_CHANNEL_LABELS)
        self._filter_sos: Optional[np.ndarray] = None

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

        for i, s in enumerate(all_streams):
            logger.info(
                "  [%d] name='%s' type='%s' channels=%d rate=%.0f",
                i, s.name(), s.type(), s.channel_count(), s.nominal_srate()
            )

        eeg_streams = [s for s in all_streams if s.type().lower() == "eeg"]
        if not eeg_streams:
            raise RuntimeError("No EEG-type LSL stream found")

        info = eeg_streams[0]
        self._channel_count = info.channel_count()
        nominal_rate = info.nominal_srate() or SAMPLING_RATE

        logger.info("Selected stream: '%s' (%d channels @ %.0f Hz)",
                     info.name(), self._channel_count, nominal_rate)

        # Extract channel labels
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
                    self._channel_labels = labels
                    logger.info("Channel labels: %s", labels)
        except Exception:
            pass

        # Build preprocessing filter
        self._filter_sos = build_filter(nominal_rate)
        logger.info("Preprocessing filter: 2-45 Hz bandpass + 50/60 Hz notch")

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

        logger.info("Waiting for EEG data...")
        time.sleep(2)

        if self._producer.total_samples > 0:
            logger.info("Crown connected via LSL — receiving data (%d samples so far)",
                        self._producer.total_samples)
        else:
            logger.warning("Connected but no samples yet — Crown may need a moment")

    def calibrate(self, duration_sec: int = 30) -> float:
        """Run calibration: compute baseline beta/(alpha+theta) ratio."""
        if self._producer is None:
            raise RuntimeError("Crown not connected")

        logger.info("Calibrating for %ds — sit still and focus on screen...", duration_sec)

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

        # Compute beta/(alpha+theta) ratio for each 2-second window during calibration
        # to get mean and std dev for personalized thresholds.
        filtered = apply_filter(self._filter_sos, data)
        window = WELCH_NPERSEG  # 2-second chunks
        ratios: list[float] = []
        for start in range(0, data.shape[1] - window, window):
            chunk = filtered[:, start:start + window]
            bp = compute_band_powers(chunk, SAMPLING_RATE, window)
            theta = bp["theta"]
            alpha = bp["alpha"]
            beta = bp["beta"]
            ratio = beta / max(alpha + theta, 0.001)
            ratios.append(ratio)

        if not ratios:
            logger.warning("Could not compute calibration ratios, using defaults")
            return 1.0

        mean_ratio = float(np.mean(ratios))
        std_ratio = float(np.std(ratios))

        # Overall band powers for logging
        band_powers = compute_band_powers(filtered, SAMPLING_RATE, WELCH_NPERSEG)
        logger.info(
            "[CAL BANDS] δ=%.4f θ=%.4f α=%.4f β=%.4f γ=%.4f",
            band_powers["delta"], band_powers["theta"], band_powers["alpha"],
            band_powers["beta"], band_powers["gamma"]
        )

        # Set baseline and personalized thresholds
        self._baseline_ratio = mean_ratio
        self._focused_threshold = mean_ratio - 1.0 * std_ratio
        self._lost_threshold = mean_ratio - 2.0 * std_ratio

        logger.info(
            "Baseline β/(α+θ): mean=%.3f std=%.3f | "
            "Thresholds: focused=%.3f lost=%.3f (from %d windows)",
            mean_ratio, std_ratio,
            self._focused_threshold, self._lost_threshold, len(ratios)
        )
        return self._baseline_ratio

    def compute(self, session_id: str) -> Optional[AttentionState]:
        """Compute current AttentionState from live EEG using all 8 channels."""
        if self._producer is None:
            raise RuntimeError("Crown not connected")

        data = self._producer.get_current_data(WINDOW_SAMPLES)
        n_channels, n_samples = data.shape

        if n_samples == 0:
            logger.warning("[RAW] No samples in buffer — Crown not streaming")
            return None

        if n_samples < SAMPLING_RATE:
            logger.warning("[RAW] Not enough samples (%d < %d), waiting...", n_samples, SAMPLING_RATE)
            return None

        # Apply preprocessing filter
        filtered = apply_filter(self._filter_sos, data)

        # Band powers (median across all 8 channels)
        bp = compute_band_powers(filtered, SAMPLING_RATE, WELCH_NPERSEG)
        logger.info(
            "[BAND] δ=%.4f θ=%.4f α=%.4f β=%.4f γ=%.4f",
            bp["delta"], bp["theta"], bp["alpha"], bp["beta"], bp["gamma"]
        )

        # Normalize band powers to proportions (sum to 1)
        total = sum(bp.values())
        norm = {k: round(v / total, 4) if total > 0 else 0.0 for k, v in bp.items()}

        # Focus ratios
        ratios = compute_ratios(bp)

        # Classify using raw ratio against personalized thresholds
        current_ratio = ratios["beta_alpha_theta"]
        level = self._classify(current_ratio)

        # Map ratio to 0-1 focus score relative to personalized thresholds
        # At baseline mean → 0.75, at focused threshold → 0.5, at lost threshold → 0.0
        if current_ratio >= self._baseline_ratio:
            focus = float(np.clip(0.75 + 0.25 * (current_ratio - self._baseline_ratio) / max(self._baseline_ratio, 0.001), 0.75, 1.0))
        elif current_ratio >= self._lost_threshold:
            span = self._baseline_ratio - self._lost_threshold
            focus = float(np.clip(0.75 * (current_ratio - self._lost_threshold) / max(span, 0.001), 0.0, 0.75))
        else:
            focus = 0.0

        # Signal quality (use 2s window)
        sq_samples = int(SQ_WINDOW_S * SAMPLING_RATE)
        sq_data = self._producer.get_current_data(sq_samples)
        if sq_data.shape[1] >= SAMPLING_RATE:
            sq_filtered = apply_filter(self._filter_sos, sq_data)
            signal_quality = compute_signal_quality(sq_filtered, self._channel_labels)
        else:
            signal_quality = {label: 0.0 for label in self._channel_labels}

        return AttentionState(
            session_id=session_id,
            focus_score=round(focus, 3),
            delta=norm["delta"],
            theta=norm["theta"],
            alpha=norm["alpha"],
            beta=norm["beta"],
            gamma=norm["gamma"],
            level=level.value,
            timestamp=datetime.now(timezone.utc).timestamp(),
            theta_alpha=ratios["theta_alpha"],
            beta_theta=ratios["beta_theta"],
            beta_alpha_theta=ratios["beta_alpha_theta"],
            signal_quality=signal_quality,
        )

    def _classify(self, raw_ratio: float) -> AttentionLevel:
        """Classify attention using personalized thresholds with hysteresis.

        Thresholds are set during calibration:
          focused_threshold = mean - 1 std dev
          lost_threshold    = mean - 2 std dev
        """
        self._recent_ratios.append(raw_ratio)
        if len(self._recent_ratios) > HYSTERESIS_WINDOWS:
            self._recent_ratios.pop(0)

        if len(self._recent_ratios) < HYSTERESIS_WINDOWS:
            return AttentionLevel.focused

        avg = sum(self._recent_ratios) / len(self._recent_ratios)
        if avg >= self._focused_threshold:
            return AttentionLevel.focused
        elif avg >= self._lost_threshold:
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
                "%4d | %s%8s%s | focus=%.3f | "
                "δ=%.3f θ=%.3f α=%.3f β=%.3f γ=%.3f | "
                "β/(α+θ)=%.2f",
                tick, c, state.level, reset, state.focus_score,
                state.delta, state.theta, state.alpha, state.beta, state.gamma,
                state.beta_alpha_theta,
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
