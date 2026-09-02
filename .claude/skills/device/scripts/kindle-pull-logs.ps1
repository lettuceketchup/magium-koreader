# Pull crash.log + the koreader/magium/ state dir off the Kindle for a post-mortem.
# Use after a device bug report, before theorizing about the cause.
#
#   powershell -File .claude/skills/device/scripts/kindle-pull-logs.ps1 -Name paperwhite
#
# Lands everything in a timestamped dir under %TEMP% and prints the path + a
# grep of crash.log for magium / error / traceback lines. -Ip <addr> works ad
# hoc without a saved device config. -Out <dir> overrides the destination.

param(
  [string]$Name = 'paperwhite',
  [string]$Ip,
  [string]$Out
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path
. "$repo\tools\kindle-ssh-common.ps1"

$dev = Get-KindleDevice -Name $Name
if ($Ip) { $dev.host = $Ip }

$r = Test-KindleSsh -Device $dev -Quiet
if (-not $r.Ok) {
  $r.Output | ForEach-Object { Write-Host "  $_" }
  throw "SSH not reachable - see the device skill, or run tools/kindle-ssh-test.ps1 -Name $($dev.name)"
}
$kodir = $dev.koreader_dir
Write-Host "device koreader dir: $kodir"

if (-not $Out) {
  $Out = Join-Path $env:TEMP ("magium-devlogs-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$sshArgs = Get-KindleSshArgs $dev

# --- crash.log ---
& ssh @sshArgs "cat '$kodir/crash.log'" | Set-Content -Encoding utf8 (Join-Path $Out 'crash.log')

# --- koreader/magium/ (absent if the game never ran on this device) ---
$hasMagium = (& ssh @sshArgs "[ -d '$kodir/magium' ] && echo yes || echo no").Trim()
if ($hasMagium -eq 'yes') {
  $destFwd = $Out.Replace([char]92, [char]47)
  $batchFile = Join-Path $env:TEMP 'magium-pull-batch.txt'
  [IO.File]::WriteAllText($batchFile, ('get -r "{0}/magium" "{1}/"' -f $kodir, $destFwd) + "`n", (New-Object Text.UTF8Encoding($false)))
  & sftp -i $KeyPath -P $dev.port -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -b $batchFile "$($dev.user)@$($dev.host)" | Out-Null
} else {
  Write-Host "no koreader/magium/ on device (game may never have run here)"
}

Write-Host ''
Write-Host "pulled to: $Out" -ForegroundColor Green
Get-ChildItem -Recurse -File $Out | ForEach-Object { Write-Host "  $($_.FullName.Substring($Out.Length + 1))" }

$crash = Join-Path $Out 'crash.log'
if ((Test-Path $crash) -and (Get-Item $crash).Length -gt 0) {
  Write-Host ''
  Write-Host '=== crash.log: magium / error / traceback lines (last 40) ===' -ForegroundColor Yellow
  Select-String -Path $crash -Pattern 'magium|error|traceback|luajit' | Select-Object -Last 40 | ForEach-Object { $_.Line }
} else {
  Write-Host ''
  Write-Host 'crash.log is empty - no hard error logged (a layout/stuck-widget bug can still be real).'
}
