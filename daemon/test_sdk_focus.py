#!/usr/bin/env python3
"""
Diagnostic: subscribe to Neurosity SDK focus() and print every raw callback.

Run for 30s, tally callback count and print payload shape. If focus is
"stuck" in the real daemon, this proves whether the SDK is receiving
fresh data from the Crown or not.

Usage:
    python daemon/test_sdk_focus.py
"""

from __future__ import annotations

import os
import time
from pathlib import Path

from dotenv import load_dotenv
from neurosity import NeurositySDK


def main() -> None:
    env_path = Path(__file__).parent / ".env"
    load_dotenv(env_path)
    print(f"[env] loaded from {env_path}")

    email = os.getenv("NEUROSITY_EMAIL")
    password = os.getenv("NEUROSITY_PASSWORD")
    device_id = os.getenv("NEUROSITY_DEVICE_ID")

    print(f"[sdk] initializing (device_id={device_id[:8]}...)")
    sdk = NeurositySDK({"device_id": device_id})

    print(f"[sdk] logging in as {email}...")
    sdk.login({"email": email, "password": password})
    print("[sdk] logged in")

    # ── focus() ────────────────────────────────────────────────
    focus_count = [0]
    focus_samples: list[float] = []
    focus_first: list[dict] = []

    def on_focus(data: dict) -> None:
        focus_count[0] += 1
        if len(focus_first) < 3:
            focus_first.append(dict(data))
        prob = data.get("probability")
        if prob is not None:
            focus_samples.append(float(prob))

    print("[sdk] subscribing to focus()...")
    unsub_focus = sdk.focus(on_focus)

    # ── brainwaves_power_by_band() ─────────────────────────────
    band_count = [0]
    band_first: list[dict] = []

    def on_bands(data: dict) -> None:
        band_count[0] += 1
        if len(band_first) < 2:
            band_first.append(dict(data))

    print("[sdk] subscribing to brainwaves_power_by_band()...")
    unsub_bands = sdk.brainwaves_power_by_band(on_bands)

    # ── Run for 30s ────────────────────────────────────────────
    duration = 30
    print(f"[sdk] collecting for {duration}s — wear Crown and relax...\n")

    start = time.time()
    last_report = start
    while time.time() - start < duration:
        time.sleep(1.0)
        now = time.time()
        if now - last_report >= 5.0:
            elapsed = int(now - start)
            print(
                f"  [+{elapsed:2d}s]  focus_callbacks={focus_count[0]:4d}  "
                f"band_callbacks={band_count[0]:4d}"
            )
            last_report = now

    # ── Report ────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("RESULTS")
    print("=" * 60)
    print(f"focus() callbacks in {duration}s:  {focus_count[0]}")
    print(f"  rate: {focus_count[0] / duration:.2f} Hz")
    if focus_samples:
        print(f"  first value:  {focus_samples[0]:.4f}")
        print(f"  last value:   {focus_samples[-1]:.4f}")
        print(f"  min:  {min(focus_samples):.4f}")
        print(f"  max:  {max(focus_samples):.4f}")
        unique = len(set(round(v, 4) for v in focus_samples))
        print(f"  unique values: {unique} (out of {len(focus_samples)})")
    else:
        print("  NO SAMPLES RECEIVED")

    if focus_first:
        print("\nFirst focus() payload shape:")
        for key, val in focus_first[0].items():
            print(f"  {key!r}: {val!r} ({type(val).__name__})")

    print(f"\nbrainwaves_power_by_band() callbacks: {band_count[0]}")
    print(f"  rate: {band_count[0] / duration:.2f} Hz")
    if band_first:
        print("\nFirst brainwaves_power_by_band() payload shape:")
        for key, val in band_first[0].items():
            if isinstance(val, dict):
                print(f"  {key!r}: <dict with keys {list(val.keys())}>")
                for bk, bv in val.items():
                    preview = bv[:3] if isinstance(bv, list) else bv
                    print(f"    {bk!r}: {preview}... ({type(bv).__name__})")
            else:
                print(f"  {key!r}: {val!r} ({type(val).__name__})")

    print("=" * 60)
    print("\nDIAGNOSIS:")
    if focus_count[0] == 0:
        print("  X No focus callbacks at all — SDK subscription or auth is broken")
    elif focus_count[0] < 30:
        print(f"  X Only {focus_count[0]} callbacks in {duration}s (expected ~{duration * 4})")
        print("    Crown is not actively transmitting. Checklist:")
        print("      - Crown worn on head (skin contact with pogo pins)")
        print("      - Crown mobile app open and showing 'Connected'")
        print("      - Crown battery charged (check LED)")
    elif focus_samples and len(set(round(v, 4) for v in focus_samples)) == 1:
        print("  X All values identical — SDK is replaying a cached value")
        print("    (Same fix list as above — Crown not transmitting fresh data)")
    else:
        print("  OK SDK is receiving fresh, varying data")
        print("    Safe to run: python daemon/focus_engine_sdk.py")

    # Cleanup
    try:
        unsub_focus()
    except Exception:
        pass
    try:
        unsub_bands()
    except Exception:
        pass


if __name__ == "__main__":
    main()
