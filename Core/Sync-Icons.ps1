param(
    [string]$InputPath,
    [string]$OutputPath,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$ScriptPath = $PSCommandPath
$RepoRoot   = Split-Path -Parent (Split-Path -Parent $ScriptPath)

Set-Location $RepoRoot

$configPath = Join-Path $RepoRoot "config\paths.json"
$config     = Get-Content $configPath -Raw | ConvertFrom-Json

if (-not $config) { throw "CONFIG FAILED TO LOAD" }

# =========================
# RESOLVE PATHS
# =========================

# ✅ UPDATED: single icon source now
$IconSource  = $config.Icons
$RepoSource  = Join-Path $RepoRoot $config.sourceIcons
$ProcessedDir = Join-Path $RepoRoot $config.processedIcons

Write-Host "DEBUG RepoRoot     = [$RepoRoot]"
Write-Host "DEBUG IconSource   = [$IconSource]"
Write-Host "DEBUG sourceIcons  = [$RepoSource]"
Write-Host "DEBUG processedDir = [$ProcessedDir]"

# =========================
# VALIDATION
# =========================
if (-not (Test-Path $IconSource)) {
    throw "Icons folder missing -> $IconSource"
}

if (-not (Test-Path $RepoSource)) {
    New-Item -ItemType Directory -Path $RepoSource -Force | Out-Null
    Write-Host "[INIT] Created source-icons folder" -ForegroundColor Cyan
}

if (-not $DryRun -and -not (Test-Path $ProcessedDir)) {
    New-Item -ItemType Directory -Path $ProcessedDir -Force | Out-Null
    Write-Host "[INIT] Created processed-icons folder" -ForegroundColor Cyan
}

# =========================
# STEP 1: ICON SOURCE -> SOURCE-ICONS
# =========================
Write-Host "`n[STEP 1] Icons -> source-icons" -ForegroundColor Yellow

. "$RepoRoot\pipeline\Copy-SourceIcons.ps1"

Copy-SourceIcons `
    -Source      $IconSource `
    -Destination $RepoSource `
    -DryRun:$DryRun

# =========================
# STEP 2: NORMALIZATION
# =========================
Write-Host "`n[STEP 2] Normalization" -ForegroundColor Yellow

. "$RepoRoot\core\Invoke-IconNormalization.ps1"
Invoke-IconNormalization -Path $RepoSource -DryRun:$DryRun

# =========================
# STEP 3: TRANSFORMATION
# =========================
Write-Host "`n[STEP 3] Transformation" -ForegroundColor Yellow

. "$RepoRoot\core\Convert-Icons.ps1"

Convert-Icons `
    -Path   $RepoSource `
    -Output $ProcessedDir `
    -DryRun:$DryRun

# =========================
# DONE
# =========================
Write-Host "`nDONE`n" -ForegroundColor Green