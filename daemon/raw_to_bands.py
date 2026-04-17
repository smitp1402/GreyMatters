#!/usr/bin/env python3
"""
Raw EEG → Band Powers (standalone research tool).

Subscribes to the Neurosity SDK's brainwaves_raw() stream and computes
frequency-band powers from scratch using Welch's PSD method — instead of
relying on the SDK's pre-computed brainwaves_power_by_band() endpoint.

Pipeline:
    1. Neurosity SDK streams raw EEG epochs at ~16 Hz (16 samples/channel/epoch)
    2. Per-channel rolling buffer holds the most recent `window` seconds
    3. Every `print-interval` seconds, Welch's PSD is computed per channel
    4. Band powers integrated over standard EEG bands:
         delta 1-4 Hz, theta 4-8, alpha 8-13, beta 13-30, gamma 30-45
    5. Absolute + relative (% of total) powers printed per band

Why this script:
    - focus_engine_sdk.py uses the SDK's *pre-computed* band powers (cloud-side)
    - This script derives them *locally* from raw samples, giving full control
      over window length, overlap, and band definitions for research / sanity
      checks against the cloud engine

Prerequisites:
    - Crown powered on, logged in via Neurosity mobile app
    - daemon/.env: NEUROSITY_EMAIL, NEUROSITY_PASSWORD, NEUROSITY_DEVICE_ID
    - pip install -r daemon/requirements-sdk.txt
    - pip install -r daemon/requirements.txt   (for numpy + scipy)

Usage:
    python daemon/raw_to_bands.py                       # real Crown
    python daemon/raw_to_bands.py --mock                # synthetic data
    python daemon/raw_to_bands.py --window=4            # 4s PSD window
    python daemon/raw_to_bands.py --print-interval=1.0  # print every 1s
    python daemon/raw_to_bands.py --duration=60         # stop after 60s
    python daemon/raw_to_bands.py --csv=out/bands.csv   # append to CSV
"""

from __future__ import annotations

import asyncio
import collections
import csv
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
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import numpy as np
import websockets
from scipy.integrate import trapezoid
from scipy.signal import butter, filtfilt, iirnotch, welch


# ── Logging ──────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("greymatter.raw_to_bands")


# ── Constants ────────────────────────────────────────────────────────────

# Crown 8-channel 10-20 layout in SDK-emitted order.
CROWN_CHANNEL_LABELS: tuple[str, ...] = (
    "CP3", "C3", "F5", "PO3", "PO4", "F6", "C4", "CP4",
)

# Crown samples raw EEG at 256 Hz (confirmed in Neurosity docs).
DEFAULT_SAMPLE_RATE_HZ = 256.0

# WebSocket broadcast port. Kept OFF the production 8765 port used by the
# LSL/SDK focus engines so raw_to_bands can run side-by-side for A/B study.
DEFAULT_WS_PORT = 8766

# Drift detection defaults:
#   - threshold:         engagement index below which a tick counts as "below"
#   - consecutive secs:  below-threshold run must last this long to trigger
# Wall-clock seconds so tuning doesn't break when --print-interval changes.
DEFAULT_ENGAGEMENT_THRESHOLD = 0.5
DEFAULT_CONSECUTIVE_SECONDS = 10.0
# Visual history length (ticks) emitted to the dashboard for the strip view.
DEFAULT_HISTORY_TICKS = 30

# Personalized baseline defaults.
# Threshold formula: threshold = mean_engagement − std_multiplier × std_engagement
# Higher multiplier → looser threshold (less sensitive to drift).
# Lower multiplier → stricter threshold (fires on smaller dips).
DEFAULT_BASELINE_PATH = Path(__file__).parent / "baseline.json"
DEFAULT_BASELINE_STD_MULTIPLIER = 1.0
DEFAULT_CALIBRATION_SECONDS = 60.0
# Floor so a very flat baseline doesn't produce an impossibly low threshold.
BASELINE_THRESHOLD_FLOOR = 0.05

# EEG band boundaries (Hz), matching Science of Focus Detection spec:
#   - Delta is 2-4 Hz (not textbook 0.5-4) — sub-2 Hz on dry electrodes is
#     dominated by motion + sweat drift + cardiac pulsation, not brain.
#   - Gamma is 30-45 Hz (not textbook 30-80) — above 45 Hz on consumer EEG
#     is EMG-dominated; Neurosity also caps at 45 Hz on-device.
BAND_RANGES: dict[str, tuple[float, float]] = {
    "delta": (2.0, 4.0),
    "theta": (4.0, 8.0),
    "alpha": (8.0, 13.0),
    "beta":  (13.0, 30.0),
    "gamma": (30.0, 45.0),
}
BAND_NAMES: tuple[str, ...] = tuple(BAND_RANGES.keys())

# Signal-processing pipeline parameters (per Science of Focus Detection spec):
#   2-45 Hz Butterworth bandpass removes DC drift, cardiac, sweat, EMG and
#   line-noise harmonics. 50 Hz + 60 Hz notches strip both European and
#   North American mains hum.
BANDPASS_LOW_HZ = 2.0
BANDPASS_HIGH_HZ = 45.0
BANDPASS_ORDER = 4
NOTCH_FREQS_HZ: tuple[float, ...] = (50.0, 60.0)
NOTCH_Q = 30.0


# ── Immutable snapshot returned by the analyzer ──────────────────────────

