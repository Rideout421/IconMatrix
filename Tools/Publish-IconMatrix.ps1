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
3. Apply intelligence layer
4. Build theme
5. Package VSIX
6. Optional install
===============================================================================
#>

<#
ICONMATRIX PUBLISH ORCHESTRATOR (STABLE + CONTRACT SAFE)
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
$SourceIcons = Join-Path $RepoRoot $config.sourceIcons
$Processed   = Join-Path $RepoRoot $config.processedIcons

# registry MUST be file
$RegistryPath = Join-Path $RepoRoot $config.registry

# theme file
$ThemePath = Join-Path $RepoRoot $config.theme

# =========================
# SAFETY CHECKS (CRITICAL)
# =========================
if (Test-Path $RegistryPath -PathType Container) {
    throw "FATAL: RegistryPath is a DIRECTORY but must be a FILE -> $RegistryPath"
}

if (-not (Test-Path $SourceIcons)) {
    throw "SourceIcons folder missing -> $SourceIcons"
}

# ensure registry folder exists
$RegistryFolder = Split-Path $RegistryPath -Parent
New-Item -ItemType Directory -Path $RegistryFolder -Force | Out-Null

# ensure theme folder exists
$ThemeFolder = Split-Path $ThemePath -Parent
New-Item -ItemType Directory -Path $ThemeFolder -Force | Out-Null

# =========================
# DEBUG (single block only)
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

$syncParams = @{
    InputPath = $SourceIcons
}

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
# =========================
Write-Host "`n[STEP 2] Registry build" -ForegroundColor Yellow

$registryParams = @{
    InputPath  = $Processed
    OutputPath = $RegistryPath
}

if ($DryRun) { $registryParams.DryRun = $true }

Write-Host "[DEBUG] Writing registry file -> $RegistryPath"

& "$RepoRoot\pipeline\Invoke-RegistryBuild.ps1" @registryParams

if (-not (Test-Path $RegistryPath)) {
    throw "REGISTRY FAILED: file not created -> $RegistryPath"
}

# =========================
# STEP 3 - THEME
# =========================
Write-Host "`n[STEP 3] Theme build" -ForegroundColor Yellow

& "$RepoRoot\Core\Invoke-IconMatrixTheme.ps1" `
    -RegistryPath $RegistryPath `
    -IconsPath $Processed `
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