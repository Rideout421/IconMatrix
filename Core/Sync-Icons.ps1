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
$KeypassSource = $config.keypassIcons                        # E:\...\Keypass_Icons
$RepoSource    = Join-Path $RepoRoot $config.sourceIcons     # source-icons\
$ProcessedDir  = Join-Path $RepoRoot $config.processedIcons  # processed-icons\

Write-Host "DEBUG RepoRoot     = [$RepoRoot]"
Write-Host "DEBUG KeypassSrc   = [$KeypassSource]"
Write-Host "DEBUG sourceIcons  = [$RepoSource]"
Write-Host "DEBUG processedDir = [$ProcessedDir]"

# =========================
# VALIDATION
# =========================
if (-not (Test-Path $KeypassSource)) {
    throw "Keypass folder missing -> $KeypassSource"
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
# STEP 1: SYNC KEYPASS -> SOURCE-ICONS
# Copy-SourceIcons handles image validation, canonical
# naming, and dedup - we just wire the correct Source/Destination
# =========================
Write-Host "`n[STEP 1] Keypass -> source-icons" -ForegroundColor Yellow

. "$RepoRoot\pipeline\Copy-SourceIcons.ps1"

Copy-SourceIcons `
    -Source      $KeypassSource `
    -Destination $RepoSource `
    -DryRun:$DryRun

# =========================
# STEP 2: NORMALIZATION (clean source-icons)
# =========================
Write-Host "`n[STEP 2] Normalization" -ForegroundColor Yellow

. "$RepoRoot\core\Invoke-IconNormalization.ps1"
Invoke-IconNormalization -Path $RepoSource -DryRun:$DryRun

# =========================
# STEP 3: TRANSFORMATION (source-icons -> processed-icons)
# =========================
Write-Host "`n[STEP 3] Transformation" -ForegroundColor Yellow

. "$RepoRoot\core\Convert-Icons.ps1"

Convert-Icons `
    -Path   $RepoSource `
    -Output $ProcessedDir `
    -DryRun:$DryRun

# =========================
# DONE - Publish-IconMatrix handles registry + theme + vsix
# =========================
Write-Host "`nDONE`n" -ForegroundColor Green