@dataclass(frozen=True)
class DriftState:
    """Drift classification for a single tick.

    - `classification` is one of "focused" / "drifting" / "lost".
      · focused  = engagement ≥ threshold, no active trigger
      · drifting = below threshold, but not yet enough to trigger
      · lost     = trigger fired (5+ consecutive OR 10s sustained)
    - `trigger_reason` is "", "consecutive", or "sustained" — empty when
      not triggered. Frontend uses it to pick banner text.
    - `recent_engagement` is the last N engagement values (oldest→newest)
      so the dashboard can paint a rolling strip without tracking state.
    - `recent_below` is the parallel below/above flag list for the strip.
    """
    threshold: float
    below_threshold: bool
    consecutive_below: int
    rolling_avg_engagement: float
    rolling_below_count: int
    rolling_window_ticks: int
    drift_triggered: bool
    classification: str
    trigger_reason: str
    recent_engagement: list[float] = field(default_factory=list)
    recent_below: list[bool] = field(default_factory=list)


@dataclass(frozen=True)
class BandSnapshot:
    """Band powers computed from one PSD window.

    - `absolute[band]` is the median power across channels (μV²).
    - `relative[band]` is absolute[band] / sum(absolute.values()); sums to 1.0.
    - `per_channel[band][ch_label]` holds the raw per-channel absolute power.
    - `engagement_index` is β / (α + θ), the combined focus index (Pope 1995).
    - `theta_alpha_ratio` is θ / α — drift indicator (low = focused).
    - `beta_theta_ratio` is β / θ — engagement indicator (high = focused).
    - `drift` carries the rolling-window classification (see DriftState).
    """

    timestamp: float
    sample_count: int
    window_sec: float
    absolute: dict[str, float]
    relative: dict[str, float]
    engagement_index: float
    theta_alpha_ratio: float
    beta_theta_ratio: float
    per_channel: dict[str, dict[str, float]] = field(default_factory=dict)
    drift: Optional[DriftState] = None

    def to_json(self) -> str:
        return json.dumps(asdict(self))


# ── Personalized baseline ────────────────────────────────────────────────

@dataclass(frozen=True)
class Baseline:
    """Per-user focus baseline derived from a calibration session.

    `derived_threshold` is the value the DriftClassifier uses; the rest is
    metadata so we can diagnose / recompute / show provenance in the UI.
    """
    created_at: float
    created_at_iso: str
    duration_seconds: float
    tick_count: int
    sample_rate_hz: float
    window_sec: float
    print_interval_sec: float
    mean_engagement: float
    std_engagement: float
    min_engagement: float
    max_engagement: float
    std_multiplier: float
    derived_threshold: float


def compute_baseline(
    values: list[float],
    *,
    sample_rate_hz: float,
    window_sec: float,
    print_interval_sec: float,
    std_multiplier: float,
    duration_seconds: float,
) -> Baseline:
    """Mean − N × std, floored at BASELINE_THRESHOLD_FLOOR."""
    if len(values) < 2:
        raise ValueError(f"need ≥2 engagement values for baseline; got {len(values)}")

    mean = statistics.mean(values)
    stdev = statistics.pstdev(values)  # population, samples ARE the dataset
    raw_threshold = mean - std_multiplier * stdev
    derived = max(BASELINE_THRESHOLD_FLOOR, raw_threshold)

    now = time.time()
    return Baseline(
        created_at=now,
        created_at_iso=datetime.fromtimestamp(now, tz=timezone.utc).isoformat(),
        duration_seconds=duration_seconds,
        tick_count=len(values),
        sample_rate_hz=sample_rate_hz,
        window_sec=window_sec,
        print_interval_sec=print_interval_sec,
        mean_engagement=mean,
        std_engagement=stdev,
        min_engagement=min(values),
        max_engagement=max(values),
        std_multiplier=std_multiplier,
        derived_threshold=derived,
    )


def save_baseline(baseline: Baseline, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(asdict(baseline), indent=2), encoding="utf-8")


def load_baseline(path: Path) -> Optional[Baseline]:
    """Read baseline.json. Returns None if missing or malformed (never raises)."""
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return Baseline(**data)
    except (json.JSONDecodeError, TypeError, KeyError) as exc:
        logger.warning("Ignoring malformed baseline at %s: %s", path, exc)
        return None


# ── Filter design (cached by sample rate) ────────────────────────────────

_FILTER_CACHE: dict[float, dict[str, tuple[np.ndarray, np.ndarray]]] = {}


def _design_filters(sample_rate: float) -> dict[str, tuple[np.ndarray, np.ndarray]]:
    """Design (b, a) coefficients for bandpass + notches. Cached per fs.

    Returns {"bandpass": (b, a), "notch_50": (b, a), "notch_60": (b, a), ...}.
    Notch keys are "notch_<freq>".
    """
    cached = _FILTER_CACHE.get(sample_rate)
    if cached is not None:
        return cached

    nyquist = sample_rate / 2.0
    lo = BANDPASS_LOW_HZ / nyquist
    hi = BANDPASS_HIGH_HZ / nyquist
    b_bp, a_bp = butter(BANDPASS_ORDER, [lo, hi], btype="bandpass")

    filters: dict[str, tuple[np.ndarray, np.ndarray]] = {"bandpass": (b_bp, a_bp)}
    for freq in NOTCH_FREQS_HZ:
        if freq >= nyquist:
            continue  # notch above Nyquist is a no-op (and scipy errors out)
        b_n, a_n = iirnotch(freq, NOTCH_Q, fs=sample_rate)
        filters[f"notch_{int(freq)}"] = (b_n, a_n)

    _FILTER_CACHE[sample_rate] = filters
    return filters


