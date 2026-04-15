"""Sniff raw OSC packets from Crown to see what format it sends."""

from pythonosc.osc_server import BlockingOSCUDPServer
from pythonosc.dispatcher import Dispatcher

count = 0

def handler(addr, *args):
    global count
    count += 1
    if count <= 20:  # Print first 20 messages
        print(f"[{count}] addr={addr}")
        print(f"      args count={len(args)}, types={[type(a).__name__ for a in args[:8]]}")
        if len(args) <= 10:
            print(f"      values={args}")
        else:
            print(f"      first 5={args[:5]}")
            print(f"      last 3={args[-3:]}")
        print()
    elif count == 21:
        print("... (showing only first 20 messages)")

d = Dispatcher()
d.set_default_handler(handler)

print("Listening on UDP port 9000 for Crown OSC packets...")
print("Make sure daemon is STOPPED and OSC is ON in console")
print()

server = BlockingOSCUDPServer(("0.0.0.0", 9000), d)
server.serve_forever()
