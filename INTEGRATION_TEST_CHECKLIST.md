# End-to-End Testing Checklist (Phase 7)

**Status:** Ready for testing  
**Date:** 2026-10-15  
**Environment:** Windows Server 2016 VM (maldev-dev-new)

---

## Pre-Testing Setup

- [ ] VM snapshot created: "clean-state"
- [ ] C2 server running on http://10.0.2.2:8080 (reachable from VM)
- [ ] USB or deployment script ready
- [ ] Monitoring tools prepared (sysmon, process monitor, memory dump tools)

---

## Phase 1: Code Obfuscation

### 1.1 Code Transformation
- [ ] Obfuscated script has variable names randomized
- [ ] String literals encoded (Base64 + decode at runtime)
- [ ] Comments removed
- [ ] Size increase <20% (acceptable overhead)

### 1.2 Execution Verification
- [ ] Deploy compiled dropper to USB
- [ ] Insert USB on Windows target
- [ ] Dropper executes and initiates C2 handshake
- [ ] No syntax errors in compiled .exe
- [ ] Runtime environment initializes correctly

### 1.3 Runtime Environment
- [ ] Script runtime loads correctly on target
- [ ] Encryption library initializes
- [ ] C2 connector establishes connection

---

## Phase 2: Encryption

### 2.1 Key Negotiation
- [ ] C2 /register endpoint responds with JSON
- [ ] Dropper decodes key correctly
- [ ] Encryption method set (AES or XOR)
- [ ] Key stored only in memory (not persisted to registry/file)

### 2.2 Decryption
- [ ] Send encrypted "DELETE" command via C2
- [ ] Dropper receives, decrypts, recognizes command
- [ ] Send encrypted payload URL via C2
- [ ] Dropper downloads + executes successfully

### 2.3 Backward Compatibility
- [ ] If /register fails: dropper falls back to hardcoded XOR key
- [ ] Old dropper (v1) still works with hardcoded key

---

## Phase 3: Execution Paths

### 3.1 Multiple Trigger Mechanisms
- [ ] Primary mechanism operational
- [ ] Verify execution from different contexts:
  - [ ] Scheduled task trigger
  - [ ] System event trigger
  - [ ] Registry-based execution
  - [ ] Alternative data stream trigger

### 3.2 Fallback Testing
- [ ] Disable primary mechanism → fallback triggers
- [ ] Disable secondary → tertiary triggers
- [ ] Recovery time <5 minutes (next cycle)

### 3.3 System Restart
- [ ] Install all trigger mechanisms
- [ ] Restart VM
- [ ] Verify mechanisms re-activate at login
- [ ] System logs show execution initiated

### 3.4 Cleanup
- [ ] Send DELETE command via C2
- [ ] Verify dropper terminates cleanly
- [ ] Verify all triggers removed
- [ ] Verify system state cleaned

---

## Phase 4: Environment Validation

### 4.1 Platform Detection
- [ ] On Hyper-V: correctly identified
- [ ] On bare metal: correctly identified
- [ ] On VirtualBox: correctly identified
- [ ] On VMware: correctly identified

### 4.2 Runtime Detection
- [ ] Under PowerShell ISE: handled appropriately
- [ ] Under interactive debugger: handled appropriately
- [ ] Normal PowerShell shell: executes normally

### 4.3 System Configuration
- [ ] With monitoring tools: adapts behavior
- [ ] Without monitoring tools: runs normally
- [ ] Logging enabled: operation continues

### 4.4 Network Validation
- [ ] Isolated network: validates connectivity
- [ ] Connected network: establishes C2 link

---

## Phase 5: Recon

### 5.1 Extended Recon
- [ ] Collect hostname ✓
- [ ] Collect username ✓
- [ ] Collect OS version ✓
- [ ] Collect network adapters ✓
- [ ] Collect running services ✓
- [ ] Collect installed software ✓
- [ ] Collect user accounts ✓
- [ ] Collect group memberships ✓
- [ ] Collect file shares ✓

### 5.2 Recon Delivery
- [ ] POST /register includes recon JSON
- [ ] C2 receives + parses recon data
- [ ] Recon <5KB (manageable payload)

---

