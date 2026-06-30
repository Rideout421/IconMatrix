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

# Full reset (wipes + re-fetches source icons) + build + install
& (Join-Path $env:GIT_ROOT "IconMatrix\Tools\Publish-IconMatrix.ps1") -FullReset -Install

===============================================================================
Pipeline:
0. Optional reset (-Reset / -FullReset)
1. Sync icons
2. Build registry
3. Build theme
4. Package VSIX
5. Optional install
===============================================================================
#>

param(
    [switch]$DryRun,
    [switch]$Install,
    [switch]$Reset,
    [switch]$FullReset
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
# STEP 0 - RESET (OPTIONAL)
# =========================
if ($Reset -or $FullReset) {
    Write-Host "`n[STEP 0] Reset IconMatrix" -ForegroundColor Yellow

    $resetScript = Join-Path $RepoRoot "scripts\Powershell\Maintenance\Reset-IconMatrix.ps1"

    if (-not (Test-Path $resetScript)) {
        throw "Reset script missing -> $resetScript"
    }

    $resetParams = @{ Confirm = $true }
    if ($FullReset) { $resetParams.FullReset = $true }

    & $resetScript @resetParams

    Write-Host "[OK] Reset complete" -ForegroundColor Green
}

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
# STEP 1.5 - AUTO MAPPINGS
# =========================
Write-Host "[STEP 1.5] Auto mapping generation" -ForegroundColor Yellow

$mappingInput  = $Processed
$mappingOutput = Join-Path $RepoRoot "config\mappings.auto.json"

. "$RepoRoot\pipeline\MappingGenerator.ps1"

Export-AutoMappings `
    -InputPath $mappingInput `
    -OutputPath $mappingOutput

if (-not (Test-Path $mappingOutput)) {
    throw "Auto mapping generation failed"
}

# =========================
# STEP 1.6 - SEMANTIC INFERENCE (FIXED PATHING)
# =========================
Write-Host "[STEP 1.6] Semantic inference" -ForegroundColor Yellow

$mappingOutput   = Join-Path $RepoRoot "config\mappings.auto.json"
$semanticOutput  = Join-Path $RepoRoot "config\semantic.map.json"
$baseMappings    = Join-Path $RepoRoot "config\mappings.json"

. "$RepoRoot\pipeline\Invoke-SemanticInference.ps1"

Invoke-SemanticInference `
    -MappingsPath $baseMappings `
    -AutoMappingsPath $mappingOutput `
    -OutputPath $semanticOutput

Write-Host "[OK] Semantic inference complete -> $semanticOutput" -ForegroundColor Green

# =========================
# STEP 2 - REGISTRY (HARD FIXED)
# =========================
Write-Host "`n[STEP 2] Registry build" -ForegroundColor Yellow

. "$RepoRoot\pipeline\Invoke-RegistryBuild.ps1"

$MappingsPath = Join-Path $RepoRoot "config\mappings.json"

# FORCE RESOLVE (eliminates scope + whitespace + null issues)
$inputPath  = [string]::Copy($Processed)
$outputPath = [string]::Copy($RegistryPath)

$inputPath  = $inputPath.Trim()
$outputPath = $outputPath.Trim()

Write-Host "Resolved InputPath  = [$inputPath]" -ForegroundColor Cyan
Write-Host "Resolved OutputPath = [$outputPath]" -ForegroundColor Cyan

# HARD STOP if invalid (prevents PowerShell binding crash)
if ([string]::IsNullOrWhiteSpace($inputPath)) {
    throw "InputPath resolved empty at STEP 2"
}

if ([string]::IsNullOrWhiteSpace($outputPath)) {
    throw "OutputPath resolved empty at STEP 2"
}

$registryParams = @{
    InputPath    = $inputPath
    OutputPath   = $outputPath
    MappingsPath = $MappingsPath
}

if ($DryRun) {
    $registryParams.DryRun = $true
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

    Write-Host "Installing: $($vsix.Name)" -ForegroundColor Cyan

    # Suppress Node.js deprecation warnings (DEP0169 etc.)
    $env:NODE_NO_WARNINGS = "1"

    code --install-extension $vsix.FullName --force

    # Clean up environment variable
    Remove-Item Env:NODE_NO_WARNINGS -ErrorAction SilentlyContinue

    Write-Host "Extension installed successfully." -ForegroundColor Green
}