def _apply_filters(samples: np.ndarray, sample_rate: float) -> np.ndarray:
    """Zero-phase bandpass + 50 Hz + 60 Hz notches. Input/output shape preserved.

    Uses scipy.filtfilt so the filter adds no phase lag (matters when the
    PSD window is only 2-4 seconds — group delay would eat real signal).
    """
    filters = _design_filters(sample_rate)
    out = samples
    b, a = filters["bandpass"]
    out = filtfilt(b, a, out, axis=1)
    for key, (b, a) in filters.items():
        if key == "bandpass":
            continue
        out = filtfilt(b, a, out, axis=1)
    return out


# ── Drift classifier (rolling-window focus state) ────────────────────────

class DriftClassifier:
    """Single-rule classifier: trigger fires when engagement stays below
    threshold for `consecutive_trigger_ticks` in a row. Any above-threshold
    tick resets the counter.

    Keeps a separate history deque (longer) for the UI strip, decoupled from
    the trigger rule itself.
    """

    def __init__(
        self,
        *,
        threshold: float,
        consecutive_trigger_ticks: int,
        history_ticks: int,
    ) -> None:
        if consecutive_trigger_ticks <= 0:
            raise ValueError("consecutive_trigger_ticks must be > 0")

        self._threshold = threshold
        self._consecutive_trigger_ticks = consecutive_trigger_ticks
        self._history: collections.deque[tuple[float, bool]] = collections.deque(
            maxlen=max(history_ticks, consecutive_trigger_ticks)
        )
        self._consecutive_below = 0

    def classify(self, engagement: float) -> DriftState:
        below = engagement < self._threshold
        self._history.append((engagement, below))

        if below:
            self._consecutive_below += 1
        else:
            self._consecutive_below = 0

        drift_triggered = self._consecutive_below >= self._consecutive_trigger_ticks

        # Rolling stats on the display history — informational only, NOT used
        # to decide triggers. Helps the dashboard show "how the window looks".
        below_count = sum(1 for _, b in self._history if b)
        avg_engagement = (
            sum(e for e, _ in self._history) / len(self._history)
            if self._history
            else 0.0
        )

        if drift_triggered:
            classification = "lost"
            trigger_reason = "consecutive"
        elif below:
            classification = "drifting"
            trigger_reason = ""
        else:
            classification = "focused"
            trigger_reason = ""

        return DriftState(
            threshold=self._threshold,
            below_threshold=below,
            consecutive_below=self._consecutive_below,
            rolling_avg_engagement=avg_engagement,
            rolling_below_count=below_count,
            rolling_window_ticks=len(self._history),
            drift_triggered=drift_triggered,
            classification=classification,
            trigger_reason=trigger_reason,
            recent_engagement=[round(e, 3) for e, _ in self._history],
            recent_below=[b for _, b in self._history],
        )


# ── Rolling buffer (per-channel) ─────────────────────────────────────────

class RollingBuffer:
    """Fixed-size ring buffer per channel. Oldest samples drop off.

    numpy-backed rather than collections.deque so the math is vectorised:
    Welch's method is happier with contiguous float arrays.
    """

    def __init__(self, *, n_channels: int, capacity: int) -> None:
        if capacity <= 0:
            raise ValueError("capacity must be > 0")
        if n_channels <= 0:
            raise ValueError("n_channels must be > 0")
        self._capacity = capacity
        self._n_channels = n_channels
        # Shape (channels, capacity). Filled from the right.
        self._buf = np.zeros((n_channels, capacity), dtype=np.float64)
        self._filled = 0
        self._lock = threading.Lock()

    def extend(self, block: np.ndarray) -> None:
        """Append a (n_channels, n_samples) block. n_samples can be anything."""
        if block.ndim != 2 or block.shape[0] != self._n_channels:
            logger.warning(
                "Ignoring malformed block: shape=%s (expected (%d, N))",
                block.shape, self._n_channels,
            )
            return

        n = block.shape[1]
        if n == 0:
            return

        with self._lock:
            if n >= self._capacity:
                # Block is bigger than the buffer — keep only the newest tail.
                self._buf[:] = block[:, -self._capacity:]
                self._filled = self._capacity
            else:
                # Shift left by n, then write block into the tail.
                self._buf[:, :-n] = self._buf[:, n:]
                self._buf[:, -n:] = block
                self._filled = min(self._capacity, self._filled + n)

    def snapshot(self) -> Optional[np.ndarray]:
        """Return a copy of the current buffer, or None until we have enough data."""
        with self._lock:
            if self._filled < self._capacity:
                return None
            return self._buf.copy()


# ── Band computation ─────────────────────────────────────────────────────

