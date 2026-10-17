# Test Suite for Phase 4 Anti-Analysis

Describe "Anti-Analysis Detection" {
    BeforeAll {
        . "$PSScriptRoot/../lib/anti-analysis.ps1"
        . "$PSScriptRoot/../lib/edr-detect.ps1"
        . "$PSScriptRoot/../lib/network-detect.ps1"
    }

    Context "VM Detection" {
        It "Has detection function" {
            Test-Path Function:\Detect-VM | Should -Be $true
        }

        It "Returns null or string" {
            $result = Detect-VM
            ($result -eq $null -or $result -is [string]) | Should -Be $true
        }
    }

    Context "Debugger Detection" {
        It "Has detection function" {
            Test-Path Function:\Detect-Debugger | Should -Be $true
        }

        It "Returns boolean" {
            $result = Detect-Debugger
            $result -is [bool] | Should -Be $true
        }
    }

    Context "EDR Detection" {
        It "Has detection function" {
            Test-Path Function:\Detect-EDR | Should -Be $true
        }

        It "Returns boolean" {
            $result = Detect-EDR
            $result -is [bool] | Should -Be $true
        }

        It "Returns detailed results" {
            $result = Detect-EDR -Detailed
            $result -is [array] | Should -Be $true
        }
    }

    Context "Network Detection" {
        It "Has detection function" {
            Test-Path Function:\Test-NetworkIsolation | Should -Be $true
        }

        It "Returns hashtable" {
            $result = Test-NetworkIsolation
            $result -is [hashtable] | Should -Be $true
        }
    }
}

Write-Host "`n[*] Running Phase 4 anti-analysis tests..."
Invoke-Pester -Path $PSCommandPath -Output Detailed
