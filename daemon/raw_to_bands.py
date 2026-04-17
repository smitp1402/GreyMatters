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
import csv
import json
import logging
import os
import random
import sys
import threading
import time
from argparse import ArgumentParser
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Optional

import numpy as np
import websockets
from scipy.integrate import trapezoid
from scipy.signal import welch


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

# Standard clinical EEG band boundaries (Hz).
BAND_RANGES: dict[str, tuple[float, float]] = {
    "delta": (1.0, 4.0),
    "theta": (4.0, 8.0),
    "alpha": (8.0, 13.0),
    "beta":  (13.0, 30.0),
    "gamma": (30.0, 45.0),
}
BAND_NAMES: tuple[str, ...] = tuple(BAND_RANGES.keys())


# ── Immutable snapshot returned by the analyzer ──────────────────────────

@dataclass(frozen=True)
class BandSnapshot:
    """Band powers computed from one PSD window.

    - `absolute[band]` is the channel-averaged absolute power (μV²/Hz·Hz = μV²).
    - `relative[band]` is absolute[band] / sum(absolute.values()); sums to 1.0.
    - `per_channel[band][ch_label]` holds the raw per-channel absolute power.
    - `engagement_index` is Pope's β / (α + θ) (NASA adaptive-automation formula).
    - `theta_beta_ratio` is classic θ / β (Lubar/Monastra attention literature).
    """

    timestamp: float
    sample_count: int
    window_sec: float
    absolute: dict[str, float]
    relative: dict[str, float]
    engagement_index: float
    theta_beta_ratio: float
    per_channel: dict[str, dict[str, float]] = field(default_factory=dict)

    def to_json(self) -> str:
        return json.dumps(asdict(self))


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

    # DC-remove per channel — otherwise delta power dominates everything.
    centered = samples - samples.mean(axis=1, keepdims=True)

    # nperseg = 1 second window by default; cap at available samples.
    nperseg = int(min(n_samples, sample_rate))
    nperseg = max(64, nperseg)

    freqs, psd = welch(
        centered,
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
        absolute[band] = float(band_power.mean())

    total = sum(absolute.values())
    if total <= 0:
        relative = {b: 0.0 for b in BAND_NAMES}
    else:
        relative = {b: absolute[b] / total for b in BAND_NAMES}

    # Pope's engagement index. Guard against divide-by-zero when bands are
    # silent (e.g. first tick, flat input). Returns 0.0 then.
    alpha_theta = absolute["alpha"] + absolute["theta"]
    engagement = absolute["beta"] / alpha_theta if alpha_theta > 0 else 0.0
    theta_beta = (
        absolute["theta"] / absolute["beta"] if absolute["beta"] > 0 else 0.0
    )

    return BandSnapshot(
        timestamp=time.time(),
        sample_count=n_samples,
        window_sec=window_sec,
        absolute=absolute,
        relative=relative,
        engagement_index=engagement,
        theta_beta_ratio=theta_beta,
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
    parts.append(f"θ/β={snap.theta_beta_ratio:5.2f}")
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

def run(
    *,
    mock: bool,
    window_sec: float,
    print_interval_sec: float,
    sample_rate: float,
    duration_sec: Optional[float],
    csv_path: Optional[Path],
    ws_port: Optional[int],
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
    args = parser.parse_args()

    if args.window <= 0.25:
        logger.error("--window must be > 0.25s for useful PSD")
        sys.exit(2)
    if args.print_interval <= 0:
        logger.error("--print-interval must be positive")
        sys.exit(2)

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
    )
    sys.exit(code)


if __name__ == "__main__":
    main()
