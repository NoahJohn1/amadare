# Starts Anki if nothing is listening on AnkiConnect's port. Run by a scheduled task in the desktop session,
# since Anki can't start from a service or an SSH session.
param([Parameter(Mandatory)][string]$AnkiExe)
if (Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue) { exit 0 }
Start-Process -FilePath $AnkiExe
