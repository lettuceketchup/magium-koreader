# Check that a configured Kindle is reachable over SSH with the deploy key.
# Persists the IP (if passed) and the real koreader dir back to the device config.
#
#   powershell -File tools/kindle-ssh-test.ps1 -Name paperwhite [-Ip 192.168.1.42]

param(
  [string]$Name,
  [string]$Ip,
  [int]$Port,
  [string]$User
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\kindle-ssh-common.ps1"

$dev = Get-KindleDevice -Name $Name
if ($Ip)   { $dev.host = $Ip }
if ($Port) { $dev.port = $Port }
if ($User) { $dev.user = $User }

Write-Host "testing $($dev.user)@$($dev.host):$($dev.port)  (key: $KeyPath)"
$r = Test-KindleSsh -Device $dev
if (-not $r.Ok) {
  Write-Host ''
  Write-Host 'SSH TEST FAILED.' -ForegroundColor Red
  Write-Host "  - SSH server started on the Kindle?  (Tools > Network > SSH server)"
  Write-Host "  - same Wi-Fi, IP still $($dev.host)?"
  Write-Host "  - 'Login with key only' ticked, and kindle-ssh-setup.ps1 run for this device?"
  exit 1
}
Save-KindleDevice $dev
Write-Host ''
Write-Host "OK - $($dev.name) reachable; koreader at $($dev.koreader_dir)" -ForegroundColor Green
