#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$DestinationDirectory = (Join-Path $PSScriptRoot "..\.build\release"),

    [string]$StagingDirectory = (Join-Path $PSScriptRoot "..\.build\release-staging")
)

$ErrorActionPreference = "Stop"

function Test-DescendantPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $rootPrefix = $Root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
        [System.IO.Path]::DirectorySeparatorChar
    return $Path.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
}

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$buildRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot ".build"))
$destinationRoot = [System.IO.Path]::GetFullPath($DestinationDirectory)
$stagingRoot = [System.IO.Path]::GetFullPath($StagingDirectory)

if (-not (Test-DescendantPath -Path $destinationRoot -Root $buildRoot) -or
    -not (Test-DescendantPath -Path $stagingRoot -Root $buildRoot)) {
    throw "Package staging and output must remain under .build."
}

$modInfoPath = Join-Path $projectRoot "info.json"
if (-not (Test-Path -LiteralPath $modInfoPath -PathType Leaf)) {
    throw "Required release file is missing: info.json"
}
$modInfo = Get-Content -LiteralPath $modInfoPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($modInfo.name) -or
    [string]::IsNullOrWhiteSpace($modInfo.version)) {
    throw "info.json must define non-empty name and version values."
}

if ($modInfo.name -notmatch '^[a-zA-Z0-9_-]+$' -or
    $modInfo.version -notmatch '^\d+\.\d+\.\d+$') {
    throw "info.json must define a valid mod name and three-part numeric version."
}

$packageName = "$($modInfo.name)_$($modInfo.version)"
$packageRoot = [System.IO.Path]::GetFullPath((Join-Path $stagingRoot $packageName))
$packageZip = [System.IO.Path]::GetFullPath((Join-Path $destinationRoot "$packageName.zip"))
if (-not (Test-DescendantPath -Path $packageRoot -Root $stagingRoot) -or
    -not (Test-DescendantPath -Path $packageZip -Root $destinationRoot)) {
    throw "Resolved package paths escaped .build."
}
if ($destinationRoot.Equals($packageRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    (Test-DescendantPath -Path $destinationRoot -Root $packageRoot)) {
    throw "Package output must not be inside the staging package directory."
}

New-Item -ItemType Directory -Path $destinationRoot -Force -WhatIf:$false | Out-Null
New-Item -ItemType Directory -Path $stagingRoot -Force -WhatIf:$false | Out-Null
if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force -WhatIf:$false
}

$archivePrefix = "$($modInfo.name)_"
$existingArchives = Get-ChildItem -LiteralPath $destinationRoot -File | Where-Object {
    $_.Extension.Equals(".zip", [System.StringComparison]::OrdinalIgnoreCase) -and
    $_.Name.StartsWith($archivePrefix, [System.StringComparison]::OrdinalIgnoreCase)
}
foreach ($archive in $existingArchives) {
    Remove-Item -LiteralPath $archive.FullName -Force -WhatIf:$false
}

New-Item -ItemType Directory -Path $packageRoot -Force -WhatIf:$false | Out-Null

$requiredRootFiles = @(
    "control.lua",
    "data-final-fixes.lua",
    "settings.lua",
    "info.json",
    "LICENSE",
    "README.md"
)
$optionalRootFiles = @(
    "data.lua",
    "data-updates.lua",
    "settings-updates.lua",
    "settings-final-fixes.lua",
    "changelog.txt",
    "thumbnail.png"
)

foreach ($relativePath in $requiredRootFiles) {
    $source = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required release file is missing: $relativePath"
    }
    Copy-Item -LiteralPath $source -Destination $packageRoot -WhatIf:$false
}
foreach ($relativePath in $optionalRootFiles) {
    $source = Join-Path $projectRoot $relativePath
    if (Test-Path -LiteralPath $source -PathType Leaf) {
        Copy-Item -LiteralPath $source -Destination $packageRoot -WhatIf:$false
    }
}

$requiredDirectories = @("locale")
$optionalDirectories = @("graphics", "migrations", "prototypes", "scripts")
foreach ($relativePath in $requiredDirectories) {
    $source = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw "Required release directory is missing: $relativePath"
    }
    Copy-Item -LiteralPath $source -Destination $packageRoot -Recurse -WhatIf:$false
}
foreach ($relativePath in $optionalDirectories) {
    $source = Join-Path $projectRoot $relativePath
    if (Test-Path -LiteralPath $source -PathType Container) {
        Copy-Item -LiteralPath $source -Destination $packageRoot -Recurse -WhatIf:$false
    }
}

$developmentNamePattern = '(?i)(test|harness|fixture|generator)'
$developmentDirectoryPattern = '(?i)(^|\\)(tests?|fixtures?)(\\|$)'
$packagedFiles = Get-ChildItem -LiteralPath $packageRoot -Recurse -File
foreach ($file in $packagedFiles) {
    $relativePath = [System.IO.Path]::GetRelativePath($packageRoot, $file.FullName)
    if ($file.Name -match $developmentNamePattern -or
        $relativePath -match $developmentDirectoryPattern) {
        throw "Release package contains a development artifact: $relativePath"
    }
}

Compress-Archive -LiteralPath $packageRoot -DestinationPath $packageZip `
    -CompressionLevel Optimal -WhatIf:$false

[pscustomobject]@{
    ModName = [string]$modInfo.name
    Version = [string]$modInfo.version
    PackageName = $packageName
    PackageRoot = $packageRoot
    ZipPath = $packageZip
}
