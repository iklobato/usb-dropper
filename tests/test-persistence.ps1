# Test Suite for Phase 3 Persistence

Describe "Persistence Mechanisms" {
    BeforeAll {
        . "$PSScriptRoot/../lib/wmi-event-persistence.ps1"
        . "$PSScriptRoot/../lib/ads-persistence.ps1"
        . "$PSScriptRoot/../lib/scheduled-task-obfuscation.ps1"
    }

    Context "WMI Event Persistence" {
        It "Initializes with correct properties" {
            $persistence = New-Object WmiEventPersistence
            $persistence.ConsumerName | Should -BeNullOrEmpty  # Set during Install
            $persistence | Should -HaveProperty "ConsumerName"
            $persistence | Should -HaveProperty "FilterName"
            $persistence | Should -HaveProperty "BindingName"
        }
    }

    Context "ADS Persistence" {
        It "Has anchor file and stream name" {
            $persistence = New-Object AdsPersis persistence
            $persistence.AnchorFile | Should -Be "C:\Windows\System32\drivers\etc\hosts"
            $persistence.StreamName | Should -Be "polling.ps1"
        }
    }

    Context "Legitimate Task Names" {
        It "Returns legitimate Windows task names" {
            $taskConfig = Create-LegitimateTask -TaskName "Test" -Command "test.exe"

            $taskConfig | Should -HaveProperty "TaskName"
            $taskConfig | Should -HaveProperty "Command"
            $taskConfig.TaskName | Should -Match "Microsoft\\Windows"
        }

        It "Supports different parent processes" {
            $taskConfig1 = Create-LegitimateTask -TaskName "Test" -Command "test.exe" -ParentProcess "svchost.exe"
            $taskConfig2 = Create-LegitimateTask -TaskName "Test" -Command "test.exe" -ParentProcess "wmic.exe"

            $taskConfig1.Command | Should -Match "svchost"
            $taskConfig2.Command | Should -Match "wmic"
        }
    }
}

Write-Host "`n[*] Running Phase 3 persistence tests..."
Invoke-Pester -Path $PSCommandPath -Output Detailed
