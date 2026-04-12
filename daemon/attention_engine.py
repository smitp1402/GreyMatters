# daemon/attention_engine.py
"""
NeuroLearn EEG Daemon

Connects to Neurosity Crown via BrainFlow, computes real-time attention metrics,
and broadcasts AttentionState JSON over WebSocket to Flutter app.

Usage:
    python attention_engine.py              # Real Crown mode
    python attention_engine.py --mock       # Mock data for testing
"""

import asyncio
import json
import logging
import sys
from argparse import ArgumentParser
from datetime import datetime
from typing import Optional

import numpy as np
import websockets
from brainflow import BoardShim, BrainFlowInputParams, BoardIds
from scipy.signal import welch

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Crown board configuration
CROWN_BOARD = BoardIds.CROWN_BOARD
SAMPLING_RATE = 256  # Hz
WINDOW_SIZE_SEC = 4  # 4-second rolling window for PSD
EXPECTED_CHANNELS = 8  # Crown has 8 EEG channels

# Band frequency ranges (Hz)
BANDS = {
    'theta': (4, 8),
    'alpha': (8, 13),
    'beta': (13, 30),
    'gamma': (30, 45)
}

# Attention classification thresholds (multiples of baseline)
FOCUSED_THRESHOLD = 1.5
LOST_THRESHOLD = 2.2
HYSTERESIS_WINDOWS = 2  # Require 2 consecutive windows for state change

