# Test Suite for Obfuscation Module
# Tests: variable renaming, string encoding, behavior preservation

Describe "Obfuscation Module" {
    BeforeAll {
        . "$PSScriptRoot/../lib/obfuscation.ps1"
        $testDir = [System.IO.Path]::GetTempPath()
        $testScript = @"
`$hostname = [System.Net.Dns]::GetHostName()
`$url = 'http://example.com'
if (`$hostname -eq 'TEST') {
    Write-Host 'DELETE'
}
Start-Sleep -Seconds 5
"@
        $testScriptPath = Join-Path $testDir "test_script.ps1"
        $testScript | Set-Content $testScriptPath -Encoding UTF8
    }

    AfterAll {
        Remove-Item $testScriptPath -Force -ErrorAction SilentlyContinue
        Remove-Item "$testScriptPath" -Replace '\.ps1$', '_obfuscated.ps1' -Force -ErrorAction SilentlyContinue
    }

    It "Obfuscates variable names" {
        $obfuscatedPath = Obfuscate-PowerShellScript -ScriptPath $testScriptPath
        $obfuscated = Get-Content $obfuscatedPath -Raw

        # Original variable names should not appear (except special vars)
        $obfuscated -notmatch '\$hostname' | Should -Be $true
        $obfuscated -match '\$[a-z]{1,2}' | Should -Be $true

        # File should exist
        Test-Path $obfuscatedPath | Should -Be $true
    }

    It "Encodes suspicious strings" {
        $obfuscatedPath = Obfuscate-PowerShellScript -ScriptPath $testScriptPath -IncludeStringEncoding $true
        $obfuscated = Get-Content $obfuscatedPath -Raw

        # 'DELETE' and 'http' should be encoded (base64 or chunked)
        $obfuscated -notmatch "'DELETE'" | Should -Be $true
        $obfuscated -notmatch "'http://'" | Should -Be $true
    }

    It "Strips comments" {
        $scriptWithComment = @"
# This is a comment
`$var = 'value' # Inline comment
"@
        $commentPath = Join-Path $testDir "test_comment.ps1"
        $scriptWithComment | Set-Content $commentPath -Encoding UTF8

        $obfuscatedPath = Obfuscate-PowerShellScript -ScriptPath $commentPath -IncludeCommentStripping $true
        $obfuscated = Get-Content $obfuscatedPath -Raw

        # Comments should be removed
        $obfuscated -notmatch '# This is a comment' | Should -Be $true
        $obfuscated -notmatch '# Inline comment' | Should -Be $true

        Remove-Item $commentPath -Force
    }

    It "Provides obfuscation stats" {
        $obfuscatedPath = Obfuscate-PowerShellScript -ScriptPath $testScriptPath
        $stats = Get-Obfuscation-Stats -OriginalPath $testScriptPath -ObfuscatedPath $obfuscatedPath

        $stats | Should -HaveProperty "OriginalSize"
        $stats | Should -HaveProperty "ObfuscatedSize"
        $stats | Should -HaveProperty "SizeChange"
        $stats | Should -HaveProperty "OriginalVarCount"
        $stats | Should -HaveProperty "ObfuscatedVarCount"
    }
}

# Run tests with Pester
Write-Host "`n[*] Running obfuscation tests..."
Invoke-Pester -Path $PSCommandPath -Output Detailed
