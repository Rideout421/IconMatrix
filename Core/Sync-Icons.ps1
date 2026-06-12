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
$config = Get-Content $configPath -Raw | ConvertFrom-Json

if (-not $config) {
    throw "CONFIG FAILED TO LOAD"
}

Write-Host "DEBUG RepoRoot = [$RepoRoot]"
Write-Host "DEBUG sourceIcons = [$($config.sourceIcons)]"

# =========================
# CORE PATHS (FIXED)
# =========================

$RepoSource = Join-Path $RepoRoot $config.sourceIcons

if ([string]::IsNullOrWhiteSpace($RepoSource)) {
    throw "RepoSource resolved to NULL"
}

# IMPORTANT FIX: never trust caller InputPath blindly
$ProcessedDir = Join-Path $RepoRoot $config.processedIcons

# Only override if explicitly passed AND valid
if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    $ProcessedDir = $InputPath
}

$RegistryPath = Join-Path $RepoRoot $config.registry
$ThemePath    = Join-Path $RepoRoot $config.theme
$LogPath      = Join-Path $RepoRoot $config.logs

# =========================
# VALIDATION (DO NOT REMOVE)
# =========================
if (-not (Test-Path $RepoSource)) {
    throw "Source folder missing -> $RepoSource"
}

# THIS is the root cause you hit earlier
if (-not $DryRun -and -not (Test-Path $ProcessedDir)) {
    throw "Processed folder missing -> $ProcessedDir"
}

# =========================
# STEP 1: INGESTION
# =========================
& "$RepoRoot\pipeline\Copy-SourceIcons.ps1" `
    -Source $RepoSource `
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
    -Output $ProcessedDir `
    -DryRun:$DryRun

# =========================
# STEP 4: REGISTRY
# =========================
& "$RepoRoot\pipeline\Invoke-RegistryBuild.ps1" `
    -InputPath $ProcessedDir `
    -OutputPath $RegistryPath `
    -DryRun:$DryRun

# =========================
# STEP 5: THEME
# =========================
& "$RepoRoot\core\Invoke-IconMatrixTheme.ps1" `
    -RegistryPath $RegistryPath `
    -IconsPath $ProcessedDir `
    -ThemeFilePath $ThemePath `
    -DryRun:$DryRun

# =========================
# STEP 6: REPORT
# =========================
& "$RepoRoot\utils\Invoke-ReviewReport.ps1" `
    -LogPath $LogPath `
    -DryRun:$DryRun

Write-Host "`nDONE`n" -ForegroundColor Green