def compute_bands(
    samples: np.ndarray,
    *,
    sample_rate: float,
    channel_labels: tuple[str, ...],
    window_sec: float,
) -> BandSnapshot:
    """Compute band powers via Welch's PSD.

    samples shape: (n_channels, n_samples).
    """
    n_channels, n_samples = samples.shape
    if n_channels != len(channel_labels):
        raise ValueError(
            f"Channel count mismatch: samples has {n_channels}, "
            f"labels has {len(channel_labels)}"
        )

    # 2-45 Hz bandpass + 50/60 Hz notches. The 2 Hz high-pass also kills DC,
    # so no separate mean-subtract step is needed.
    filtered = _apply_filters(samples, sample_rate)

    # nperseg = 1 second window by default; cap at available samples.
    nperseg = int(min(n_samples, sample_rate))
    nperseg = max(64, nperseg)

    freqs, psd = welch(
        filtered,
        fs=sample_rate,
        nperseg=nperseg,
        noverlap=nperseg // 2,
        axis=1,
        detrend="constant",
    )

    per_channel: dict[str, dict[str, float]] = {b: {} for b in BAND_NAMES}
    absolute: dict[str, float] = {}

    for band, (lo, hi) in BAND_RANGES.items():
        mask = (freqs >= lo) & (freqs < hi)
        if not mask.any():
            band_power = np.zeros(n_channels)
        else:
            # Trapezoidal integration of PSD over the band → power in μV².
            band_power = trapezoid(psd[:, mask], freqs[mask], axis=1)

        for ch_idx, ch_label in enumerate(channel_labels):
            per_channel[band][ch_label] = float(band_power[ch_idx])
        # Median across channels — robust to one bad electrode (per spec).
        absolute[band] = float(np.median(band_power))

    total = sum(absolute.values())
    if total <= 0:
        relative = {b: 0.0 for b in BAND_NAMES}
    else:
        relative = {b: absolute[b] / total for b in BAND_NAMES}

    # Focus ratios — all guarded against /0 in silent edge cases.
    alpha = absolute["alpha"]
    beta  = absolute["beta"]
    theta = absolute["theta"]
    engagement  = beta / (alpha + theta) if (alpha + theta) > 0 else 0.0
    theta_alpha = theta / alpha if alpha > 0 else 0.0
    beta_theta  = beta  / theta if theta > 0 else 0.0

    return BandSnapshot(
        timestamp=time.time(),
        sample_count=n_samples,
        window_sec=window_sec,
        absolute=absolute,
        relative=relative,
        engagement_index=engagement,
        theta_alpha_ratio=theta_alpha,
        beta_theta_ratio=beta_theta,
        per_channel=per_channel,
    )


# ── Real SDK source ──────────────────────────────────────────────────────

class SDKRawSource:
    """Subscribes to Neurosity brainwaves_raw() and pushes blocks into a buffer."""

    def __init__(self, buffer: RollingBuffer) -> None:
        self._buffer = buffer
        self._sdk: Optional[object] = None
        self._unsubscribe: Optional[object] = None
        self._samples_received = 0
        self._first_sample_wallclock: float = 0.0

    def connect(self) -> None:
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
            logger.warning("No .env at %s — using OS environment", env_path)

        email = os.getenv("NEUROSITY_EMAIL")
        password = os.getenv("NEUROSITY_PASSWORD")
        device_id = os.getenv("NEUROSITY_DEVICE_ID")

        missing = [
            n for n, v in (
                ("NEUROSITY_EMAIL", email),
                ("NEUROSITY_PASSWORD", password),
                ("NEUROSITY_DEVICE_ID", device_id),
            ) if not v
        ]
        if missing:
            raise RuntimeError(
                f"Missing credential(s): {', '.join(missing)}"
            )

        logger.info("Initializing Neurosity SDK (device=%s...)", device_id[:8])
        self._sdk = NeurositySDK({"device_id": device_id})

        logger.info("Logging in as %s...", email)
        self._sdk.login({"email": email, "password": password})

        logger.info("Subscribing to brainwaves_raw()...")
        self._unsubscribe = self._sdk.brainwaves_raw(self._on_raw)
        logger.info("Raw stream active. Collecting samples...")

    def disconnect(self) -> None:
        if self._unsubscribe is not None:
            try:
                self._unsubscribe()
            except Exception as exc:
                logger.debug("Unsubscribe error (ignored): %s", exc)
            self._unsubscribe = None

    def _on_raw(self, data: dict) -> None:
        # SDK payload shape (raw):
        #   {"data": [[ch0 samples], [ch1 samples], ..., [ch7 samples]],
        #    "info": {"samplingRate": 256, ...}}
        try:
            payload = data.get("data", data)
            if not isinstance(payload, list) or len(payload) == 0:
                return
            block = np.asarray(payload, dtype=np.float64)
        except (TypeError, ValueError) as exc:
            logger.debug("Malformed raw payload ignored: %s", exc)
            return

        if block.ndim != 2:
            return

        self._buffer.extend(block)
        self._samples_received += block.shape[1]
        if self._first_sample_wallclock == 0.0:
            self._first_sample_wallclock = time.time()


# ── Mock source (offline) ────────────────────────────────────────────────

