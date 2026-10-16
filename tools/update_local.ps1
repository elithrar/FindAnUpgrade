param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory=$true)][string]$BuildRoot,
    [string]$ClientRoot='C:\Program Files (x86)\World of Warcraft\_classic_beta_'
)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$build=[IO.Path]::GetFullPath($BuildRoot)
$addons=[IO.Path]::GetFullPath((Join-Path $ClientRoot 'Interface\AddOns'))
$target=[IO.Path]::GetFullPath((Join-Path $addons 'FindAnUpgrade'))
$settings=[IO.Path]::GetFullPath((Join-Path $ClientRoot 'WTF'))
$backup=[IO.Path]::GetFullPath((Join-Path $workspace ('.work\FindAnUpgrade-backup-'+$SourceCommit.Substring(0,8))))
$stage=[IO.Path]::GetFullPath((Join-Path $workspace ('.work\FindAnUpgrade-update-'+$SourceCommit.Substring(0,8))))
if ((Split-Path -Parent $target) -cne $addons -or (Split-Path -Leaf $target) -cne 'FindAnUpgrade') { throw 'Unsafe addon target.' }
foreach($path in @($build,$backup,$stage)) { if(!$path.StartsWith((Join-Path $workspace '.work\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe workspace target.' } }
if ((Test-Path -LiteralPath $backup) -or (Test-Path -LiteralPath $stage)) { throw 'Existing staging or backup must be inspected first.' }
function Assert-Closed { if (@(Get-Process -Name WowB -ErrorAction SilentlyContinue).Count) { throw 'Close Forever normally before updating; no reload or closure is forced.' } }
Assert-Closed
$exe=Get-Item -LiteralPath (Join-Path $ClientRoot 'WowB.exe')
if ($exe.VersionInfo.FileVersion -cne '1.60.1.70425') { throw 'Client build changed; verify matching contracts first.' }
$validation=Get-Content -Raw -LiteralPath (Join-Path $build 'dist\validation-evidence.json') | ConvertFrom-Json
if (!$validation.success -or (Get-Content -Raw -LiteralPath (Join-Path $build 'SOURCE-COMMIT')).Trim() -cne $SourceCommit) { throw 'Exact source verification is absent.' }
$sourceTree=(Get-Content -Raw -LiteralPath (Join-Path $build 'SOURCE-TREE')).Trim()
if ($sourceTree -cnotmatch '^[0-9a-f]{40}$') { throw 'Exact source tree is absent or invalid.' }
$package=Get-Content -Raw -LiteralPath (Join-Path $build 'dist\package-receipt.json') | ConvertFrom-Json
if ($package.addon -cne 'FindAnUpgrade' -or $package.interface -ne 16001 -or $package.version -notmatch '^\d+\.\d+\.\d+$') { throw 'Wrong addon package.' }
$receiptPath=Join-Path $workspace 'dist\FindAnUpgrade-installation-receipt.json'
$previous=Get-Content -Raw -LiteralPath $receiptPath | ConvertFrom-Json
if (!$previous.installed -or $previous.installationPath -cne $target) { throw 'Previous installation identity differs.' }
if ($previous.addonVersion -notmatch '^\d+\.\d+\.\d+$' -or [version]$package.version -le [version]$previous.addonVersion) { throw 'An update must increase the installed version.' }
$previousReceiptBytes=[IO.File]::ReadAllBytes($receiptPath)
$pendingReceipt=Join-Path $workspace ('dist\FindAnUpgrade-installation-'+$SourceCommit.Substring(0,8)+'.pending.json')
if (Test-Path -LiteralPath $pendingReceipt) { throw 'Existing pending receipt must be inspected first.' }
foreach($entry in $previous.installedFiles) {
    if ($entry.path.Contains('..') -or [IO.Path]::IsPathRooted($entry.path)) { throw 'Unsafe previous payload entry.' }
    $file=Get-Item -LiteralPath (Join-Path $target $entry.path)
    if ($file.Length -ne $entry.bytes -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.sha256) { throw 'Existing addon changed; preserve and inspect first.' }
}
if (@(Get-ChildItem -LiteralPath $target -Recurse -File -Force).Count -ne $previous.installedFiles.Count) { throw 'Unrecorded existing addon file.' }
$archiveName='FindAnUpgrade-'+$package.version+'.zip'
$archive=Join-Path $build ('dist\'+$archiveName)
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -cne $package.archives.$archiveName) { throw 'Archive hash differs.' }
Expand-Archive -LiteralPath $archive -DestinationPath $stage
foreach($entry in $package.payload) {
    if ($entry.path -notmatch '^FindAnUpgrade/[A-Za-z0-9_/.-]+$' -or $entry.path.Contains('..')) { throw 'Unsafe new payload entry.' }
    $file=Get-Item -LiteralPath (Join-Path $stage $entry.path)
    if ($file.Length -ne $entry.bytes -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.sha256) { throw 'Staged payload differs.' }
}
if (@(Get-ChildItem -LiteralPath $stage -Recurse -File -Force).Count -ne $package.payload.Count) { throw 'Unexpected staged file.' }
function Snapshot([string]$root,[bool]$excludeAddon) {
    $map=@{}
    foreach($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
        $relative=$file.FullName.Substring($root.Length).TrimStart('\')
        if ($excludeAddon -and $relative.StartsWith('FindAnUpgrade\',[StringComparison]::OrdinalIgnoreCase)) { continue }
        $map[$relative]=@{bytes=$file.Length;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
    return $map
}
function Assert-Same($before,$after,[string]$label) {
    if ($before.Count -ne $after.Count) { throw "$label count changed." }
    foreach($name in $before.Keys) { if (!$after.ContainsKey($name) -or $before[$name].bytes -ne $after[$name].bytes -or $before[$name].sha256 -cne $after[$name].sha256) { throw "$label changed: $name" } }
}
$beforeAddons=Snapshot $addons $true;$beforeSettings=Snapshot $settings $false
$beforeDirectories=@(Get-ChildItem -LiteralPath $addons -Directory | Select-Object -ExpandProperty Name | Sort-Object)
Assert-Closed
Copy-Item -LiteralPath $receiptPath -Destination (Join-Path $workspace ('dist\FindAnUpgrade-installation-'+$previous.addonVersion+'-receipt.json'))
# These resolved paths are bounded above; only this verified addon is moved.
Move-Item -LiteralPath $target -Destination $backup
$complete=$false
try {
    Copy-Item -LiteralPath (Join-Path $stage 'FindAnUpgrade') -Destination $addons -Recurse
    $installed=@()
    foreach($entry in $package.payload) {
        $relative=$entry.path.Substring('FindAnUpgrade/'.Length)
        $file=Get-Item -LiteralPath (Join-Path $target $relative)
        $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($file.Length -ne $entry.bytes -or $hash -cne $entry.sha256) { throw 'Installed payload differs.' }
        $installed+=@{path=$relative;bytes=$file.Length;sha256=$hash}
    }
    if (@(Get-ChildItem -LiteralPath $target -Recurse -File -Force).Count -ne $package.payload.Count) { throw 'Unexpected installed file.' }
    Assert-Same $beforeAddons (Snapshot $addons $true) 'Unrelated addons'
    Assert-Same $beforeSettings (Snapshot $settings $false) 'Saved settings'
    $afterDirectories=@(Get-ChildItem -LiteralPath $addons -Directory | Select-Object -ExpandProperty Name | Sort-Object)
    if (($beforeDirectories -join "`n") -cne ($afterDirectories -join "`n")) { throw 'Addon directories changed.' }
    $receipt=[ordered]@{installed=$true;installedAtUtc=[DateTime]::UtcNow.ToString('o');host=$env:COMPUTERNAME;sourceCommit=$SourceCommit;sourceTree=$sourceTree;branch='main';addonVersion=$package.version;clientBuild=$exe.VersionInfo.FileVersion;interface=16001;installationPath=$target;installedFiles=$installed;previousVersion=$previous.addonVersion;backupPath=$backup;previousInstalledFilesVerified=$previous.installedFiles.Count;unrelatedAddonFilesVerified=$beforeAddons.Count;unrelatedAddonDirectoriesVerified=$beforeDirectories.Count-1;originalSettingsFilesVerified=$beforeSettings.Count;unrelatedAddonsUnchanged=$true;originalSettingsUnchanged=$true;settingsWritten=$false;runningClientProcessesAtVerification=@(Get-Process -Name WowB -ErrorAction SilentlyContinue).Count;searchCommand='/fau';inGameValidationPerformed=$false;releasePublished=$false}
    $receipt | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $pendingReceipt -Encoding UTF8
    [IO.File]::Replace($pendingReceipt,$receiptPath,[NullString]::Value)
    $complete=$true
} finally {
    if (!$complete) {
        if ((Split-Path -Parent $target) -cne $addons -or (Split-Path -Leaf $target) -cne 'FindAnUpgrade') { throw 'Unsafe rollback target.' }
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        Move-Item -LiteralPath $backup -Destination $target
        try {
            $currentReceiptBytes=[IO.File]::ReadAllBytes($receiptPath)
            if ([Convert]::ToBase64String($currentReceiptBytes) -cne [Convert]::ToBase64String($previousReceiptBytes)) { [IO.File]::WriteAllBytes($receiptPath,$previousReceiptBytes) }
        } finally { if (Test-Path -LiteralPath $pendingReceipt) { Remove-Item -LiteralPath $pendingReceipt -Force } }
    }
}
[pscustomobject]$receipt | Select-Object installed,sourceCommit,addonVersion,installationPath,backupPath,unrelatedAddonsUnchanged,originalSettingsUnchanged | ConvertTo-Json
