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
param(
    [switch]$DryRun,
    [switch]$Install
)

$ErrorActionPreference = "Stop"

# =========================
# ROOT RESOLUTION
# =========================
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

# =========================
# CONFIG LOAD
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

if ($DryRun) {
    Write-Host "`n[DRYRUN] Sync complete - stopping pipeline`n" -ForegroundColor Yellow
    return
}

# =========================
# VALIDATION
# =========================
if (-not (Test-Path $Processed)) {
    throw "Processed folder missing: $Processed"
}

# =========================
# STEP 2: REGISTRY BUILD
# =========================
Write-Host "[REGISTRY] Building registry..." -ForegroundColor Yellow

& "$RepoRoot\pipeline\Invoke-RegistryBuild.ps1" `
    -Path $Processed `
    -OutputPath $RegistryPath `
    -DryRun:$false

# =========================
# STEP 3: INTELLIGENCE LAYER
# =========================
Write-Host "[INTEL] Applying icon intelligence..." -ForegroundColor Yellow

if (-not (Test-Path $RegistryPath)) {
    throw "Registry missing before intelligence step"
}

$registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json

$registry = & "$RepoRoot\core\Invoke-IconIntelligence.ps1" `
    -Registry $registry `
    -IconsPath $Processed `
    -DryRun:$false

$registry | ConvertTo-Json -Depth 20 | Set-Content $RegistryPath -Encoding UTF8

# =========================
# STEP 4: THEME
# =========================
Write-Host "[THEME] Building theme..." -ForegroundColor Yellow

& "$RepoRoot\core\Invoke-IconMatrixTheme.ps1" `
    -RegistryPath $RegistryPath `
    -IconsPath $Processed `
    -ThemeFilePath $ThemePath `
    -DryRun:$false

# =========================
# STEP 5: PACKAGE
# =========================
Write-Host "[PACKAGE] Building VSIX..." -ForegroundColor Yellow

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw "npx is required for VSIX packaging"
}

npx @vscode/vsce package

# =========================
# STEP 6: INSTALL (OPTIONAL)
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

    Write-Host "[OK] Installed -> $($vsix.Name)" -ForegroundColor Green
}

# =========================
# FINAL OUTPUT
# =========================
if ($Install) {
    Write-Host "`n=== BUILD + INSTALL COMPLETE ===`n" -ForegroundColor Green
}
else {
    Write-Host "`n=== BUILD COMPLETE ===`n" -ForegroundColor Cyan
}