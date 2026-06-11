<#
================================================================================
 ICON SYNC PIPELINE
================================================================================
#>

param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if (-not $DryRun) {
    Write-Host "LIVE MODE ENABLED - changes will be written" -ForegroundColor Red
}

# =========================
# SELF-HEALING CONTEXT
# =========================
$ScriptPath = $PSCommandPath
$RepoRoot   = Split-Path -Parent (Split-Path -Parent $ScriptPath)

Set-Location $RepoRoot

$configPath = Join-Path $RepoRoot "config\paths.json"

if (-not (Test-Path $configPath)) {
    throw "Config file not found: $configPath"
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

Write-Host "DEBUG RepoRoot = [$RepoRoot]" -ForegroundColor Cyan
Write-Host "DEBUG sourceIcons = [$($config.sourceIcons)]" -ForegroundColor Cyan
Write-Host "DEBUG RepoSource BEFORE JOIN = [$RepoSource]" -ForegroundColor Cyan

# =========================
# SAFE PATH RESOLUTION
# =========================

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    throw "RepoRoot is NULL - script execution context broken"
}

if ([string]::IsNullOrWhiteSpace($config.sourceIcons)) {
    throw "config.sourceIcons is missing"
}

$RepoSource = Join-Path -Path $RepoRoot -ChildPath $config.sourceIcons
$Processed  = Join-Path -Path $RepoRoot -ChildPath $config.processedIcons
$RegistryPath = Join-Path -Path $RepoRoot -ChildPath $config.registry
$ThemePath    = Join-Path -Path $RepoRoot -ChildPath $config.theme
$LogPath      = Join-Path -Path $RepoRoot -ChildPath $config.logs

# =========================
# HARD VALIDATION (CRITICAL)
# =========================

if ([string]::IsNullOrWhiteSpace($Processed)) {
    throw "processedIcons is missing or empty in config"
}

if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
    throw "registry path is missing or empty in config"
}

# =========================
# SAFETY CHECKS
# =========================
if (-not (Test-Path $RepoSource)) {
    throw "Source folder missing -> $RepoSource"
}

if (-not $DryRun -and -not (Test-Path $Processed)) {
    throw "Processed folder missing -> $Processed (run ingestion first or DryRun pipeline)"
}

# =========================
# STEP 1: INGESTION
# =========================
& "$RepoRoot\pipeline\Copy-SourceIcons.ps1" `
    -Source $Source `
    -Destination $RepoSource `
    -DryRun:$DryRun

# =========================
# STEP 2: NORMALIZATION
# =========================
& "$RepoRoot\core\Invoke-IconNormalization.ps1" `
    -Path $RepoSource `
    -DryRun:$DryRun

# =========================
# STEP 3: TRANSFORMATION
# =========================
& "$RepoRoot\core\Convert-Icons.ps1" `
    -Path $RepoSource `
    -Output $Processed `
    -DryRun:$DryRun

# =========================
# STAGE 4: REGISTRY BUILD
# =========================

if ([string]::IsNullOrWhiteSpace($Processed)) {
    throw "Processed path is NULL/EMPTY - check config or earlier pipeline stages"
}

Write-Host "[REGISTRY] Building registry..." -ForegroundColor Yellow

& "$RepoRoot\pipeline\Invoke-RegistryBuild.ps1" `
    -Path $Processed `
    -OutputPath $RegistryPath `
    -DryRun:$DryRun

# =========================
# STEP 5: THEME BUILD
# =========================
& "$RepoRoot\core\Invoke-IconMatrixTheme.ps1" `
    -RegistryPath $RegistryPath `
    -IconsPath $Processed `
    -ThemeFilePath $ThemePath `
    -DryRun:$DryRun

# =========================
# STEP 6: REPORT
# =========================
& "$RepoRoot\utils\Invoke-ReviewReport.ps1" `
    -LogPath $LogPath `
    -DryRun:$DryRun

Write-Host "`nDONE`n" -ForegroundColor Green