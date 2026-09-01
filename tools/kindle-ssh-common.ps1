# Shared helpers for the kindle-ssh-*.ps1 scripts. Dot-source it:
#   . "$PSScriptRoot\kindle-ssh-common.ps1"
#
# State lives in tools/.kindle/ (gitignored):
#   id_ed25519 / id_ed25519.pub   one deploy keypair, reused for every device
#   devices/<name>.json           { name, host, port, user, koreader_dir } per Kindle

$script:KindleDir  = Join-Path $PSScriptRoot '.kindle'
$script:KeyPath    = Join-Path $script:KindleDir 'id_ed25519'
$script:DevicesDir = Join-Path $script:KindleDir 'devices'

function Initialize-KindleKey {
  New-Item -ItemType Directory -Force -Path $script:DevicesDir | Out-Null
  if (Test-Path "$script:KeyPath.pub") { return }
  Write-Host "generating deploy keypair -> $script:KeyPath"
  # Windows OpenSSH: '""' is how you pass an empty passphrase (a bare '' becomes a stray arg)
  & ssh-keygen -t ed25519 -f $script:KeyPath -N '""' -C 'magium-koreader-deploy' -q
  if (-not (Test-Path "$script:KeyPath.pub")) { throw 'ssh-keygen did not produce a key' }
}

function Get-KindleDevice {
  param([string]$Name)
  $files = @(Get-ChildItem $script:DevicesDir -Filter '*.json' -ErrorAction SilentlyContinue)
  if ($Name) {
    $f = $files | Where-Object { $_.BaseName -eq $Name }
    if (-not $f) { throw "no device config tools/.kindle/devices/$Name.json - run kindle-ssh-setup.ps1 -Name $Name first" }
  } elseif ($files.Count -eq 0) {
    throw 'no device configs in tools/.kindle/devices/ - run kindle-ssh-setup.ps1 -Name <name> first'
  } elseif ($files.Count -gt 1) {
    throw "multiple device configs - pass -Name <$(($files.BaseName) -join '|')>"
  } else {
    $f = $files[0]
  }
  $d = Get-Content $f.FullName -Raw | ConvertFrom-Json
  $d | Add-Member -NotePropertyName _path -NotePropertyValue $f.FullName -Force -PassThru
}

function Save-KindleDevice {
  param($Device)
  $p = if ($Device.PSObject.Properties['_path'] -and $Device._path) { $Device._path }
       else { Join-Path $script:DevicesDir "$($Device.name).json" }
  $Device | Select-Object name, host, port, user, koreader_dir |
    ConvertTo-Json | Set-Content -Encoding utf8 $p
}

function Get-KindleSshArgs {
  param($Device)
  @('-i', $script:KeyPath, '-p', "$($Device.port)",
    '-o', 'IdentitiesOnly=yes', '-o', 'BatchMode=yes',
    '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=8',
    "$($Device.user)@$($Device.host)")
}

# Probe the device. On success, updates $Device.koreader_dir in place from what's
# actually on the device. Returns @{ Ok = [bool]; Output = [string[]] }.
function Test-KindleSsh {
  param($Device, [switch]$Quiet)
  if (-not $Device.host) { throw "device '$($Device.name)' has no host - kindle-ssh-test.ps1 -Name $($Device.name) -Ip <addr>" }
  $probe = 'echo MAGIUM_SSH_OK; for d in ' + $Device.koreader_dir +
           ' /mnt/us/koreader /mnt/base-us/koreader /mnt/onboard/.adds/koreader; do ' +
           '[ -d "$d/plugins" ] && echo "KODIR=$d" && break; done'
  $out = & ssh @(Get-KindleSshArgs $Device) $probe 2>&1 | ForEach-Object { "$_" }
  $ok = ($LASTEXITCODE -eq 0) -and ($out -match 'MAGIUM_SSH_OK')
  if (-not $Quiet) { $out | ForEach-Object { Write-Host "  $_" } }
  if ($ok) {
    $kodir = ($out | Select-String '^KODIR=(.+)$').Matches.Groups[1].Value
    if ($kodir) { $Device.koreader_dir = $kodir.Trim() }
  }
  @{ Ok = $ok; Output = $out }
}
