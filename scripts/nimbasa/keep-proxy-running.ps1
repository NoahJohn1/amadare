# Starts Muse's read-only Anki proxy if it isn't listening. Pass the Tailscale IP as -Bind: the proxy fails to
# start until Tailscale is up, so this retries on a schedule.
param(
    [Parameter(Mandatory)][string]$Proxy,
    [Parameter(Mandatory)][string]$Bind
)
if (Get-NetTCPConnection -LocalPort 18765 -State Listen -ErrorAction SilentlyContinue) { exit 0 }
Start-Process -FilePath pythonw.exe -ArgumentList "`"$Proxy`"", '--bind', $Bind, '--port', '18765' -WindowStyle Hidden