class MockRawSource:
    """Synthesizes 8-channel EEG with realistic-ish band content.

    Not a medical model — just enough structure that Welch decomposes into
    non-trivial bands: 1/f background, alpha peak at 10 Hz, beta at 20 Hz.
    """

    def __init__(
        self,
        buffer: RollingBuffer,
        *,
        sample_rate: float,
        block_size: int = 16,
        block_hz: float = 16.0,
    ) -> None:
        self._buffer = buffer
        self._sample_rate = sample_rate
        self._block_size = block_size
        self._interval = 1.0 / block_hz
        self._rng = random.Random(42)
        self._np_rng = np.random.default_rng(42)
        self._t = 0.0
        self._thread: Optional[threading.Thread] = None
        self._stop = threading.Event()

    def connect(self) -> None:
        logger.info(
            "Mock raw source started (fs=%.0f Hz, block=%d, rate=%.0f Hz)",
            self._sample_rate, self._block_size, 1.0 / self._interval,
        )
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def disconnect(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=1.0)

    def _loop(self) -> None:
        n_channels = len(CROWN_CHANNEL_LABELS)
        dt = 1.0 / self._sample_rate
        while not self._stop.is_set():
            t0 = self._t
            ts = t0 + np.arange(self._block_size) * dt
            # Base: 1/f pink-ish noise shaped via random walk.
            base = self._np_rng.standard_normal((n_channels, self._block_size)) * 5.0
            # Alpha rhythm (~10 Hz) — louder on PO3/PO4 (visual cortex).
            alpha = 12.0 * np.sin(2 * np.pi * 10.0 * ts)
            alpha_weights = np.array([0.3, 0.4, 0.2, 1.0, 1.0, 0.2, 0.4, 0.3])
            # Beta (~20 Hz) — louder on frontal/central channels.
            beta = 6.0 * np.sin(2 * np.pi * 20.0 * ts)
            beta_weights = np.array([0.6, 0.8, 1.0, 0.2, 0.2, 1.0, 0.8, 0.6])

            block = (
                base
                + alpha_weights[:, None] * alpha[None, :]
                + beta_weights[:, None] * beta[None, :]
            )
            self._buffer.extend(block)

            self._t += self._block_size * dt
            self._stop.wait(self._interval)


# ── Printing / CSV output ────────────────────────────────────────────────

def format_snapshot(snap: BandSnapshot) -> str:
    parts = [f"samples={snap.sample_count}"]
    for band in BAND_NAMES:
        abs_p = snap.absolute[band]
        rel_p = snap.relative[band] * 100.0
        parts.append(f"{band}={abs_p:8.2f} ({rel_p:4.1f}%)")
    parts.append(f"engage={snap.engagement_index:5.2f}")
    parts.append(f"θ/α={snap.theta_alpha_ratio:5.2f}")
    parts.append(f"β/θ={snap.beta_theta_ratio:5.2f}")
    if snap.drift is not None:
        d = snap.drift
        label = d.classification.upper()
        if d.drift_triggered:
            label = f"*** {label} *** ({d.trigger_reason})"
        parts.append(
            f"[{label}  cons={d.consecutive_below}  "
            f"below={d.rolling_below_count}/{d.rolling_window_ticks}]"
        )
    return "  ".join(parts)


class CSVWriter:
    """Appends one row per snapshot. Header written if the file is new."""

    def __init__(self, path: Path) -> None:
        self._path = path
        self._fh = None
        self._writer = None

    def open(self) -> None:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        is_new = not self._path.exists()
        self._fh = self._path.open("a", newline="", encoding="utf-8")
        self._writer = csv.writer(self._fh)
        if is_new:
            header = ["timestamp", "samples"]
            for band in BAND_NAMES:
                header.append(f"{band}_abs")
                header.append(f"{band}_rel")
            for band in BAND_NAMES:
                for ch in CROWN_CHANNEL_LABELS:
                    header.append(f"{band}_{ch}")
            self._writer.writerow(header)
            self._fh.flush()

    def write(self, snap: BandSnapshot) -> None:
        if self._writer is None:
            return
        row: list[float | int | str] = [f"{snap.timestamp:.3f}", snap.sample_count]
        for band in BAND_NAMES:
            row.append(f"{snap.absolute[band]:.4f}")
            row.append(f"{snap.relative[band]:.4f}")
        for band in BAND_NAMES:
            for ch in CROWN_CHANNEL_LABELS:
                row.append(f"{snap.per_channel[band][ch]:.4f}")
        self._writer.writerow(row)
        self._fh.flush()

    def close(self) -> None:
        if self._fh is not None:
            self._fh.close()
            self._fh = None
            self._writer = None


# ── WebSocket broadcaster ────────────────────────────────────────────────

