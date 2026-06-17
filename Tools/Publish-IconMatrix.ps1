<#
===============================================================================
 ICONMATRIX PUBLISH ORCHESTRATOR
===============================================================================

Runs full build pipeline:
1. Sync icons
2. Build registry
3. Build theme
4. Package VS Code extension (vsix)
5. Optional install into VS Code

USAGE:

# Dry run (safe)
& (Join-Path $env:GIT_ROOT "IconMatrix\Tools\Publish-IconMatrix.ps1") -DryRun

# Full build
& (Join-Path $env:GIT_ROOT "IconMatrix\Tools\Publish-IconMatrix.ps1")

# Build + install
& (Join-Path $env:GIT_ROOT "IconMatrix\Tools\Publish-IconMatrix.ps1") -Install

===============================================================================
Pipeline:
1. Sync icons
2. Build registry
3. Build theme
4. Package VSIX
5. Optional install
===============================================================================
#>

param(
    [switch]$DryRun,
    [switch]$Install
)

$ErrorActionPreference = "Stop"

# =========================
# ROOT
# =========================
if (-not $env:GIT_ROOT) {
    throw "GIT_ROOT not set"
}

$RepoRoot = Join-Path $env:GIT_ROOT "IconMatrix"
$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)

if (-not (Test-Path $RepoRoot)) {
    throw "RepoRoot missing: $RepoRoot"
}

Set-Location $RepoRoot

# =========================
# CONFIG
# =========================
$configPath = Join-Path $RepoRoot "config\paths.json"

if (-not (Test-Path $configPath)) {
    throw "Missing config: $configPath"
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

# HARD validation (prevents null propagation)
foreach ($k in @("sourceIcons","processedIcons","registry","theme")) {
    if ([string]::IsNullOrWhiteSpace($config.$k)) {
        throw "CONFIG ERROR: '$k' is missing or empty"
    }
}

# =========================
# PATH RESOLUTION (CANONICAL)
# =========================
$SourceIcons  = Join-Path $RepoRoot $config.sourceIcons
$Processed    = Join-Path $RepoRoot $config.processedIcons
$RegistryPath = Join-Path $RepoRoot $config.registry
$ThemePath    = Join-Path $RepoRoot $config.theme

# =========================
# SAFETY CHECKS
# =========================
if (Test-Path $RegistryPath -PathType Container) {
    throw "FATAL: RegistryPath is a DIRECTORY but must be a FILE -> $RegistryPath"
}

if (-not (Test-Path $SourceIcons)) {
    throw "SourceIcons folder missing -> $SourceIcons"
}

# ensure registry and theme folders exist
New-Item -ItemType Directory -Path (Split-Path $RegistryPath -Parent) -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $ThemePath    -Parent) -Force | Out-Null

# =========================
# DEBUG
# =========================
Write-Host "`n=== ICONMATRIX DEBUG ===`n" -ForegroundColor Cyan
Write-Host "RepoRoot     : $RepoRoot"
Write-Host "SourceIcons  : $SourceIcons"
Write-Host "Processed    : $Processed"
Write-Host "Registry     : $RegistryPath"
Write-Host "Theme        : $ThemePath"
Write-Host ""

# =========================
# STEP 1 - SYNC
# =========================
Write-Host "[STEP 1] Sync icons" -ForegroundColor Yellow

$syncParams = @{ InputPath = $SourceIcons }

$syncCmd = Get-Command "$RepoRoot\core\Sync-Icons.ps1"
if ($syncCmd.Parameters.ContainsKey("OutputPath")) {
    $syncParams.OutputPath = $Processed
}
if ($DryRun) { $syncParams.DryRun = $true }

& "$RepoRoot\core\Sync-Icons.ps1" @syncParams

if (-not (Test-Path $Processed)) {
    throw "SYNC FAILED: Processed folder not created -> $Processed"
}

# =========================
# STEP 2 - REGISTRY
# FIX: dot-source to load the function, then call it
# =========================
Write-Host "`n[STEP 2] Registry build" -ForegroundColor Yellow

. "$RepoRoot\pipeline\Invoke-RegistryBuild.ps1"

$MappingsPath = Join-Path $RepoRoot "config\mappings.json"

# =========================
# HARD SAFETY GUARDS (CRITICAL FIX)
# =========================
if ([string]::IsNullOrWhiteSpace($Processed)) {
    throw "Processed path is EMPTY - Sync step failed or returned invalid output"
}

if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
    throw "Registry path is EMPTY - config.registry is invalid"
}

if (-not (Test-Path $Processed)) {
    throw "Processed folder does not exist -> $Processed"
}

# Normalize (removes hidden whitespace / encoding issues)
$Processed    = $Processed.Trim()
$RegistryPath = $RegistryPath.Trim()

# =========================
# DEBUG (safe)
# =========================
Write-Host "DEBUG Processed = [$Processed]" -ForegroundColor Cyan
Write-Host "DEBUG Registry  = [$RegistryPath]" -ForegroundColor Cyan

# =========================
# BUILD PARAMS (STRICT)
# =========================
$registryParams = @{
    InputPath    = $Processed
    OutputPath   = $RegistryPath
    MappingsPath = $MappingsPath
}

if ($DryRun) {
    $registryParams.DryRun = $true
}

# FINAL GUARD BEFORE CALL (this is the real fix)
if ([string]::IsNullOrWhiteSpace($registryParams.InputPath) -or
    [string]::IsNullOrWhiteSpace($registryParams.OutputPath)) {
    throw "Registry parameters invalid - aborting pipeline"
}

Invoke-RegistryBuild @registryParams

# =========================
# STEP 3 - THEME
# FIX: dot-source to load the function, then call it
# =========================
Write-Host "`n[STEP 3] Theme build" -ForegroundColor Yellow

. "$RepoRoot\Core\Invoke-IconMatrixTheme.ps1"

Invoke-IconMatrixTheme `
    -RegistryPath $RegistryPath `
    -IconsPath    $Processed `
    -ThemeFilePath $ThemePath `
    -DryRun:$DryRun

# =========================
# STEP 4 - PACKAGE
# =========================
Write-Host "`n[STEP 4] VSIX package" -ForegroundColor Yellow

npx @vscode/vsce package

# =========================
# STEP 5 - INSTALL
# =========================
if ($Install) {
    Write-Host "`n[STEP 5] Install extension" -ForegroundColor Yellow

    $vsix = Get-ChildItem $RepoRoot -Filter "*.vsix" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $vsix) {
        throw "No VSIX file found"
    }

    code --install-extension $vsix.FullName --force
}

Write-Host "`n=== COMPLETE ===`n" -ForegroundColor Green