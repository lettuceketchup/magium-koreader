# One-time per-Kindle setup: plant the deploy public key on the device over USB,
# so kindle-ssh-deploy.ps1 can push builds over Wi-Fi with no password and no
# manual folder deletion.
#
#   powershell -File tools/kindle-ssh-setup.ps1 -Name paperwhite [-Ip 192.168.1.42]
#
# The Kindle must be USB-connected and unlocked. Also, once, on the device:
#   Tools (cog) > Network > SSH server:
#     - tick "Login with key only (SECURE)"
#     - optionally tick "Start SSH server with KOReader" (auto-start on boot)
#     - Start it once  (creates settings/SSH/ and shows the device IP + port)
# Then run this script. The IP goes in the device config (pass -Ip now or let
# kindle-ssh-test.ps1 fill it in later).

param(
  [Parameter(Mandatory)][string]$Name,
  [int]$Port = 2222,
  [string]$User = 'root',
  [string]$Ip
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\kindle-ssh-common.ps1"
Initialize-KindleKey

$pub = (Get-Content "$KeyPath.pub" -Raw).Trim()
Write-Host "deploy public key:`n  $pub`n"

# stage an authorized_keys file (LF, no BOM) with our one key
$stage = Join-Path $env:TEMP 'magium-kindle-ssh'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
$akLocal = Join-Path $stage 'authorized_keys'
[IO.File]::WriteAllText($akLocal, $pub + "`n")
$want = (Get-Item $akLocal).Length

# --- locate koreader/settings/SSH on the USB-connected device ---
$sh = New-Object -ComObject Shell.Application
$kindle = $sh.Namespace(17).Items() | Where-Object { $_.Name -like 'Kindle*' }
if (-not $kindle) { throw 'no Kindle under This PC - connect USB and unlock the device' }
function child($folder, $name) { ($folder.Items() | Where-Object { $_.Name -eq $name }).GetFolder }
$settings = child (child (child $kindle.GetFolder 'Internal Storage') 'koreader') 'settings'
if (-not $settings) { throw 'koreader/settings not found - open KOReader on the device at least once' }
$sshDir = child $settings 'SSH'
if (-not $sshDir) {
  Write-Host 'creating koreader/settings/SSH ...'
  $settings.NewFolder('SSH'); Start-Sleep -Milliseconds 600
  $sshDir = child $settings 'SSH'
  if (-not $sshDir) { throw 'could not create settings/SSH over MTP - on the device open Tools > Network > SSH server and Start it once, then rerun' }
}

# --- replace authorized_keys (MTP CopyHere will not overwrite; delete first) ---
$old = $sshDir.Items() | Where-Object { $_.Name -eq 'authorized_keys' }
if ($old) {
  $del = $old.Verbs() | Where-Object { $_.Name -replace '&','' -eq 'Delete' }
  if ($del) { $del.DoIt() } else { $old.InvokeVerb('delete') }
  Start-Sleep -Milliseconds 800
}
$FOF = 16 -bor 512 -bor 1024
$sshDir.CopyHere($sh.Namespace($stage).ParseName('authorized_keys'), $FOF)

# --- verify by size ---
$got = $null
for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Milliseconds 500
  $it = $sshDir.Items() | Where-Object { $_.Name -eq 'authorized_keys' }
  if ($it) { $got = [int64]$it.ExtendedProperty('System.Size'); if ($got -eq $want) { break } }
}
if ($got -ne $want) {
  throw "authorized_keys copy failed (device $got != $want bytes). Delete This PC > Kindle > Internal Storage > koreader > settings > SSH > authorized_keys by hand, then rerun."
}
Write-Host "authorized_keys placed on device ($want bytes)"

# --- write / update the device config ---
$dev = $null
try { $dev = Get-KindleDevice -Name $Name } catch { }
if (-not $dev) { $dev = [pscustomobject]@{ name = $Name; host = $null; port = $Port; user = $User; koreader_dir = '/mnt/us/koreader' } }
if ($Ip) { $dev.host = $Ip }
$dev.port = $Port
$dev.user = $User
Save-KindleDevice $dev
Write-Host "wrote tools/.kindle/devices/$Name.json"

Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host '  1. Unplug USB. On the Kindle, start the SSH server (Tools > Network > SSH server).'
Write-Host "  2. powershell -File tools/kindle-ssh-test.ps1 -Name $Name$(if (-not $Ip) { ' -Ip <device-ip>' })"
Write-Host "  3. powershell -File tools/kindle-ssh-deploy.ps1 -Name $Name"