class WebSocketBroadcaster:
    """Runs websockets.serve() in a background thread + its own asyncio loop.

    Keeps the main synchronous time.sleep loop in run() untouched. The main
    thread calls broadcast(json_str) — non-blocking — and this class schedules
    the send on its owned loop via run_coroutine_threadsafe.
    """

    def __init__(self, port: int) -> None:
        self._port = port
        self._clients: set = set()
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._thread: Optional[threading.Thread] = None
        self._started = threading.Event()
        self._stop = threading.Event()

    def start(self) -> None:
        self._thread = threading.Thread(
            target=self._run_loop, name="ws-broadcast", daemon=True
        )
        self._thread.start()
        # Wait up to 3 s for the server to bind — surfaces port-in-use errors
        # to the caller instead of silently failing.
        if not self._started.wait(timeout=3.0):
            raise RuntimeError(
                f"WebSocket server failed to start on port {self._port} "
                f"within 3s (is the port in use?)"
            )
        logger.info("WebSocket broadcast on ws://localhost:%d", self._port)

    def stop(self) -> None:
        # Let _serve()'s `while not self._stop` loop exit naturally so
        # websockets.serve() can finish its async teardown. Don't force-stop
        # the loop — that leaves dangling coroutines raising on interpreter
        # shutdown.
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=2.0)

    def _run_loop(self) -> None:
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)
        try:
            self._loop.run_until_complete(self._serve())
        except Exception as exc:
            logger.error("WebSocket loop crashed: %s", exc)

    async def _serve(self) -> None:
        try:
            async with websockets.serve(
                self._on_connect, "localhost", self._port,
                ping_interval=20, ping_timeout=10,
            ):
                self._started.set()
                # Sleep forever until stop() is called.
                while not self._stop.is_set():
                    await asyncio.sleep(0.5)
        except OSError as exc:
            logger.error("WebSocket bind failed on port %d: %s", self._port, exc)
            # Leave _started UNset so start() raises for the caller.

    async def _on_connect(self, ws) -> None:
        self._clients.add(ws)
        remote = getattr(ws, "remote_address", "?")
        logger.info("Dashboard connected: %s (%d total)", remote, len(self._clients))
        try:
            async for _ in ws:
                # Dashboard is read-only — ignore any inbound messages.
                pass
        except websockets.ConnectionClosed:
            pass
        finally:
            self._clients.discard(ws)
            logger.info(
                "Dashboard disconnected: %s (%d remaining)",
                remote, len(self._clients),
            )

    def broadcast(self, message: str) -> None:
        """Thread-safe: schedules a fire-and-forget send on the ws loop."""
        if self._loop is None or not self._clients:
            return
        asyncio.run_coroutine_threadsafe(self._send_all(message), self._loop)

    async def _send_all(self, message: str) -> None:
        disconnected = []
        for client in list(self._clients):
            try:
                await client.send(message)
            except websockets.ConnectionClosed:
                disconnected.append(client)
            except Exception as exc:
                logger.debug("Broadcast error (dropping client): %s", exc)
                disconnected.append(client)
        for client in disconnected:
            self._clients.discard(client)


# ── Orchestrator ─────────────────────────────────────────────────────────

def run_calibration(
    *,
    mock: bool,
    window_sec: float,
    print_interval_sec: float,
    sample_rate: float,
    calibrate_seconds: float,
    std_multiplier: float,
    baseline_path: Path,
) -> int:
    """Run a single focused calibration pass, then write baseline.json and exit.

    No WebSocket broadcast, no CSV — just collects engagement values while
    the user focuses, then saves the derived threshold.
    """
    capacity = int(round(window_sec * sample_rate))
    buffer = RollingBuffer(n_channels=len(CROWN_CHANNEL_LABELS), capacity=capacity)
    source: SDKRawSource | MockRawSource = (
        MockRawSource(buffer, sample_rate=sample_rate) if mock else SDKRawSource(buffer)
    )

    try:
        source.connect()
    except Exception as exc:
        logger.error("Failed to start source: %s", exc)
        return 1

    try:
        logger.info("")
        logger.info("=" * 62)
        logger.info("  CALIBRATION — %d second focused recording", int(calibrate_seconds))
        logger.info("=" * 62)
        logger.info("")
        logger.info("  Do a FOCUSED task for %.0f seconds:", calibrate_seconds)
        logger.info("    • Mental math  (e.g. 47 × 13, then 82 × 19, ...)")
        logger.info("    • OR read dense technical text")
        logger.info("  Sit still, eyes open, stay engaged.")
        logger.info("")

        # Wait for the PSD buffer to fill before any countdown starts.
        while buffer.snapshot() is None:
            time.sleep(print_interval_sec)

        for n in (3, 2, 1):
            logger.info("  Starting in %d...", n)
            time.sleep(1.0)
        logger.info("  GO! Focus NOW.")
        logger.info("")

        values: list[float] = []
        start = time.time()
        tick = 0

        while True:
            elapsed = time.time() - start
            if elapsed >= calibrate_seconds:
                break
            time.sleep(print_interval_sec)

            samples = buffer.snapshot()
            if samples is None:
                continue

            snap = compute_bands(
                samples,
                sample_rate=sample_rate,
                channel_labels=CROWN_CHANNEL_LABELS,
                window_sec=window_sec,
            )
            values.append(snap.engagement_index)
            tick += 1

            # Log every tick — shows elapsed / remaining seconds clearly.
            remaining = max(0, calibrate_seconds - elapsed)
            running_mean = statistics.mean(values) if values else 0.0
            logger.info(
                "  %5.1fs elapsed / %5.1fs left  ·  tick=%3d  engage=%.2f  "
                "running mean=%.2f",
                elapsed, remaining, tick, snap.engagement_index, running_mean,
            )
    except KeyboardInterrupt:
        logger.info("Calibration cancelled by user.")
        source.disconnect()
        return 1
    finally:
        source.disconnect()

    if len(values) < 5:
        logger.error(
            "Too few engagement samples (%d) — calibration failed. "
            "Check Crown connection + signal quality.", len(values),
        )
        return 1

    baseline = compute_baseline(
        values,
        sample_rate_hz=sample_rate,
        window_sec=window_sec,
        print_interval_sec=print_interval_sec,
        std_multiplier=std_multiplier,
        duration_seconds=calibrate_seconds,
    )
    save_baseline(baseline, baseline_path)

    logger.info("")
    logger.info("=" * 62)
    logger.info("  BASELINE SAVED → %s", baseline_path)
    logger.info("=" * 62)
    logger.info("  ticks collected:   %d", baseline.tick_count)
    logger.info("  mean engagement:   %.3f", baseline.mean_engagement)
    logger.info("  std deviation:     %.3f", baseline.std_engagement)
    logger.info(
        "  range:             %.3f … %.3f",
        baseline.min_engagement, baseline.max_engagement,
    )
    logger.info(
        "  formula:           mean − %.1f × std",
        baseline.std_multiplier,
    )
    logger.info("  YOUR THRESHOLD:    %.3f", baseline.derived_threshold)
    logger.info("")
    logger.info("  Next normal run will auto-load this threshold.")
    logger.info("  Override any time with --drift-threshold=X or --no-baseline.")
    logger.info("")
    return 0


