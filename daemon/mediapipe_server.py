#!/usr/bin/env python3
"""
NeuroLearn MediaPipe Hand Tracking Server

Captures webcam, runs MediaPipe hand landmark detection, and broadcasts
hand data over WebSocket on port 8766 to the Flutter gesture intervention.

Usage:
    python mediapipe_server.py
    python mediapipe_server.py --mock   # Synthetic hand data (no camera)
"""

from __future__ import annotations

import asyncio
import json
import logging
import math
from argparse import ArgumentParser
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from typing import Optional, Set

import numpy as np
import websockets
from websockets.server import WebSocketServerProtocol

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("neurolearn.mediapipe")

WS_PORT = 8766


@dataclass(frozen=True)
class HandState:
    detected: bool
    finger_count: int
    pointing_direction: str  # "left", "right", "up", "down", "none"
    confidence: float
    timestamp: float

    def to_json(self) -> str:
        return json.dumps(asdict(self))


class HandTracker:
    """Real MediaPipe hand tracking from webcam."""

    def __init__(self) -> None:
        self._cap = None
        self._hands = None

    def start(self) -> None:
        import cv2
        import mediapipe as mp

        self._cap = cv2.VideoCapture(0)
        if not self._cap.isOpened():
            raise RuntimeError("Cannot open camera")

        self._hands = mp.solutions.hands.Hands(
            static_image_mode=False,
            max_num_hands=1,
            min_detection_confidence=0.7,
            min_tracking_confidence=0.5,
        )
        logger.info("Camera and MediaPipe initialized")

    def detect(self) -> HandState:
        import cv2

        if self._cap is None or self._hands is None:
            return HandState(
                detected=False, finger_count=0,
                pointing_direction="none", confidence=0.0,
                timestamp=datetime.now(timezone.utc).timestamp(),
            )

        ret, frame = self._cap.read()
        if not ret:
            return HandState(
                detected=False, finger_count=0,
                pointing_direction="none", confidence=0.0,
                timestamp=datetime.now(timezone.utc).timestamp(),
            )

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self._hands.process(rgb)

        if not results.multi_hand_landmarks:
            return HandState(
                detected=False, finger_count=0,
                pointing_direction="none", confidence=0.0,
                timestamp=datetime.now(timezone.utc).timestamp(),
            )

        hand = results.multi_hand_landmarks[0]
        landmarks = hand.landmark

        finger_count = self._count_fingers(landmarks)
        direction = self._detect_pointing(landmarks)

        return HandState(
            detected=True,
            finger_count=finger_count,
            pointing_direction=direction,
            confidence=0.9,
            timestamp=datetime.now(timezone.utc).timestamp(),
        )

    def _count_fingers(self, landmarks: list) -> int:
        """Count raised fingers using landmark positions."""
        tips = [8, 12, 16, 20]  # Index, middle, ring, pinky tips
        pips = [6, 10, 14, 18]  # Corresponding PIP joints

        count = 0
        for tip_id, pip_id in zip(tips, pips):
            if landmarks[tip_id].y < landmarks[pip_id].y:
                count += 1

        # Thumb: compare x position (different axis)
        if landmarks[4].x < landmarks[3].x:
            count += 1

        return count

    def _detect_pointing(self, landmarks: list) -> str:
        """Detect pointing direction from index finger."""
        tip = landmarks[8]   # Index tip
        mcp = landmarks[5]   # Index MCP

        dx = tip.x - mcp.x
        dy = tip.y - mcp.y

        if abs(dx) > abs(dy):
            return "left" if dx < 0 else "right"
        return "up" if dy < 0 else "down"

    def stop(self) -> None:
        if self._cap is not None:
            self._cap.release()
        self._cap = None
        self._hands = None


class MockHandTracker:
    """Generates synthetic hand data for testing without a camera."""

    def __init__(self) -> None:
        self._tick = 0
        self._rng = np.random.default_rng(99)

    def detect(self) -> HandState:
        self._tick += 1

        # Cycle through finger counts every 5 seconds
        cycle = (self._tick // 5) % 6
        detected = cycle > 0

        return HandState(
            detected=detected,
            finger_count=cycle if detected else 0,
            pointing_direction=["none", "up", "right", "down", "left", "up"][cycle],
            confidence=0.85 + self._rng.random() * 0.1 if detected else 0.0,
            timestamp=datetime.now(timezone.utc).timestamp(),
        )


class MediaPipeServer:
    """WebSocket server broadcasting hand tracking data."""

    def __init__(self, *, mock: bool = False) -> None:
        self._mock = mock
        self._clients: Set[WebSocketServerProtocol] = set()
        self._tracker: Optional[HandTracker | MockHandTracker] = None
        self._running = True

    async def start(self) -> None:
        if self._mock:
            self._tracker = MockHandTracker()
            logger.info("Mock hand tracker ready")
        else:
            tracker = HandTracker()
            tracker.start()
            self._tracker = tracker
            logger.info("Real hand tracker ready")

        async with websockets.serve(
            self._on_connect,
            "localhost",
            WS_PORT,
            ping_interval=20,
            ping_timeout=10,
        ):
            logger.info("MediaPipe server on ws://localhost:%d", WS_PORT)
            await self._broadcast_loop()

    async def _on_connect(self, ws: WebSocketServerProtocol) -> None:
        self._clients.add(ws)
        logger.info("Client connected (%d total)", len(self._clients))
        try:
            await ws.wait_closed()
        finally:
            self._clients.discard(ws)

    async def _broadcast_loop(self) -> None:
        while self._running:
            if self._tracker is None:
                await asyncio.sleep(0.1)
                continue

            state = self._tracker.detect()

            if self._clients:
                payload = state.to_json()
                disconnected = []
                for client in self._clients.copy():
                    try:
                        await client.send(payload)
                    except websockets.ConnectionClosed:
                        disconnected.append(client)
                for c in disconnected:
                    self._clients.discard(c)

            # 10 Hz for smoother hand tracking
            await asyncio.sleep(0.1)


def main() -> None:
    parser = ArgumentParser(description="NeuroLearn MediaPipe Server")
    parser.add_argument("--mock", action="store_true", help="Mock mode (no camera)")
    args = parser.parse_args()

    server = MediaPipeServer(mock=args.mock)
    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        logger.info("MediaPipe server stopped")


if __name__ == "__main__":
    main()
