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
#>
param(
    [switch]$DryRun,
    [switch]$Install
)

$ErrorActionPreference = "Stop"

# =========================
# ROOT
# =========================
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

# =========================
# CONFIG
# =========================
$configPath = Join-Path $RepoRoot "config\paths.json"
if (-not (Test-Path $configPath)) {
    throw "Missing config: $configPath"
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

$Processed    = Join-Path $RepoRoot $config.processedIcons
$RegistryPath = Join-Path $RepoRoot $config.registry
$ThemePath    = Join-Path $RepoRoot $config.theme

# =========================
# HEADER
# =========================
Write-Host "`n=== ICONMATRIX PUBLISH START ===`n" -ForegroundColor Cyan
Write-Host "DryRun : $DryRun"
Write-Host "Install: $Install`n"

# =========================
# STEP 1: SYNC
# =========================
Write-Host "[SYNC] Running icon sync..." -ForegroundColor Yellow

& "$RepoRoot\core\Sync-Icons.ps1" -DryRun:$DryRun

# =========================
# DRY RUN STOP (CRITICAL)
# =========================
if ($DryRun) {
    Write-Host "`n[DRYRUN] Pipeline stopped after sync`n" -ForegroundColor Yellow
    return
}

# =========================
# VALIDATION
# =========================
if (-not (Test-Path $Processed)) {
    throw "Processed folder missing: $Processed"
}

# =========================
# STEP 2: REGISTRY
# =========================
Write-Host "[REGISTRY] Building registry..." -ForegroundColor Yellow

& "$RepoRoot\pipeline\Invoke-RegistryBuild.ps1" `
    -Path $Processed `
    -OutputPath $RegistryPath `
    -DryRun:$false

# =========================
# STEP 3: THEME
# =========================
Write-Host "[THEME] Building theme..." -ForegroundColor Yellow

& "$RepoRoot\core\Invoke-IconMatrixTheme.ps1" `
    -RegistryPath $RegistryPath `
    -IconsPath $Processed `
    -ThemeFilePath $ThemePath `
    -DryRun:$false

# =========================
# STEP 4: PACKAGE
# =========================
Write-Host "[PACKAGE] Building VSIX..." -ForegroundColor Yellow

npx @vscode/vsce package

# =========================
# STEP 5: INSTALL
# =========================
if ($Install) {
    Write-Host "[INSTALL] Installing extension..." -ForegroundColor Yellow

    $vsix = Get-ChildItem $RepoRoot -Filter "*.vsix" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $vsix) {
        throw "No VSIX found"
    }

    code --install-extension $vsix.FullName --force

    Write-Host "[OK] Installed: $($vsix.Name)" -ForegroundColor Green
}

# =========================
# FINAL OUTPUT (CLEAN)
# =========================
Write-Host ""

if ($Install) {
    Write-Host "=== BUILD + INSTALL COMPLETE ===" -ForegroundColor Green
}
else {
    Write-Host "=== BUILD COMPLETE ===" -ForegroundColor Cyan
}