def run(
    *,
    mock: bool,
    window_sec: float,
    print_interval_sec: float,
    sample_rate: float,
    duration_sec: Optional[float],
    csv_path: Optional[Path],
    ws_port: Optional[int],
    drift_threshold: float,
    drift_consecutive_seconds: float,
    drift_history_ticks: int,
) -> int:
    capacity = int(round(window_sec * sample_rate))
    buffer = RollingBuffer(n_channels=len(CROWN_CHANNEL_LABELS), capacity=capacity)

    source: SDKRawSource | MockRawSource
    if mock:
        source = MockRawSource(buffer, sample_rate=sample_rate)
    else:
        source = SDKRawSource(buffer)

    try:
        source.connect()
    except Exception as exc:
        logger.error("Failed to start source: %s", exc)
        return 1

    csv_writer: Optional[CSVWriter] = None
    if csv_path is not None:
        csv_writer = CSVWriter(csv_path)
        csv_writer.open()
        logger.info("Writing CSV to %s", csv_path)

    # Convert seconds → ticks using the current print cadence. Ceil so a
    # fractional configuration still covers the requested wall-clock time.
    step = max(print_interval_sec, 1e-6)
    consecutive_trigger_ticks = max(1, int(math.ceil(drift_consecutive_seconds / step)))

    drift_classifier = DriftClassifier(
        threshold=drift_threshold,
        consecutive_trigger_ticks=consecutive_trigger_ticks,
        history_ticks=drift_history_ticks,
    )
    logger.info(
        "Drift rule: threshold=%.2f · consecutive %.1fs (%d ticks) below → trigger",
        drift_threshold, drift_consecutive_seconds, consecutive_trigger_ticks,
    )

    broadcaster: Optional[WebSocketBroadcaster] = None
    if ws_port is not None:
        broadcaster = WebSocketBroadcaster(ws_port)
        try:
            broadcaster.start()
        except Exception as exc:
            logger.error("Broadcaster failed: %s", exc)
            source.disconnect()
            if csv_writer is not None:
                csv_writer.close()
            return 1

    logger.info(
        "PSD window=%.1fs (%d samples), print every %.1fs",
        window_sec, capacity, print_interval_sec,
    )
    logger.info("Channels: %s", ", ".join(CROWN_CHANNEL_LABELS))

    start = time.time()
    tick = 0
    try:
        while True:
            if duration_sec is not None and (time.time() - start) >= duration_sec:
                logger.info("Duration reached (%.1fs) — stopping.", duration_sec)
                break

            time.sleep(print_interval_sec)

            samples = buffer.snapshot()
            if samples is None:
                logger.info("Waiting for buffer to fill...")
                continue

            snap = compute_bands(
                samples,
                sample_rate=sample_rate,
                channel_labels=CROWN_CHANNEL_LABELS,
                window_sec=window_sec,
            )
            drift_state = drift_classifier.classify(snap.engagement_index)
            # Re-pack the snapshot with drift state attached. BandSnapshot is
            # frozen so we use dataclasses.replace-style construction via dict.
            snap_with_drift = BandSnapshot(
                timestamp=snap.timestamp,
                sample_count=snap.sample_count,
                window_sec=snap.window_sec,
                absolute=snap.absolute,
                relative=snap.relative,
                engagement_index=snap.engagement_index,
                theta_alpha_ratio=snap.theta_alpha_ratio,
                beta_theta_ratio=snap.beta_theta_ratio,
                per_channel=snap.per_channel,
                drift=drift_state,
            )
            snap = snap_with_drift
            tick += 1
            logger.info("#%04d  %s", tick, format_snapshot(snap))
            if csv_writer is not None:
                csv_writer.write(snap)
            if broadcaster is not None:
                broadcaster.broadcast(snap.to_json())

    except KeyboardInterrupt:
        logger.info("Stopped by user.")
    finally:
        source.disconnect()
        if csv_writer is not None:
            csv_writer.close()
        if broadcaster is not None:
            broadcaster.stop()

    return 0


