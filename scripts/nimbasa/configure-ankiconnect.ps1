# Sets AnkiConnect to localhost only, with a new API key. Run with Anki closed: it keeps add-on settings in
# memory and may write them back. The key is never printed. It's kept in ANKI_API_KEY for the other scripts,
# and you can read it with:  [Environment]::GetEnvironmentVariable('ANKI_API_KEY', 'User')
$ErrorActionPreference = 'Stop'
$addon = Join-Path $env:APPDATA 'Anki2\addons21\2055492159'
$config = Get-Content (Join-Path $addon 'config.json') -Raw | ConvertFrom-Json
$meta = Get-Content (Join-Path $addon 'meta.json') -Raw | ConvertFrom-Json

$key = [Environment]::GetEnvironmentVariable('ANKI_API_KEY', 'User')
if (-not $key) {
    $bytes = New-Object byte[] 24
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $key = [Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
    [Environment]::SetEnvironmentVariable('ANKI_API_KEY', $key, 'User')
}

$config.webBindAddress = '127.0.0.1'
$config | Add-Member -NotePropertyName apiKey -NotePropertyValue $key -Force
$meta | Add-Member -NotePropertyName config -NotePropertyValue $config -Force
# WriteAllText writes UTF-8 with no byte-order mark. PowerShell 5's Set-Content would add one, which breaks JSON readers.
[IO.File]::WriteAllText((Join-Path $addon 'meta.json'), ($meta | ConvertTo-Json -Depth 10))
Write-Output 'AnkiConnect configured: localhost only, API key set.'
