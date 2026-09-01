# Deploy magium.koplugin to the Kindle over WiFi via KOReader's SSH server.
# No USB, no MTP, no manual folder deletion — this is the repeatable dev loop.
#
# ONE-TIME SETUP on the Kindle (KOReader):
#   Tools (cog) > Network > SSH server:
#     - tick "Login without password (DANGEROUS)"   (home WiFi only)
#       OR put your public key in  koreader/settings/SSH/authorized_keys
#     - Start the SSH server. It shows the device IP + port 2222.
#   Optional: tick "auto-start" so it's on every boot.
#
# USAGE:
#   powershell -File tools/deploy-kindle-ssh.ps1 -Ip 192.168.1.42
#   (set $env:KINDLE_IP once and omit -Ip)

param(
  [string]$Ip = $env:KINDLE_IP,
  [int]$Port = 2222,
  [string]$User = "root"
)

$ErrorActionPreference = 'Stop'
if (-not $Ip) { throw "No IP. Pass -Ip <addr> (shown on the Kindle's SSH server screen), or set `$env:KINDLE_IP." }

$repo  = Split-Path $PSScriptRoot -Parent
$src   = Join-Path $repo 'magium.koplugin'
$stage = Join-Path $env:TEMP 'magium-kindle-stage'
$dest  = Join-Path $stage 'magium.koplugin'

# --- stage: repo plugin minus spec/ and dotfiles ---
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse "$src\*" $dest
Remove-Item -Recurse -Force "$dest\spec" -ErrorAction SilentlyContinue
Get-ChildItem $dest -Force -Filter '.*' | Remove-Item -Recurse -Force
$want = (Get-ChildItem -Recurse -File $dest).Count
Write-Host "staged $want runtime files"

$sshArgs = @('-p', $Port, '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=8', "$User@$Ip")

# --- find the koreader dir on the device ---
$kodir = (& ssh @sshArgs "for d in /mnt/us/koreader /mnt/base-us/koreader /mnt/onboard/.adds/koreader; do [ -d `$d/plugins ] && echo `$d && break; done").Trim()
if (-not $kodir) { throw "Couldn't find koreader/plugins on the device. Is KOReader installed under /mnt/us ?" }
Write-Host "device koreader dir: $kodir"

$target = "$kodir/plugins/magium.koplugin"

# --- wipe + push fresh (rm -rf is busybox; sftp put -r for the copy) ---
& ssh @sshArgs "rm -rf '$target'"
$batch = "put -r `"$($dest -replace '\\','/')`" `"$kodir/plugins/`""
$batch | & sftp -P $Port -o StrictHostKeyChecking=accept-new "$User@$Ip" | Out-Null

# --- verify by file count ---
$got = [int](& ssh @sshArgs "find '$target' -type f | wc -l").Trim()
Write-Host "device now has $got / $want files"
if ($got -lt $want) { Write-Host 'INCOMPLETE — rerun.' -ForegroundColor Red; exit 1 }
Write-Host 'OK — restart KOReader on the Kindle to load it.'
