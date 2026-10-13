#Requires -Version 7.0
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
param()

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$factorioRootInput = $env:CCQF_FACTORIO_ROOT
if ([string]::IsNullOrWhiteSpace($factorioRootInput)) {
    $localConfigPath = Join-Path $projectRoot ".factorio-local.json"
    if (Test-Path -LiteralPath $localConfigPath -PathType Leaf) {
        $localConfig = Get-Content -LiteralPath $localConfigPath -Raw | ConvertFrom-Json
        $factorioRootInput = $localConfig.factorio_root
    }
}
if ([string]::IsNullOrWhiteSpace($factorioRootInput)) {
    throw "Set factorio_root in .factorio-local.json or define CCQF_FACTORIO_ROOT."
}

$factorioRoot = [System.IO.Path]::GetFullPath($factorioRootInput)
$factorioExe = Join-Path $factorioRoot "bin\x64\factorio.exe"
$factorioData = Join-Path $factorioRoot "data"
if (-not (Test-Path -LiteralPath $factorioExe -PathType Leaf) -or
    -not (Test-Path -LiteralPath $factorioData -PathType Container)) {
    throw "The configured factorio_root is not a Factorio installation: $factorioRoot"
}

$package = & (Join-Path $PSScriptRoot "package-mod.ps1")

$modsRoot = [System.IO.Path]::GetFullPath((Join-Path $factorioRoot "mods"))
$destinationZip = [System.IO.Path]::GetFullPath((Join-Path $modsRoot "$($package.PackageName).zip"))
$modsPrefix = $modsRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
    [System.IO.Path]::DirectorySeparatorChar
if (-not $destinationZip.StartsWith($modsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to install outside the configured Factorio mods directory: $destinationZip"
}

$staleArchives = @()
if (Test-Path -LiteralPath $modsRoot -PathType Container) {
    $archivePrefix = "$($package.ModName)_"
    $staleArchives = @(Get-ChildItem -LiteralPath $modsRoot -File | Where-Object {
        $_.Extension.Equals(".zip", [System.StringComparison]::OrdinalIgnoreCase) -and
        $_.Name.StartsWith($archivePrefix, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $_.FullName.Equals($destinationZip, [System.StringComparison]::OrdinalIgnoreCase)
    })
}

$action = "Install packaged mod and remove $($staleArchives.Count) stale version ZIP(s)"
if ($PSCmdlet.ShouldProcess($destinationZip, $action)) {
    New-Item -ItemType Directory -Path $modsRoot -Force | Out-Null
    Copy-Item -LiteralPath $package.ZipPath -Destination $destinationZip -Force
    foreach ($archive in $staleArchives) {
        Remove-Item -LiteralPath $archive.FullName -Force
    }
    Write-Output "Installed $destinationZip"
}
else {
    Write-Output "Created $($package.ZipPath); installation would remove $($staleArchives.Count) stale ZIP(s)."
}
