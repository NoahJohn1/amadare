# Syncs the collection to AnkiWeb: the off-machine backup. Logs each run, because the task's own result
# shows 0 even when this fails (it runs through conhost).
$log = Join-Path $env:LOCALAPPDATA 'Amadare\anki-sync.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
$key = [Environment]::GetEnvironmentVariable('ANKI_API_KEY', 'User')
$body = @{ action = 'sync'; version = 6; key = $key } | ConvertTo-Json
try {
    $reply = Invoke-RestMethod -Uri 'http://127.0.0.1:8765' -Method Post -Body $body -TimeoutSec 300
    $outcome = if ($reply.error) { "failed: $($reply.error)" } else { 'ok' }
} catch {
    $outcome = "failed: $_"
}
Add-Content $log "$(Get-Date -Format s) $outcome"
