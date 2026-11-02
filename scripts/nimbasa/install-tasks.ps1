# Registers the scheduled tasks. They run through conhost --headless so that no console window flashes.
param([Parameter(Mandatory)][string]$AnkiExe)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)

function Register-Headless($name, $script, $arguments, $triggers) {
    $action = New-ScheduledTaskAction -Execute 'conhost.exe' `
        -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$here\$script`" $arguments"
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force | Out-Null
}

$every5 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
Register-Headless 'Amadare Keep Anki Running' 'keep-anki-running.ps1' "-AnkiExe `"$AnkiExe`"" @((New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME), $every5)
Register-Headless 'Amadare Anki Sync' 'anki-sync.ps1' '' (New-ScheduledTaskTrigger -Daily -At 4am)
Write-Output 'Scheduled tasks registered.'
