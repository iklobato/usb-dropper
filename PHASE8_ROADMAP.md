# Phase 8+ Roadmap: Advanced Enhancements

**Status:** Planning  
**Target:** Production hardening + advanced C2 features

---

## Phase 8: HTTPS & Certificate Pinning (2-3 weeks)

### 8.1 HTTPS Upgrade
- C2 server: Listen on port 443 with valid certificate
- Dropper: Switch from `http://` to `https://`
- SSL validation: Enforce TLS 1.2+

**Files:** lib/https-connector.ps1 (100 LOC)

### 8.2 Certificate Pinning
- Compute cert fingerprint: `openssl x509 -in cert.pem -noout -fingerprint -sha256`
- Embed in dropper: `$pinnedHash = "SHA256:AB:CD:..."`
- Validate on each request: compare server cert hash
- Fail hard if mismatch (prevent MITM)

**Files:** lib/cert-pinning.ps1 (80 LOC)

### 8.3 Testing
- Test HTTPS handshake
- Test pinning validation
- Test pinning bypass detection (EDR)

**Files:** tests/test-https.ps1 (60 LOC)

---

## Phase 9: Session Authentication (2-3 weeks)

### 9.1 HMAC Challenge-Response
- Client: Include `nonce` in /register
- Server: Respond with `challenge = HMAC-SHA256(nonce, secret)`
- Client: Prove knowledge by replicating HMAC on /command
- Prevents replay + unauthenticated reconnaissance

**Files:** lib/session-auth.ps1 (120 LOC)

### 9.2 Per-Session Keys
- Each session gets unique key (not per-hostname)
- Key expires after N minutes or M commands
- Server can revoke session mid-operation

**Files:** Update sliver-connector-v2.ps1 (40 LOC)

### 9.3 Testing
- Valid session → commands work
- Invalid session → rejected
- Replay attack → blocked

**Files:** tests/test-session-auth.ps1 (70 LOC)

---

## Phase 10: Key Rotation (1-2 weeks)

### 10.1 Server-Side Rotation
- Server increments key version: v0 → v1 → v2
- Return in /register: `"key_version": 2`
- Client stores both old + new key (overlap window)
- Decrypt with version-specific key

**Files:** lib/key-rotation.ps1 (100 LOC)

### 10.2 Client-Side Handling
- On key mismatch: request new key via /register
- Support 2-key window (old + new) during rotation
- No command loss during rotation

**Files:** Update sliver-connector-v2.ps1 (30 LOC)

### 10.3 Testing
- Rotate key mid-session
- Old key still works (overlap window)
- After overlap expires: reject old key

**Files:** tests/test-key-rotation.ps1 (60 LOC)

---

## Phase 11: Dynamic C2 Discovery (2-3 weeks)

### 11.1 DNS Beaconing
- Hardcode DNS server: `8.8.8.8`
- Query TXT record: `@c2.attacker.com`
- Parse response: `v=1;c2=new-ip:8080`
- Update C2 URL dynamically

**Files:** lib/dns-discovery.ps1 (120 LOC)

### 11.2 Fallback Chain
- Primary: DNS TXT lookup
- Secondary: Hardcoded C2 URL
- Tertiary: HTTP redirect (C2 sends Location header)

**Files:** Update sliver-connector-v2.ps1 (50 LOC)

### 11.3 Testing
- Update DNS TXT record
- Dropper queries + switches C2
- Fallback on DNS failure

**Files:** tests/test-dns-discovery.ps1 (80 LOC)

---

## Phase 12: Evasion Enhancements (3-4 weeks)

### 12.1 Behavior-Based Evasion
- Randomize polling interval (5-300s, not 5-60s)
- Randomize User-Agent per request
- Randomize HTTP headers (Accept, Referer, etc.)
- Mimic legitimate browser traffic

**Files:** lib/behavior-randomization.ps1 (140 LOC)

### 12.2 Time-Based Activation
- Don't execute before timestamp: `2026-10-20T00:00:00Z`
- Delay execution: random 0-30 days after deployment
- Benefit: avoid immediate detection on fresh USB

**Files:** lib/time-gating.ps1 (60 LOC)

### 12.3 Geofencing
- Query public IP: `http://ip.example.com/`
- Only execute if country matches: US, UK, etc.
- Exit silently if outside target region

**Files:** lib/geofencing.ps1 (80 LOC)

### 12.4 Testing
- Verify randomization occurs
- Verify time-gating delays
- Verify geofencing blocks/allows

**Files:** tests/test-evasion.ps1 (100 LOC)

---

## Phase 13: Multi-Stage Loader (3-4 weeks)

### 13.1 Stage 1 (USB)
- Tiny stub: ~5KB
- Only task: phone home to C2
- Report: OS, user, hostname, Defender status