class AttentionEngine:
    """EEG attention monitoring and broadcasting engine."""

    def __init__(self, mock: bool = False, session_id: str = 'demo'):
        self.mock = mock
        self.session_id = session_id
        self.baseline_index = 1.0  # Will be calibrated
        self.board: Optional[BoardShim] = None
        self.websocket_server: Optional[websockets.WebSocketServerProtocol] = None

        # Rolling state for hysteresis
        self.recent_levels = []

        # Mock data state
        self.mock_time = 0.0
        self.mock_baseline_set = False

    async def start(self):
        """Initialize Crown connection and start WebSocket server."""
        try:
            if not self.mock:
                await self._init_crown()
            else:
                logger.info("Starting in MOCK mode - no Crown required")

            # Start WebSocket server on port 8765
            server = await websockets.serve(
                self._handle_websocket,
                "localhost",
                8765,
                ping_interval=None  # Disable ping-pong for simplicity
            )
            logger.info("WebSocket server started on ws://localhost:8765")

            # Start attention monitoring loop
            await self._monitor_attention()

        except KeyboardInterrupt:
            logger.info("Shutting down...")
        except Exception as e:
            logger.error(f"Fatal error: {e}")
        finally:
            await self._cleanup()

    async def _init_crown(self):
        """Initialize BrainFlow connection to Crown."""
        logger.info("Initializing Crown connection...")

        params = BrainFlowInputParams()
        # Crown connects via OSC/WebSocket - configure as needed
        # This may need adjustment based on Crown's actual connection method

        self.board = BoardShim(CROWN_BOARD, params)
        self.board.prepare_session()
        self.board.start_stream()

        logger.info("Crown connected and streaming")

    async def _monitor_attention(self):
        """Main monitoring loop - compute attention every second."""
        while True:
            try:
                attention_state = self._compute_attention_state()

                if self.websocket_server:
                    # Broadcast to connected Flutter app
                    message = json.dumps(attention_state.to_dict())
                    await self.websocket_server.send(message)
                    logger.debug(f"Broadcast: {attention_state}")

                await asyncio.sleep(1.0)  # 1 Hz updates

            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                await asyncio.sleep(1.0)

    def _compute_attention_state(self):
        """Compute current AttentionState from EEG data."""
        if self.mock:
            return self._compute_mock_attention()
        else:
            return self._compute_real_attention()

    def _compute_real_attention(self):
        """Compute attention from real Crown data."""
        # Get latest samples
        data = self.board.get_current_board_data(EXPECTED_CHANNELS * SAMPLING_RATE)  # Last second

        if data.shape[1] == 0:
            # No new data
            return AttentionState(
                session_id=self.session_id,
                focus_score=0.5,
                theta=0.5, alpha=0.5, beta=0.5, gamma=0.5,
                level=AttentionLevel.drifting,
                timestamp=datetime.now()
            )

        # Use frontal channels F5, F6 (channels 4, 5 in BrainFlow indexing)
        frontal_data = data[[4, 5], :]  # Shape: (2, n_samples)

        # Compute band powers using Welch PSD
        band_powers = {}
        for band_name, (low_freq, high_freq) in BANDS.items():
            # Average across frontal channels
            channel_powers = []
            for ch_idx in range(frontal_data.shape[0]):
                freqs, psd = welch(
                    frontal_data[ch_idx, :],
                    fs=SAMPLING_RATE,
                    nperseg=min(1024, frontal_data.shape[1])
                )
                # Integrate power in band
                band_mask = (freqs >= low_freq) & (freqs <= high_freq)
                power = np.sum(psd[band_mask])
                channel_powers.append(power)

            band_powers[band_name] = np.mean(channel_powers)

        # Normalize band powers (simple z-score relative to baseline)
        # In production, you'd track running statistics
        normalized = {}
        for band, power in band_powers.items():
            normalized[band] = min(1.0, power / 1000.0)  # Rough normalization

        # Compute attention index: (theta + alpha) / beta
        attention_index = (normalized['theta'] + normalized['alpha']) / max(normalized['beta'], 0.001)

        # Normalize against baseline
        normalized_index = attention_index / self.baseline_index

        # Classify with hysteresis
        level = self._classify_with_hysteresis(normalized_index)

        # Focus score: invert and clamp (higher index = lower focus)
        focus_score = max(0.0, 1.0 - (normalized_index - 1.0))

        return AttentionState(
            session_id=self.session_id,
            focus_score=focus_score,
            theta=normalized['theta'],
            alpha=normalized['alpha'],
            beta=normalized['beta'],
            gamma=normalized['gamma'],
            level=level,
            timestamp=datetime.now()
        )

    def _compute_mock_attention(self):
        """Generate realistic mock attention data for testing."""
        self.mock_time += 1.0

        # Create realistic attention cycles: focused -> drifting -> lost -> recovery
        cycle_time = self.mock_time % 300  # 5-minute cycles

        if cycle_time < 120:  # 2 min focused
            base_focus = 0.8 + 0.1 * np.sin(self.mock_time * 0.1)
            level = AttentionLevel.focused
        elif cycle_time < 150:  # 30s drifting
            base_focus = 0.5 + 0.2 * np.sin(self.mock_time * 0.5)
            level = AttentionLevel.drifting
        elif cycle_time < 180:  # 30s lost
            base_focus = 0.2 + 0.1 * np.sin(self.mock_time * 0.8)
            level = AttentionLevel.lost
        else:  # 2 min recovery
            base_focus = 0.6 + 0.3 * np.sin(self.mock_time * 0.15)
            level = AttentionLevel.focused

        # Add noise
        focus_score = np.clip(base_focus + np.random.normal(0, 0.05), 0.0, 1.0)

        # Mock band powers that correlate with focus
        theta = 0.3 + (1.0 - focus_score) * 0.4 + np.random.normal(0, 0.05)
        alpha = 0.2 + (1.0 - focus_score) * 0.3 + np.random.normal(0, 0.05)
        beta = 0.4 + focus_score * 0.3 + np.random.normal(0, 0.05)
        gamma = 0.1 + focus_score * 0.2 + np.random.normal(0, 0.05)

        # Normalize
        total = theta + alpha + beta + gamma
        theta /= total
        alpha /= total
        beta /= total
        gamma /= total

        return AttentionState(
            session_id=self.session_id,
            focus_score=focus_score,
            theta=theta,
            alpha=alpha,
            beta=beta,
            gamma=gamma,
            level=level,
            timestamp=datetime.now()
        )

    def _classify_with_hysteresis(self, normalized_index: float) -> AttentionLevel:
        """Classify attention level with hysteresis to prevent oscillation."""
        # Add current reading to recent history
        self.recent_levels.append(normalized_index)
        if len(self.recent_levels) > HYSTERESIS_WINDOWS:
            self.recent_levels.pop(0)

        # Require majority of recent windows to agree
        if len(self.recent_levels) < HYSTERESIS_WINDOWS:
            return AttentionLevel.focused  # Default during startup

        avg_recent = sum(self.recent_levels) / len(self.recent_levels)

        if avg_recent <= FOCUSED_THRESHOLD:
            return AttentionLevel.focused
        elif avg_recent <= LOST_THRESHOLD:
            return AttentionLevel.drifting
        else:
            return AttentionLevel.lost

    async def _handle_websocket(self, websocket, path):
        """Handle WebSocket connection from Flutter app."""
        logger.info("Flutter app connected")
        self.websocket_server = websocket

        try:
            # Keep connection alive - attention monitoring handles sending
            await websocket.wait_closed()
        except Exception as e:
            logger.error(f"WebSocket error: {e}")
        finally:
            logger.info("Flutter app disconnected")
            self.websocket_server = None

    async def _cleanup(self):
        """Clean up resources."""
        if self.board:
            self.board.stop_stream()
            self.board.release_session()
        if self.websocket_server:
            await self.websocket_server.close()

class AttentionState:
    """Attention state data structure."""

    def __init__(self, session_id, focus_score, theta, alpha, beta, gamma, level, timestamp):
        self.session_id = session_id
        self.focus_score = focus_score
        self.theta = theta
        self.alpha = alpha
        self.beta = beta
        self.gamma = gamma
        self.level = level
        self.timestamp = timestamp

    def to_dict(self):
        """Convert to JSON-serializable dict."""
        return {
            'session_id': self.session_id,
            'focus_score': self.focus_score,
            'theta': self.theta,
            'alpha': self.alpha,
            'beta': self.beta,
            'gamma': self.gamma,
            'level': self.level.name,
            'timestamp': self.timestamp.timestamp()
        }

    def __str__(self):
        return f"AttentionState(session={self.session_id}, focus={self.focus_score:.2f}, level={self.level.name})"

# Attention level enum
class AttentionLevel:
    focused = "focused"
    drifting = "drifting"
    lost = "lost"

async def main():
    parser = ArgumentParser(description="NeuroLearn EEG Daemon")
    parser.add_argument('--mock', action='store_true', help="Run in mock mode (no Crown required)")
    parser.add_argument('--session-id', default='demo', help="Session ID for this run")

    args = parser.parse_args()

    engine = AttentionEngine(mock=args.mock, session_id=args.session_id)
    await engine.start()

if __name__ == "__main__":
    asyncio.run(main())