"""Quick test — connect to daemon WebSocket and print raw data."""
import asyncio
import json
import websockets

async def main():
    print("Connecting to ws://localhost:8765 ...")
    async with websockets.connect("ws://localhost:8765") as ws:
        print("Connected! Listening for data...\n")
        i = 0
        while True:
            i += 1
            raw = await ws.recv()
            m = json.loads(raw)
            print(f"{i:4d} | {m['level']:8s} | focus={m['focus_score']:.3f} | theta={m['theta']:.4f} | alpha={m['alpha']:.4f} | beta={m['beta']:.4f} | gamma={m['gamma']:.4f}")

if __name__ == "__main__":
    asyncio.run(main())
