#!/usr/bin/env python3
"""
Measure your personal focus range to find correct --lost-offset and
--focused-offset values for the SDK engine.

Three 60-second phases:
  1. RELAXED  — sit still, do nothing
  2. FOCUSED  — active mental effort (mental math)
  3. LOST     — close eyes, let mind wander

At the end, prints recommended CLI flags for focus_engine_sdk.py based
on YOUR actual measured range.

Usage:
    python daemon/measure_focus_range.py
"""

from __future__ import annotations

import os
import statistics
import time
from pathlib import Path

from dotenv import load_dotenv
from neurosity import NeurositySDK


PHASE_SECONDS = 60


def collect_phase(sdk, duration: int, title: str, instruction: str) -> list[float]:
    print()
    print("=" * 70)
    print(f"  {title}")
    print("=" * 70)
    print(f"  INSTRUCTION: {instruction}")
    print()
    for countdown in (5, 4, 3, 2, 1):
        print(f"  Starting in {countdown}...", end="\r")
        time.sleep(1)
    print("  GO!                        ")
    print()

    samples: list[float] = []

    def on_focus(data: dict) -> None:
        prob = data.get("probability")
        if prob is not None:
            samples.append(float(prob))

    unsubscribe = sdk.focus(on_focus)

    start = time.time()
    last_report = start
    while time.time() - start < duration:
        time.sleep(0.25)
        now = time.time()
        if now - last_report >= 5.0:
            elapsed = int(now - start)
            remaining = duration - elapsed
            latest = samples[-1] if samples else 0.0
            print(
                f"  [+{elapsed:2d}s]  remaining={remaining:2d}s  "
                f"samples={len(samples):3d}  latest={latest:.3f}"
            )
            last_report = now

    try:
        unsubscribe()
    except Exception:
        pass

    if not samples:
        print("  WARNING: no samples collected!")
    else:
        print(f"  Done. Collected {len(samples)} samples.")
    return samples


def stats(samples: list[float], label: str) -> dict:
    if not samples:
        return {"label": label, "n": 0}
    return {
        "label": label,
        "n": len(samples),
        "min": min(samples),
        "max": max(samples),
        "mean": statistics.mean(samples),
        "median": statistics.median(samples),
        "stdev": statistics.stdev(samples) if len(samples) > 1 else 0.0,
    }


def main() -> None:
    env_path = Path(__file__).parent / ".env"
    load_dotenv(env_path)

    print()
    print("=" * 70)
    print("  FOCUS RANGE CALIBRATION")
    print("=" * 70)
    print()
    print("  This runs three 60-second phases to find YOUR personal focus range.")
    print("  Wear the Crown throughout. Follow each instruction carefully.")
    print()
    print("  Total time: ~3.5 minutes")
    print()
    input("  Press ENTER to begin...")

    print()
    print("  Connecting to Neurosity cloud...")
    sdk = NeurositySDK({"device_id": os.getenv("NEUROSITY_DEVICE_ID")})
    sdk.login({
        "email": os.getenv("NEUROSITY_EMAIL"),
        "password": os.getenv("NEUROSITY_PASSWORD"),
    })
    print("  Connected.")

    # Phase 1 — RELAXED baseline
    relaxed_samples = collect_phase(
        sdk,
        PHASE_SECONDS,
        "PHASE 1 / 3  —  RELAXED",
        "Sit still. Breathe normally. Eyes open.\n"
        "               Do nothing special — no math, no zoning out.\n"
        "               Just be present and comfortable."
    )

    # Phase 2 — ACTIVE FOCUS
    focused_samples = collect_phase(
        sdk,
        PHASE_SECONDS,
        "PHASE 2 / 3  —  ACTIVE FOCUS",
        "Do continuous mental math for 60s:\n"
        "                 87 x 14 = ?\n"
        "                 Then 123 x 27 = ?\n"
        "                 Then 56 x 43 = ?\n"
        "               Keep going. Stay engaged, don't space out."
    )

    # Phase 3 — DISENGAGED / LOST
    lost_samples = collect_phase(
        sdk,
        PHASE_SECONDS,
        "PHASE 3 / 3  —  DISENGAGED",
        "Close your eyes. Let your mind wander completely.\n"
        "               Think about nothing specific. Don't focus on anything.\n"
        "               If thoughts drift, let them drift. Zone out."
    )

    # ── Report ─────────────────────────────────────────────────
    r = stats(relaxed_samples, "RELAXED")
    f = stats(focused_samples, "FOCUSED")
    l = stats(lost_samples, "LOST")

    print()
    print("=" * 70)
    print("  RESULTS")
    print("=" * 70)
    for s in (r, f, l):
        if s["n"] == 0:
            print(f"\n  {s['label']}: NO SAMPLES — test failed")
            continue
        print(f"\n  {s['label']}:")
        print(f"    samples:  {s['n']}")
        print(f"    range:    {s['min']:.3f}  –  {s['max']:.3f}")
        print(f"    mean:     {s['mean']:.3f}")
        print(f"    median:   {s['median']:.3f}")
        print(f"    stdev:    {s['stdev']:.3f}")

    if r["n"] == 0 or f["n"] == 0 or l["n"] == 0:
        print("\n  Cannot recommend offsets — some phases had no data.")
        return

    # ── Recommend offsets ──────────────────────────────────────
    resting = r["mean"]
    focused_delta = f["mean"] - resting
    lost_delta = resting - l["mean"]

    # Midpoint strategy: threshold halfway between resting and state mean.
    # That means offset = 50% of the observed delta.
    # Floor at 0.05 to avoid absurdly tight thresholds on noise.
    rec_focused = max(0.05, focused_delta * 0.5)
    rec_lost = max(0.05, lost_delta * 0.5)

    print()
    print("=" * 70)
    print("  RECOMMENDED OFFSETS")
    print("=" * 70)
    print()
    print(f"  Your resting mean:       {resting:.3f}")
    print(f"  Focused delta (+above):  {focused_delta:+.3f}")
    print(f"  Lost delta    (-below):  {lost_delta:+.3f}")
    print()

    warnings = []
    if focused_delta < 0.03:
        warnings.append(
            "Focused delta is tiny (<0.03). Try harder mental task next time."
        )
    if lost_delta < 0.03:
        warnings.append(
            "Lost delta is tiny (<0.03). Zone out more completely next time."
        )
    if focused_delta < 0 or lost_delta < 0:
        warnings.append(
            "Delta went the wrong direction — phase instructions may need "
            "to be re-done. Your FOCUSED value was lower than RELAXED, or "
            "your LOST value was higher. Unusual."
        )

    if warnings:
        print("  WARNINGS:")
        for w in warnings:
            print(f"    - {w}")
        print()

    print(f"  --lost-offset={rec_lost:.2f}")
    print(f"  --focused-offset={rec_focused:.2f}")
    print()
    print("  New thresholds will be:")
    print(f"    lost    < {resting - rec_lost:.3f}")
    print(f"    focused > {resting + rec_focused:.3f}")
    print()
    print("  Run the daemon with:")
    print(
        f"    python daemon/focus_engine_sdk.py "
        f"--lost-offset={rec_lost:.2f} --focused-offset={rec_focused:.2f}"
    )
    print()


if __name__ == "__main__":
    main()
