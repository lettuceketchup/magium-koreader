# Deploy magium.koplugin to a USB-connected Kindle (MTP/WPD, no drive letter).
#
# MTP CopyHere does NOT reliably replace an existing file — it silently keeps the
# old one (this shipped stale code to the device for weeks before it was caught).
# So this script DELETES the device plugin folder first, then copies fresh, then
# VERIFIES every file by size and fails loudly on any mismatch.
#
#   powershell -File tools/deploy-kindle.ps1
#   powershell -File tools/deploy-kindle.ps1 -KeepOld   # skip the wipe (fast, unsafe)

param([switch]$KeepOld)

$ErrorActionPreference = 'Stop'
$repo  = Split-Path $PSScriptRoot -Parent
$src   = Join-Path $repo 'magium.koplugin'
$stage = Join-Path $env:TEMP 'magium-kindle-stage\magium.koplugin'

# --- stage: repo plugin minus spec/ and dotfiles ---
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -Recurse "$src\*" $stage
Remove-Item -Recurse -Force "$stage\spec" -ErrorAction SilentlyContinue
Get-ChildItem $stage -Force -Filter '.*' | Remove-Item -Recurse -Force
$staged = Get-ChildItem -Recurse -File $stage
Write-Host "staged $($staged.Count) runtime files"

# --- locate koreader/plugins on the device ---
$sh = New-Object -ComObject Shell.Application
$kindle = $sh.Namespace(17).Items() | Where-Object { $_.Name -like 'Kindle*' }
if (-not $kindle) { throw 'No Kindle found under This PC - connect USB and unlock the device.' }
function child($folder, $name) { ($folder.Items() | Where-Object { $_.Name -eq $name }).GetFolder }
$plugins = child (child (child $kindle.GetFolder 'Internal Storage') 'koreader') 'plugins'
if (-not $plugins) { throw 'koreader/plugins not found on device.' }

# --- wipe the old plugin folder (unless -KeepOld) ---
$existing = ($plugins.Items() | Where-Object { $_.Name -eq 'magium.koplugin' })
if ($existing -and -not $KeepOld) {
  Write-Host 'deleting old koreader/plugins/magium.koplugin ...'
  $delVerb = $existing.Verbs() | Where-Object { $_.Name -replace '&','' -eq 'Delete' }
  if ($delVerb) { $delVerb.DoIt() } else { $existing.InvokeVerb('delete') }
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    if (-not ($plugins.Items() | Where-Object { $_.Name -eq 'magium.koplugin' })) { break }
  }
  if ($plugins.Items() | Where-Object { $_.Name -eq 'magium.koplugin' }) {
    throw "Could not delete koreader/plugins/magium.koplugin over MTP. Delete it by hand in File Explorer (This PC > Kindle > Internal Storage > koreader > plugins), then rerun."
  }
}

$mag = ($plugins.Items() | Where-Object { $_.Name -eq 'magium.koplugin' }).GetFolder
if (-not $mag) { $plugins.NewFolder('magium.koplugin'); Start-Sleep -Milliseconds 400; $mag = child $plugins 'magium.koplugin' }

$FOF = 16 -bor 512 -bor 1024   # no-confirm, no-dir-confirm, no-error-ui

# recurse: mirror stage into the matching device folder, creating subfolders
function push($localDir, $devFolder) {
  foreach ($f in Get-ChildItem $localDir -File) {
    $devFolder.CopyHere($sh.Namespace($localDir).ParseName($f.Name), $FOF)
  }
  foreach ($d in Get-ChildItem $localDir -Directory) {
    $sub = ($devFolder.Items() | Where-Object { $_.Name -eq $d.Name }).GetFolder
    if (-not $sub) { $devFolder.NewFolder($d.Name); Start-Sleep -Milliseconds 400; $sub = ($devFolder.Items() | Where-Object { $_.Name -eq $d.Name }).GetFolder }
    push $d.FullName $sub
  }
}
push $stage $mag

# --- wait for async copies to settle ---
function count($folder) {
  $n = 0
  foreach ($i in $folder.Items()) { if ($i.IsFolder) { $n += count $i.GetFolder } else { $n++ } }
  $n
}
$want = $staged.Count
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 2
  if ((count $mag) -ge $want) { break }
}

# --- VERIFY by size (this is the check that was missing) ---
function sizes($folder, $prefix) {
  $h = @{}
  foreach ($i in $folder.Items()) {
    $rel = if ($prefix) { "$prefix/$($i.Name)" } else { $i.Name }
    if ($i.IsFolder) { (sizes $i.GetFolder $rel).GetEnumerator() | ForEach-Object { $h[$_.Key] = $_.Value } }
    else { $h[$rel] = [int64]$i.ExtendedProperty('System.Size') }
  }
  $h
}
$dev = sizes $mag ''
$bad = @()
foreach ($f in $staged) {
  $rel = $f.FullName.Substring($stage.Length + 1) -replace '\\','/'
  if (-not $dev.ContainsKey($rel)) { $bad += "MISSING  $rel" }
  elseif ($dev[$rel] -ne $f.Length) { $bad += ("SIZE     {0}  (repo {1} != device {2})" -f $rel, $f.Length, $dev[$rel]) }
}
if ($bad.Count) {
  Write-Host "`nDEPLOY VERIFY FAILED - $($bad.Count) file(s):" -ForegroundColor Red
  $bad | ForEach-Object { Write-Host "  $_" }
  Write-Host "`nDelete This PC > Kindle > Internal Storage > koreader > plugins > magium.koplugin in File Explorer, then rerun." -ForegroundColor Yellow
  exit 1
}
Write-Host "verified $want / $want files match by size"
Write-Host 'OK - restart KOReader on the Kindle to load it.'
