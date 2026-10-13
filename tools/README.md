# Factorio Mod Packager/Installer

Requires PowerShell 7 and Factorio 2.1.

From the repository root, create the ignored local configuration:

```powershell
Copy-Item .factorio-local.example.json .factorio-local.json
```

Set `factorio_root` to your Factorio installation. The `CCQF_FACTORIO_ROOT` environment variable overrides this value.

## Package

```powershell
& .\tools\package-mod.ps1
```

By default, ZIPs are written to `.build/release/` and files are staged in `.build/release-staging/`, relative to the repository root regardless of the current working directory. Override either location with `-DestinationDirectory` or `-StagingDirectory`.

The script reads the name/version from `info.json` and creates a ZIP with the required `<name>_<version>/` root. Its allowlist includes runtime and prototype Lua files, settings, locale, release metadata, README, license, and thumbnail, plus optional mod resource directories. Tools, client checklists, tests, Git metadata, and local game state are excluded.

Staging and output directories must be beneath `.build/`. Repackaging replaces the matching staging directory and removes older ZIPs for this mod from the chosen output directory. Generated files are ignored by Git.

## Install into the configured game

```powershell
& .\tools\install-local.ps1 -WhatIf
& .\tools\install-local.ps1
```

The installer rebuilds the package using the same `.build/release/` and `.build/release-staging/` directories as the packager.

`-WhatIf` builds and validates the package locally and previews the installation without changing the game installation. The real command copies the ZIP into `<factorio_root>\mods`, replaces the same version, and removes older ZIPs for this mod. It leaves unpacked mod folders and the game's mod list unchanged. Close Factorio first and enable the mod in its Mods menu if needed.
