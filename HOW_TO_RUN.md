# How to Run

## Set PATH (run once per terminal)
```powershell
$env:Path += ";C:\flutter\flutter\bin;C:\Users\Smit\AppData\Local\Programs\Python\Python313;C:\Users\Smit"
```

## Terminal 1 — Daemon
```powershell
cd C:\DRIVE_F\Master\YC\GauntletAI\Capstone\GreyMatters

# Mock data (no Crown)
python daemon/attention_engine.py --mock --demo

# Real Crown
python daemon/attention_engine.py
```

## Terminal 2 — App
```powershell
cd C:\DRIVE_F\Master\YC\GauntletAI\Capstone\GreyMatters

# Desktop
flutter run -d windows

# Web
flutter run -d chrome
```

## Log Raw Data (Terminal 3)
```powershell
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

## Deploy to Vercel
```powershell
flutter build web --release
cd build/web
npx vercel --prod --yes --scope smitp1402s-projects
npx vercel alias <deployment-url> greymatters.vercel.app --scope smitp1402s-projects
```

## Kill Stuck Processes
```powershell
taskkill /F /IM python.exe
taskkill /F /IM neurolearn.exe
```
