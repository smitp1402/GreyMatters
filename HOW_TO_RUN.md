# NeuroLearn — How to Run Locally

## Prerequisites

- **Flutter SDK** at `C:\flutter\flutter\bin`
- **Python 3.13** at `C:\Users\Smit\AppData\Local\Programs\Python\Python313`
- **Neurosity Crown** (optional — mock mode available)
- **NuGet** at `C:\Users\Smit\nuget.exe` (required for Windows desktop build)

### First-time setup

```powershell
# Set PATH (add to PowerShell profile for permanent use)
$env:Path += ";C:\flutter\flutter\bin;C:\Users\Smit\AppData\Local\Programs\Python\Python313;C:\Users\Smit"

# Install Python dependencies
pip install brainflow numpy scipy websockets mediapipe opencv-python

# Install Flutter dependencies
cd C:\DRIVE_F\Master\YC\GauntletAI\Capstone\GreyMatters
flutter pub get
```

---

## Running the App

You need **2 terminals** — one for the daemon, one for the app.

### Terminal 1 — Start the EEG Daemon

```powershell
cd C:\DRIVE_F\Master\YC\GauntletAI\Capstone\GreyMatters

# Option A: Mock data (no Crown needed, fast demo cycles)
python daemon/attention_engine.py --mock --demo

# Option B: Mock data (no Crown needed, slow realistic cycles)
python daemon/attention_engine.py --mock

# Option C: Real Crown (Crown must be ON, same WiFi, OSC enabled)
python daemon/attention_engine.py
```

Wait until you see:
```
[INFO] WebSocket server listening on ws://localhost:8765
```

### Terminal 2 — Start the Flutter App

```powershell
cd C:\DRIVE_F\Master\YC\GauntletAI\Capstone\GreyMatters

# Option A: Run as Windows desktop app
flutter run -d windows

# Option B: Run as web app in Chrome
flutter run -d chrome
```

### Order matters: Daemon FIRST, then App.

---

## Testing with Real Crown

### Before running:

1. **Power on** Crown headset (green LED)
2. **Put it on** your head
3. **Same WiFi** as your computer
4. **Enable OSC** in Neurosity Developer Console (https://console.neurosity.co)
5. **Firewall** — allow UDP port 9000 inbound (already configured as "Neurosity Crown OSC" rule)

### Start daemon in real mode:

```powershell
python daemon/attention_engine.py
```

If Crown connects:
```
[INFO] Crown connected via BrainFlow
[INFO] WebSocket server listening on ws://localhost:8765
```

If Crown not found — shows checklist and exits. Fix the issue and try again.

---

## Logging Raw EEG Data

To see raw data streaming from the daemon (Crown or mock):

```powershell
# Terminal 1: daemon must be running first

# Terminal 2: log raw data
python -c "import asyncio,websockets,json; exec('''
async def t():
    async with websockets.connect(\"ws://localhost:8765\") as ws:
        i=0
        while True:
            i+=1
            m=json.loads(await ws.recv())
            print(f\"{i:4d} | {m['level']:8s} | focus={m['focus_score']:.3f} | theta={m['theta']:.4f} | alpha={m['alpha']:.4f} | beta={m['beta']:.4f} | gamma={m['gamma']:.4f}\")
asyncio.run(t())
''')"
```

Output:
```
   1 | focused  | focus=0.823 | theta=0.2401 | alpha=0.1923 | beta=0.4102 | gamma=0.1574
   2 | focused  | focus=0.851 | theta=0.2215 | alpha=0.1845 | beta=0.4293 | gamma=0.1647
   3 | drifting | focus=0.412 | theta=0.3521 | alpha=0.2890 | beta=0.2341 | gamma=0.1248
```

---

## MediaPipe Hand Tracking Server (for gesture intervention)

```powershell
# With real camera
python daemon/mediapipe_server.py

# With mock data (no camera)
python daemon/mediapipe_server.py --mock
```

Runs on `ws://localhost:8766`.

---

## Deploying to Web (Vercel)

```powershell
cd C:\DRIVE_F\Master\YC\GauntletAI\Capstone\GreyMatters

# Build web
flutter build web --release

# Deploy
cd build/web
npx vercel --prod --yes --scope smitp1402s-projects

# Update stable URL
npx vercel alias <deployment-url> greymatters.vercel.app --scope smitp1402s-projects
```

Live URL: **https://greymatters.vercel.app**

---

## Building Windows Desktop (.exe)

```powershell
cd C:\DRIVE_F\Master\YC\GauntletAI\Capstone\GreyMatters

# Debug build
flutter build windows --debug

# Release build
flutter build windows --release

# Output at:
# build\windows\x64\runner\Release\neurolearn.exe
```

---

## Common Issues

| Problem | Solution |
|---------|----------|
| `python` not recognized | `$env:Path += ";C:\Users\Smit\AppData\Local\Programs\Python\Python313"` |
| `flutter` not recognized | `$env:Path += ";C:\flutter\flutter\bin"` |
| Port 8765 already in use | Kill old daemon: `taskkill /F /IM python.exe` |
| neurolearn.exe locked | Kill old app: `taskkill /F /IM neurolearn.exe` |
| Crown BOARD_NOT_READY | Check: Crown ON, same WiFi, OSC enabled, firewall allows UDP 9000 |
| NuGet not found (Windows build) | NuGet is at `C:\Users\Smit\nuget.exe` — add to PATH |
| Web build fails | Run `flutter pub get` first |

---

## App Flow

```
Landing Page → Login (Student/Teacher)

Student path:
  → Crown Connection → Debug Stream → Calibration (30s)
  → Session Code → Dashboard → Pick Topic → Lesson
  → (drift detected) → Intervention → Resume → Session End

Teacher path:
  → Enter Session Code → Live Monitor (focus gauge + timeline)
```

---

## Project URLs

- **Web app:** https://greymatters.vercel.app
- **GitHub:** https://github.com/smitp1402/GreyMatters
- **Supabase:** https://bndmilbxzrrmwzjrjand.supabase.co
