# Deploy magium.koplugin to a Kindle over Wi-Fi via KOReader's SSH server.
# No USB, no MTP, no manual folder deletion. Tests the connection before acting.
#
# One-time per device:  powershell -File tools/kindle-ssh-setup.ps1 -Name <name>
# Then:                  powershell -File tools/kindle-ssh-deploy.ps1 -Name <name>
#
# -Ip alone (no -Name) still works ad hoc if setup was never run for the device
# and "Login without password" is enabled on it.

param(
  [string]$Name,
  [string]$Ip,
  [int]$Port,
  [string]$User
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\kindle-ssh-common.ps1"

# --- resolve target ---
$dev = $null
try { $dev = Get-KindleDevice -Name $Name } catch { if (-not $Ip) { throw } }
if (-not $dev) { $dev = [pscustomobject]@{ name = '(adhoc)'; host = $Ip; port = 2222; user = 'root'; koreader_dir = '/mnt/us/koreader' } }
if ($Ip)   { $dev.host = $Ip }
if ($Port) { $dev.port = $Port }
if ($User) { $dev.user = $User }

# --- stage: repo plugin minus spec/ and dotfiles ---
$repo  = Split-Path $PSScriptRoot -Parent
$src   = Join-Path $repo 'magium.koplugin'
$stage = Join-Path $env:TEMP 'magium-kindle-stage'
$dest  = Join-Path $stage 'magium.koplugin'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse "$src\*" $dest
Remove-Item -Recurse -Force "$dest\spec" -ErrorAction SilentlyContinue
Get-ChildItem $dest -Force -Filter '.*' | Remove-Item -Recurse -Force
$want = (Get-ChildItem -Recurse -File $dest).Count
Write-Host "staged $want runtime files"

# --- test the connection before touching the device ---
$r = Test-KindleSsh -Device $dev -Quiet
if (-not $r.Ok) {
  Write-Host 'SSH not reachable:' -ForegroundColor Red
  $r.Output | ForEach-Object { Write-Host "  $_" }
  Write-Host "Fix with: powershell -File tools/kindle-ssh-test.ps1 -Name $($dev.name)"
  exit 1
}
if ($dev.name -ne '(adhoc)') { Save-KindleDevice $dev }
$kodir  = $dev.koreader_dir
$target = "$kodir/plugins/magium.koplugin"
Write-Host "device koreader dir: $kodir"

# --- wipe + push fresh (rm -rf is busybox; sftp put -r for the copy) ---
$sshArgs = Get-KindleSshArgs $dev
& ssh @sshArgs "rm -rf '$target'"
$batch = "put -r `"$($dest -replace '\\','/')`" `"$kodir/plugins/`""
$batch | & sftp -i $KeyPath -P $dev.port -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$($dev.user)@$($dev.host)" | Out-Null

# --- verify by file count ---
$got = [int](& ssh @sshArgs "find '$target' -type f | wc -l").Trim()
Write-Host "device now has $got / $want files"
if ($got -lt $want) { Write-Host 'INCOMPLETE - rerun.' -ForegroundColor Red; exit 1 }
Write-Host 'OK - restart KOReader on the Kindle to load it.'
