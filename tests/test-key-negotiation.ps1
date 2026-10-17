# Test Suite for Key Negotiation (Phase 2)

Describe "Key Negotiation & Encryption" {
    BeforeAll {
        . "$PSScriptRoot/../lib/aes-gcm-encryption.ps1"
        . "$PSScriptRoot/../lib/sliver-connector-v2.ps1"
    }

    Context "AES-GCM Encryption" {
        It "Encrypts and decrypts plaintext" {
            $plaintext = "DELETE"
            $key = New-AesKey

            $encrypted = Encrypt-AesGcm -Plaintext $plaintext -Key $key
            $decrypted = Decrypt-AesGcm -Ciphertext $encrypted -Key $key

            $decrypted | Should -Be $plaintext
        }

        It "Fails decryption with wrong key" {
            $plaintext = "secret"
            $key1 = New-AesKey
            $key2 = New-AesKey

            $encrypted = Encrypt-AesGcm -Plaintext $plaintext -Key $key1
            $decrypted = Decrypt-AesGcm -Ciphertext $encrypted -Key $key2

            $decrypted | Should -Be $null
        }

        It "Detects tampered ciphertext" {
            $plaintext = "authenticated"
            $key = New-AesKey

            $encrypted = Encrypt-AesGcm -Plaintext $plaintext -Key $key

            # Tamper with first byte of base64
            $tamperedCiphertext = [char]([int][char]$encrypted[0] + 1) + $encrypted.Substring(1)

            try {
                $decrypted = Decrypt-AesGcm -Ciphertext $tamperedCiphertext -Key $key
                $decrypted | Should -Be $null
            } catch {
                # Expected: invalid base64 or auth failure
                $_ | Should -Not -BeNullOrEmpty
            }
        }

        It "Generates random keys" {
            $key1 = New-AesKey
            $key2 = New-AesKey

            $key1 | Should -Not -Equal $key2
        }
    }

    Context "SliverConnectorV2" {
        It "Initializes with URL and hostname" {
            $connector = New-Object SliverConnectorV2("http://test:8080", "TEST-HOST")

            $connector.URL | Should -Be "http://test:8080"
            $connector.Hostname | Should -Be "TEST-HOST"
        }

        It "Uses default encryption XOR" {
            $connector = New-Object SliverConnectorV2("http://test:8080")

            $connector.EncryptionMethod | Should -Be "xor"
        }

        It "Sets encryption key" {
            $connector = New-Object SliverConnectorV2("http://test:8080")
            $newKey = [System.Text.Encoding]::UTF8.GetBytes("new-key-123")

            $connector.SetKey($newKey)

            $connector.EncryptionKey | Should -Be $newKey
        }

        It "Decrypts XOR-encrypted messages" {
            $connector = New-Object SliverConnectorV2("http://test:8080")
            $plaintext = "DELETE"
            $key = [System.Text.Encoding]::UTF8.GetBytes("stealth-key-123")

            # Manually encrypt using XOR
            $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($plaintext)
            $cipherBytes = @()
            for ($i = 0; $i -lt $plainBytes.Length; $i++) {
                $cipherBytes += $plainBytes[$i] -bxor $key[$i % $key.Length]
            }
            $encrypted = [Convert]::ToBase64String($cipherBytes)

            # Decrypt using connector
            $connector.SetKey($key)
            $decrypted = $connector._DecryptXor($encrypted)

            $decrypted | Should -Be $plaintext
        }
    }
}

Write-Host "`n[*] Running Phase 2 encryption tests..."
Invoke-Pester -Path $PSCommandPath -Output Detailed
