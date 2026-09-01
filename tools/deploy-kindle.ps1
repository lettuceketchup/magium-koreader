# Deploy magium.koplugin to a USB-connected Kindle (MTP/WPD, no drive letter).
# Overlay copy via Shell.Application CopyHere with FOF_NOCONFIRMATION (16) so it
# never blocks on a replace/confirm dialog (InvokeVerb('delete') hangs headless).
#
# ponytail: overlay only — never removes device files. If a plugin file is ever
# DELETED from the repo, wipe koreader/plugins/magium.koplugin in Explorer once.
#
#   powershell -File tools/deploy-kindle.ps1

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
$want = (Get-ChildItem -Recurse -File $stage).Count
Write-Host "staged $want runtime files"

# --- locate koreader/plugins/magium.koplugin on the device ---
$sh = New-Object -ComObject Shell.Application
$kindle = $sh.Namespace(17).Items() | Where-Object { $_.Name -like 'Kindle*' }
if (-not $kindle) { throw 'No Kindle found under This PC — connect USB and unlock the device.' }
function child($folder, $name) { ($folder.Items() | Where-Object { $_.Name -eq $name }).GetFolder }
$plugins = child (child (child $kindle.GetFolder 'Internal Storage') 'koreader') 'plugins'
if (-not $plugins) { throw 'koreader/plugins not found on device.' }
$mag = ($plugins.Items() | Where-Object { $_.Name -eq 'magium.koplugin' }).GetFolder
if (-not $mag) { $plugins.NewFolder('magium.koplugin'); $mag = child $plugins 'magium.koplugin' }

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

# --- wait for the async copies to settle, then verify by file count ---
function count($folder) {
  $n = 0
  foreach ($i in $folder.Items()) { if ($i.IsFolder) { $n += count $i.GetFolder } else { $n++ } }
  $n
}
$got = 0
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 2
  $now = count $mag
  if ($now -eq $got -and $now -ge $want) { break }
  $got = $now
}
Write-Host "device now has $got / $want files"
if ($got -lt $want) { Write-Host 'INCOMPLETE — rerun (MTP copies can drop under load).'; exit 1 }
Write-Host 'OK — restart KOReader on the Kindle to load it.'