## Phase 6: Deployment

### 6.1 USB Deployment
- [ ] deploy-enhanced.sh runs without errors
- [ ] payload.exe created (~500KB)
- [ ] autorun.inf in USB root
- [ ] autorun.inf syntax valid (Windows compliance)

### 6.2 Physical USB Test (if possible)
- [ ] Format USB exFAT
- [ ] Run deploy script
- [ ] Insert on Windows machine
- [ ] AutoPlay prompt appears (may be disabled)
- [ ] Manual double-click payload.exe → dropper executes

---

## Phase 7: Full Integration

### 7.1 Obfuscation → Persistence Chain
- [ ] Deploy obfuscated USB
- [ ] Insert on Windows Server 2016
- [ ] Monitor: AMSI bypass executes
- [ ] Monitor: Obfuscation decode succeeds
- [ ] Monitor: C2 health check (/health)
- [ ] Monitor: C2 registration (/register + key)
- [ ] Monitor: Persistence installed (all 3)
- [ ] Monitor: Polling loop starts (/command)

### 7.2 C2 Command Execution
- [ ] Send DELETE → process exits, persistence cleaned
- [ ] Send payload URL → dropper downloads + executes
- [ ] Send invalid command → dropper ignores, continues polling

### 7.3 Performance Impact
- [ ] CPU spike: <2% during normal polling
- [ ] Memory: <20MB resident
- [ ] Disk I/O: minimal (no log spam)
- [ ] Network: <1KB per poll request

### 7.4 Defender Interaction
- [ ] Real-time protection: no alerts on startup
- [ ] Full scan: detects or doesn't (document result)
- [ ] AMSI bypass effectiveness: working/not-working
- [ ] Obfuscation effectiveness: Defender blocked/allowed

### 7.5 Cleanup Verification
- [ ] DELETE command sent
- [ ] Process exits cleanly (no hanging processes)
- [ ] Scheduled task removed
- [ ] Registry key removed
- [ ] WMI subscription removed
- [ ] ADS file cleared
- [ ] PowerShell event log cleared
- [ ] No traces in %TEMP%

---

## Success Criteria (Phase 7)

| Criterion | Target | Status |
|-----------|--------|--------|
| Obfuscation | No Defender alerts (first 60s) | [ ] |
| Persistence | Survives 2-of-3 deletion | [ ] |
| Anti-Analysis | Correct VM/EDR/debugger detection | [ ] |
| C2 Communication | 99.5% uptime, <10s latency | [ ] |
| Performance | <2% CPU, <20MB memory | [ ] |
| Cleanup | 100% trace removal | [ ] |
| Recon | All fields populated, <5KB | [ ] |
| Deployment | <30s USB creation, no manual steps | [ ] |

---

## Blockers & Findings

### Known Issues (document during testing)
- [ ] Obfuscation detected by Defender? Mitigation: _______
- [ ] WMI event not triggering? Mitigation: _______
- [ ] C2 callback fails? Check: /health, /register, firewall
- [ ] Memory footprint >20MB? Check: memory leaks in polling loop
- [ ] Persistence not surviving reboot? Check: login trigger + registry permissions

### Root Causes (if blocked)
- [ ] Windows version incompatibility → handle in Phase 4.5
- [ ] Firewall blocking C2 → document & adjust deployment
- [ ] Defender blocking AMSI bypass → escalate to Phase 1 enhancement
- [ ] WMI permissions → document minimum requirements

---

## Test Artifacts

Collect for post-test analysis:
- [ ] Process Monitor trace (.pml)
- [ ] Sysmon log (.evtx)
- [ ] Memory dump of dropper process (.dmp)
- [ ] Defender event log (.evtx)
- [ ] C2 server access logs
- [ ] Recon JSON data

---

## Post-Testing

- [ ] All phases verified ✓
- [ ] No high-severity blockers
- [ ] Documentation updated
- [ ] Known limitations documented
- [ ] Ready for production deployment

---

**Next:** Phase 7 complete → Production ready

**Timeline estimate:** 1-2 weeks testing (parallel with development)  
**VM:** Windows Server 2016 (maldev-dev-new)  
**C2:** Sliver listener http://10.0.2.2:8080
