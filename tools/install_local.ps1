param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory=$true)][string]$BuildRoot,
    [string]$ClientRoot='C:\Program Files (x86)\World of Warcraft\_classic_beta_'
)
$ErrorActionPreference='Stop'
$workspaceRoot=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$buildPath=[IO.Path]::GetFullPath($BuildRoot)
$addonRoot=[IO.Path]::GetFullPath((Join-Path $ClientRoot 'Interface\AddOns'))
$oldRoot=[IO.Path]::GetFullPath((Join-Path $addonRoot 'QuestBrief'))
$newRoot=[IO.Path]::GetFullPath((Join-Path $addonRoot 'FindAnUpgrade'))
$settingsRoot=[IO.Path]::GetFullPath((Join-Path $ClientRoot 'WTF'))
$backupRoot=[IO.Path]::GetFullPath((Join-Path $workspaceRoot ('.work\QuestBrief-0.1.7-backup-'+$SourceCommit.Substring(0,8))))
$stageRoot=[IO.Path]::GetFullPath((Join-Path $workspaceRoot ('.work\FindAnUpgrade-install-'+$SourceCommit.Substring(0,8))))
foreach ($target in @($oldRoot,$newRoot)) {
    if ((Split-Path -Parent $target) -cne $addonRoot) { throw 'Addon target escaped the approved directory.' }
}
foreach ($target in @($backupRoot,$stageRoot,$buildPath)) {
    if (!$target.StartsWith((Join-Path $workspaceRoot '.work\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Staging target escaped the workspace.' }
}
if ((Test-Path -LiteralPath $newRoot) -or (Test-Path -LiteralPath $backupRoot) -or (Test-Path -LiteralPath $stageRoot)) { throw 'A new installation, staging directory or backup already exists; inspect before replacing it.' }
$exe=Get-Item -LiteralPath (Join-Path $ClientRoot 'WowB.exe')
function Assert-ClientClosed {
    if (@(Get-Process -Name WowB -ErrorAction SilentlyContinue).Count) { throw 'Forever is running. Its unsaved settings cannot be migrated safely; close it normally before installing.' }
}
Assert-ClientClosed
if ($exe.VersionInfo.FileVersion -ne '1.60.1.70374') { throw 'The client build changed; verify matching contracts first.' }
$validation=Get-Content -Raw -LiteralPath (Join-Path $buildPath 'dist\validation-evidence.json') | ConvertFrom-Json
if (!$validation.success -or (Get-Content -Raw -LiteralPath (Join-Path $buildPath 'SOURCE-COMMIT')).Trim() -cne $SourceCommit) { throw 'The exact source commit has no passing build.' }
$sourceTree=(Get-Content -Raw -LiteralPath (Join-Path $buildPath 'SOURCE-TREE')).Trim()
if ($sourceTree -cnotmatch '^[0-9a-f]{40}$') { throw 'The exact source tree is absent or invalid.' }
$receiptPath=Join-Path $workspaceRoot 'dist\FindAnUpgrade-installation-receipt.json'
$pendingReceipt=Join-Path $workspaceRoot ('dist\FindAnUpgrade-installation-'+$SourceCommit.Substring(0,8)+'.pending.json')
if ((Test-Path -LiteralPath $receiptPath) -or (Test-Path -LiteralPath $pendingReceipt)) { throw 'Existing new-name receipt must be inspected before migration.' }
$package=Get-Content -Raw -LiteralPath (Join-Path $buildPath 'dist\package-receipt.json') | ConvertFrom-Json
if ($package.addon -cne 'FindAnUpgrade' -or $package.version -cne '0.1.8' -or $package.interface -ne 16001) { throw 'Wrong candidate package.' }
$zipPath=Join-Path $buildPath 'dist\FindAnUpgrade-0.1.8.zip'
if ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $package.archives.'FindAnUpgrade-0.1.8.zip') { throw 'Candidate archive differs from its receipt.' }
Expand-Archive -LiteralPath $zipPath -DestinationPath $stageRoot
foreach ($row in $package.payload) {
    if ($row.path -notmatch '^FindAnUpgrade/[A-Za-z0-9_/.-]+$' -or $row.path.Contains('..')) { throw 'Unsafe payload path.' }
    $file=Get-Item -LiteralPath (Join-Path $stageRoot $row.path)
    if ($file.Length -ne $row.bytes -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $row.sha256) { throw 'Extracted payload differs from its receipt.' }
}
if (@(Get-ChildItem -LiteralPath $stageRoot -Recurse -File -Force).Count -ne $package.payload.Count) { throw 'Unexpected archive payload.' }
$oldReceipt=Get-Content -Raw -LiteralPath (Join-Path $workspaceRoot 'dist\QuestBrief-installation-receipt.json') | ConvertFrom-Json
if ($oldReceipt.addonVersion -cne '0.1.7' -or $oldReceipt.installationPath -cne $oldRoot) { throw 'The expected previous installation receipt is absent.' }
foreach ($row in $oldReceipt.installedFiles) {
    if ($row.path.Contains('..') -or [IO.Path]::IsPathRooted($row.path)) { throw 'Unsafe previous payload path.' }
    $file=Get-Item -LiteralPath (Join-Path $oldRoot $row.path)
    if ($file.Length -ne $row.bytes -or (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -cne $row.sha256) { throw 'Previous addon files changed; preserve and inspect them first.' }
}
if (@(Get-ChildItem -LiteralPath $oldRoot -Recurse -File -Force).Count -ne $oldReceipt.installedFiles.Count) { throw 'Unrecorded previous addon files.' }
foreach ($name in @('QuestInsights','QuestTint')) { if (Test-Path -LiteralPath (Join-Path $addonRoot $name)) { throw 'Another active prototype must be inspected before installation.' } }
foreach ($file in Get-ChildItem -LiteralPath $settingsRoot -Recurse -File -Filter 'AddOns.txt') {
    if (Select-String -LiteralPath $file.FullName -Pattern '^(QuestBrief|FindAnUpgrade):\s*disabled\s*$' -Quiet) { throw 'An addon enablement opt-out requires explicit migration before installing.' }
}
function Snapshot([string]$root,[bool]$addons) {
    $result=@{}
    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
        $relative=$file.FullName.Substring($root.Length).TrimStart('\')
        if ($addons -and ($relative.StartsWith('QuestBrief\',[StringComparison]::OrdinalIgnoreCase) -or $relative.StartsWith('FindAnUpgrade\',[StringComparison]::OrdinalIgnoreCase))) { continue }
        $result[$relative]=@{bytes=$file.Length;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
    return $result
}
function Assert-Same($before,$after,[string]$label) {
    if ($before.Count -ne $after.Count) { throw "$label file count changed." }
    foreach ($name in $before.Keys) { if (!$after.ContainsKey($name) -or $before[$name].bytes -ne $after[$name].bytes -or $before[$name].sha256 -cne $after[$name].sha256) { throw "$label changed: $name" } }
}
$beforeAddons=Snapshot $addonRoot $true
$beforeSettings=Snapshot $settingsRoot $false
$directories=@(Get-ChildItem -LiteralPath $addonRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object)
$migrations=@()
foreach ($file in Get-ChildItem -LiteralPath $settingsRoot -Recurse -File -Filter 'QuestBrief.lua') {
    if ((Split-Path -Leaf $file.DirectoryName) -cne 'SavedVariables') { throw 'Unexpected old settings location.' }
    $target=Join-Path $file.DirectoryName 'FindAnUpgrade.lua'
    if (Test-Path -LiteralPath $target) { throw 'Existing FindAnUpgrade settings must be inspected; they will not be overwritten.' }
    $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    # Validate all files before moving an addon or writing any settings.
    python (Join-Path $PSScriptRoot 'migrate_settings.py') --source $file.FullName --target $target --expect-sha $hash --check-only
    if ($LASTEXITCODE -ne 0) { throw 'Old settings are not supported data-only Lua.' }
    $migrations+=@{source=$file.FullName;target=$target;sha256=$hash;bytes=$file.Length}
}
@{addonFiles=$beforeAddons;settingsFiles=$beforeSettings;addonDirectories=$directories;migrations=$migrations} | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $workspaceRoot 'dist\FindAnUpgrade-preinstall-manifest.json') -Encoding UTF8
Assert-ClientClosed
$createdSettings=@();$moved=$false;$installed=$false
try {
    foreach ($entry in $migrations) {
        python (Join-Path $PSScriptRoot 'migrate_settings.py') --source $entry.source --target $entry.target --expect-sha $entry.sha256
        if ($LASTEXITCODE -ne 0) { throw 'Settings migration failed.' }
        $createdSettings+=$entry
    }
    Assert-ClientClosed
    # Both absolute targets were validated above. Move only the verified addon.
    Move-Item -LiteralPath $oldRoot -Destination $backupRoot
    $moved=$true
    Copy-Item -LiteralPath (Join-Path $stageRoot 'FindAnUpgrade') -Destination $addonRoot -Recurse
    $installedFiles=@()
    foreach ($row in $package.payload) {
        $relative=$row.path.Substring('FindAnUpgrade/'.Length)
        $file=Get-Item -LiteralPath (Join-Path $newRoot $relative)
        $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($file.Length -ne $row.bytes -or $hash -cne $row.sha256) { throw 'Installed payload verification failed.' }
        $installedFiles+=@{path=$relative;bytes=$file.Length;sha256=$hash}
    }
    if (@(Get-ChildItem -LiteralPath $newRoot -Recurse -File -Force).Count -ne $package.payload.Count) { throw 'Unexpected installed payload.' }
    Assert-Same $beforeAddons (Snapshot $addonRoot $true) 'Unrelated addons'
    $afterSettings=Snapshot $settingsRoot $false
    foreach ($entry in $createdSettings) {
        if ((Get-FileHash -LiteralPath $entry.target -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry.sha256) { throw 'Migrated settings changed during installation.' }
        $afterSettings.Remove($entry.target.Substring($settingsRoot.Length).TrimStart('\'))
    }
    Assert-Same $beforeSettings $afterSettings 'Original saved settings'
    $afterDirectories=@(Get-ChildItem -LiteralPath $addonRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object)
    $expectedDirectories=@($directories | ForEach-Object { if ($_ -ceq 'QuestBrief') { 'FindAnUpgrade' } else { $_ } } | Sort-Object)
    if (($expectedDirectories -join "`n") -cne ($afterDirectories -join "`n")) { throw 'Addon directory inventory changed unexpectedly.' }
    $finalProcessCount=@(Get-Process -Name WowB -ErrorAction SilentlyContinue).Count
    $receipt=[ordered]@{installed=$true;installedAtUtc=[DateTime]::UtcNow.ToString('o');host=$env:COMPUTERNAME;sourceCommit=$SourceCommit;sourceTree=$sourceTree;branch='main';addonVersion='0.1.8';clientBuild=$exe.VersionInfo.FileVersion;interface=16001;installationPath=$newRoot;installedFiles=$installedFiles;previousVersion='0.1.7';backupPath=$backupRoot;previousInstalledFilesVerified=$oldReceipt.installedFiles.Count;unrelatedAddonFilesVerified=$beforeAddons.Count;unrelatedAddonDirectoriesVerified=$directories.Count-1;originalSettingsFilesVerified=$beforeSettings.Count;unrelatedAddonsUnchanged=$true;originalSettingsUnchanged=$true;settingsMigrations=$createdSettings;clientClosedBeforeMutations=$true;runningClientProcessesAtVerification=$finalProcessCount;searchCommand='/fau';optionsCommand='/fau opts';inGameValidationPerformed=$false;releasePublished=$false}
    $receipt | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $pendingReceipt -Encoding UTF8
    [IO.File]::Move($pendingReceipt,$receiptPath)
    $installed=$true
} finally {
    if (!$installed) {
        if ($moved) {
            if ((Split-Path -Parent $newRoot) -cne $addonRoot -or (Split-Path -Leaf $newRoot) -cne 'FindAnUpgrade') { throw 'Unsafe rollback target.' }
            if (Test-Path -LiteralPath $newRoot) { Remove-Item -LiteralPath $newRoot -Recurse -Force }
            if (Test-Path -LiteralPath $oldRoot) { throw 'Cannot restore over a newly created old-addon folder.' }
            Move-Item -LiteralPath $backupRoot -Destination $oldRoot
        }
        foreach ($entry in $createdSettings) {
            if ((Test-Path -LiteralPath $entry.target) -and (Get-FileHash -LiteralPath $entry.target -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $entry.sha256) { Remove-Item -LiteralPath $entry.target }
        }
        if (Test-Path -LiteralPath $pendingReceipt) { Remove-Item -LiteralPath $pendingReceipt -Force }
    }
}
[pscustomobject]$receipt | Select-Object installed,sourceCommit,addonVersion,installationPath,backupPath,unrelatedAddonsUnchanged,originalSettingsUnchanged | ConvertTo-Json