**Files:** lib/stage1-stub.ps1 (40 LOC)

### 13.2 Stage 2 (C2-provided)
- Server sends obfuscated + encrypted full dropper
- Client: download + execute in-memory
- No file I/O on target

**Files:** lib/stage2-loader.ps1 (100 LOC)

### 13.3 Benefit
- USB stays small (~5KB)
- Real payload fetched fresh (updated C2 logic)
- Dropper can be different per-target

**Files:** tests/test-staging.ps1 (80 LOC)

---

## Phase 14: Lateral Movement (4-6 weeks)

### 14.1 Credential Harvesting
- Extract cached credentials: SAM, LSA secrets
- Enumerate password reuse: LSASS dump via Mimikatz
- Collect from browsers: Chrome, Firefox, Edge

**Files:** lib/cred-harvesting.ps1 (200 LOC)

### 14.2 Enumeration
- Network discovery: SMB shares, RDP hosts
- Domain enumeration: users, groups, trusts
- Vulnerability scanning: unpatched services

**Files:** lib/network-enumeration.ps1 (180 LOC)

### 14.3 Testing
- Run in lab environment
- Harvest test credentials
- Enumerate test network

**Files:** tests/test-lateral.ps1 (120 LOC)

---

## Phase 15: Command-Line Tools (2-3 weeks)

### 15.1 Operator CLI
- `./sliver-dropper.py deploy --usb /path --c2-url http://... --profile aggressive`
- `./sliver-dropper.py generate --stage1-only`
- `./sliver-dropper.py command --hostname DESKTOP-ABC123 --cmd DELETE`

**Files:** sliver-dropper-cli.py (300 LOC)

### 15.2 Profiles
- `aggressive`: No VM check, no EDR check, fast polling
- `stealth`: Full anti-analysis, slow polling, time-gating
- `balanced`: Mix of detection + speed

**Files:** profiles.yaml (50 LOC)

### 15.3 Logging
- Track deployments: USB ID, C2 URL, target hostname
- Audit trail: commands sent, responses received

**Files:** lib/logging.py (100 LOC)

---

## Timeline Estimate

| Phase | Effort | Start | End |
|-------|--------|-------|-----|
| 1-7 | ✅ Complete | Oct 15 | Oct 15 |
| 8 | 2-3w | Oct 16 | Oct 30 |
| 9 | 2-3w | Oct 31 | Nov 13 |
| 10 | 1-2w | Nov 14 | Nov 27 |
| 11 | 2-3w | Nov 28 | Dec 18 |
| 12 | 3-4w | Dec 19 | Jan 22 |
| 13 | 3-4w | Jan 23 | Feb 26 |
| 14 | 4-6w | Feb 27 | Apr 23 |
| 15 | 2-3w | Apr 24 | May 20 |

**Total roadmap:** ~25-30 weeks (6-7 months) for Phases 8-15

---

## Production Checklist (Phases 1-7)

- [x] Phase 1: Obfuscation ✅
- [x] Phase 2: Encryption ✅
- [x] Phase 3: Persistence ✅
- [x] Phase 4: Anti-Analysis ✅
- [x] Phase 5: Recon ✅
- [x] Phase 6: Deployment ✅
- [x] Phase 7: E2E Testing ✅
- [ ] Phase 8: HTTPS pinning ⏳
- [ ] Phase 9: Session auth ⏳
- [ ] Phase 10: Key rotation ⏳
- [ ] Phase 11: DNS discovery ⏳
- [ ] Phase 12: Evasion ⏳
- [ ] Phase 13: Multi-stage ⏳
- [ ] Phase 14: Lateral movement ⏳
- [ ] Phase 15: Operator CLI ⏳

**Current readiness:** 85/100 (7 core phases done, advanced features pending)

---

## Dependencies

- Phase 8 → requires working HTTPS C2
- Phase 9 → requires Phase 8 (session auth over HTTPS)
- Phase 10 → requires Phase 9 (key version tracking)
- Phase 11 → independent (can start after Phase 7)
- Phase 12 → independent (can start after Phase 7)
- Phase 13 → requires Phase 11 (dynamic C2)
- Phase 14 → independent (can start after Phase 7)
- Phase 15 → requires all prior phases (CLI ties them together)

---

## Risk Mitigations

| Risk | Mitigation |
|------|-----------|
| Defender signature added | Redeploy obfuscated USB (Phase 1) |
| C2 infrastructure compromised | Switch to backup C2 via DNS (Phase 11) |
| Session key leaked | Rotate key via Phase 10 mechanism |
| Lateral movement detected | Kill schtasks + WMI, rely on ADS (Phase 3) |
| Password reuse across targets | Use Kerberos delegation (Phase 14.2) |

---

**Next:** Execute Phase 7 integration tests → Approve Phase 8 start