def main() -> None:
    parser = ArgumentParser(description="Raw EEG → band powers (Welch's PSD)")
    parser.add_argument(
        "--mock", action="store_true", help="Mock mode (no Crown required)"
    )
    parser.add_argument(
        "--window", type=float, default=2.0,
        help="PSD rolling window in seconds (default 2.0)",
    )
    parser.add_argument(
        "--print-interval", type=float, default=0.5,
        help="Seconds between band recomputes / log lines (default 0.5)",
    )
    parser.add_argument(
        "--sample-rate", type=float, default=DEFAULT_SAMPLE_RATE_HZ,
        help=f"EEG sample rate in Hz (default {DEFAULT_SAMPLE_RATE_HZ:.0f})",
    )
    parser.add_argument(
        "--duration", type=float, default=None,
        help="Stop after N seconds (default: run until Ctrl-C)",
    )
    parser.add_argument(
        "--csv", type=str, default=None,
        help="Append each band snapshot to this CSV file",
    )
    parser.add_argument(
        "--ws-port", type=int, default=DEFAULT_WS_PORT,
        help=(
            f"WebSocket port for dashboard broadcast "
            f"(default {DEFAULT_WS_PORT}; pass 0 to disable)"
        ),
    )
    # Default is None (sentinel) so we can distinguish "user explicitly set
    # a threshold" from "fall back to baseline or default". Explicit
    # --drift-threshold wins over any baseline.
    parser.add_argument(
        "--drift-threshold", type=float, default=None,
        help=(
            f"Engagement value below which a tick counts as 'below'. "
            f"When unset: loads from baseline if present, else "
            f"{DEFAULT_ENGAGEMENT_THRESHOLD}."
        ),
    )
    parser.add_argument(
        "--drift-consecutive-seconds", type=float, default=DEFAULT_CONSECUTIVE_SECONDS,
        help=(
            f"Consecutive below-threshold wall-clock seconds needed to "
            f"trigger drift (default {DEFAULT_CONSECUTIVE_SECONDS}). "
            f"Always interpreted as seconds — independent of --print-interval."
        ),
    )
    parser.add_argument(
        "--drift-history-ticks", type=int, default=DEFAULT_HISTORY_TICKS,
        help=(
            f"Number of recent engagement values to emit for the dashboard "
            f"strip view (default {DEFAULT_HISTORY_TICKS})"
        ),
    )
    # Personalized baseline flags
    parser.add_argument(
        "--calibrate-seconds", type=float, default=None,
        metavar="N",
        help=(
            f"Run a {int(DEFAULT_CALIBRATION_SECONDS)}-second (or N-second) "
            f"focused calibration, derive threshold from your own engagement, "
            f"save to --baseline-path, then exit."
        ),
    )
    parser.add_argument(
        "--baseline-path", type=str, default=str(DEFAULT_BASELINE_PATH),
        help=(
            f"Path to baseline.json (default {DEFAULT_BASELINE_PATH}). "
            f"Written by --calibrate-seconds, read on normal runs."
        ),
    )
    parser.add_argument(
        "--baseline-std-multiplier", type=float, default=DEFAULT_BASELINE_STD_MULTIPLIER,
        help=(
            f"threshold = mean − N × std. Lower N = stricter / fires sooner. "
            f"(default {DEFAULT_BASELINE_STD_MULTIPLIER})"
        ),
    )
    parser.add_argument(
        "--no-baseline", action="store_true",
        help="Ignore any existing baseline.json; use --drift-threshold or default.",
    )

    args = parser.parse_args()

    if args.window <= 0.25:
        logger.error("--window must be > 0.25s for useful PSD")
        sys.exit(2)
    if args.print_interval <= 0:
        logger.error("--print-interval must be positive")
        sys.exit(2)

    baseline_path = Path(args.baseline_path)

    # ── Calibration mode takes over and exits ────────────────────────
    if args.calibrate_seconds is not None:
        if args.calibrate_seconds < 10:
            logger.error("--calibrate-seconds must be ≥ 10 (need enough data)")
            sys.exit(2)
        code = run_calibration(
            mock=args.mock,
            window_sec=args.window,
            print_interval_sec=args.print_interval,
            sample_rate=args.sample_rate,
            calibrate_seconds=args.calibrate_seconds,
            std_multiplier=args.baseline_std_multiplier,
            baseline_path=baseline_path,
        )
        sys.exit(code)

    # ── Resolve effective threshold: explicit > baseline > default ───
    loaded_baseline: Optional[Baseline] = None
    if args.drift_threshold is not None:
        effective_threshold = args.drift_threshold
        threshold_source = f"CLI override (--drift-threshold={args.drift_threshold})"
    elif args.no_baseline:
        effective_threshold = DEFAULT_ENGAGEMENT_THRESHOLD
        threshold_source = f"default ({DEFAULT_ENGAGEMENT_THRESHOLD}), --no-baseline"
    else:
        loaded_baseline = load_baseline(baseline_path)
        if loaded_baseline is not None:
            effective_threshold = loaded_baseline.derived_threshold
            age_days = (time.time() - loaded_baseline.created_at) / 86400.0
            threshold_source = (
                f"baseline {baseline_path} "
                f"(mean={loaded_baseline.mean_engagement:.3f}, "
                f"std={loaded_baseline.std_engagement:.3f}, "
                f"{age_days:.1f} days old)"
            )
        else:
            effective_threshold = DEFAULT_ENGAGEMENT_THRESHOLD
            threshold_source = (
                f"default ({DEFAULT_ENGAGEMENT_THRESHOLD}) — no baseline at "
                f"{baseline_path}. Run --calibrate-seconds={int(DEFAULT_CALIBRATION_SECONDS)} "
                f"to personalize."
            )

    logger.info("Threshold source: %s", threshold_source)

    csv_path = Path(args.csv) if args.csv else None
    ws_port: Optional[int] = args.ws_port if args.ws_port and args.ws_port > 0 else None

    code = run(
        mock=args.mock,
        window_sec=args.window,
        print_interval_sec=args.print_interval,
        sample_rate=args.sample_rate,
        duration_sec=args.duration,
        csv_path=csv_path,
        ws_port=ws_port,
        drift_threshold=effective_threshold,
        drift_consecutive_seconds=args.drift_consecutive_seconds,
        drift_history_ticks=args.drift_history_ticks,
    )
    sys.exit(code)


if __name__ == "__main__":
    main()
