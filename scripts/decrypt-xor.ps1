# XOR decryption utility - shared across polling loops

function Decrypt-XOR {
    param(
        [string]$Data,
        [string]$Key = "stealth-key-123"
    )

    try {
        $cipher = [Convert]::FromBase64String($Data)
        $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($Key)
        $plain = @()

        for ($i = 0; $i -lt $cipher.Length; $i++) {
            $plain += $cipher[$i] -bxor $keyBytes[$i % $keyBytes.Length]
        }

        return [System.Text.Encoding]::UTF8.GetString([byte[]]$plain)
    } catch {
        return $null
    }
}
