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
if (-not $env:GIT_ROOT) {
    throw "GIT_ROOT environment variable is not set"
}

$RepoRoot = Join-Path $env:GIT_ROOT "IconMatrix"
$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)

if (-not (Test-Path $RepoRoot)) {
    throw "RepoRoot resolved but does not exist: $RepoRoot"
}
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
# =========================
# THEME PATH (HARD SAFE BUILD)
# =========================

$themeDir = Join-Path $RepoRoot "theme"

if (-not (Test-Path $themeDir)) {
    New-Item -ItemType Directory -Path $themeDir -Force | Out-Null
    Write-Host "[FIX] Created theme directory -> $themeDir" -ForegroundColor Yellow
}

$ThemePath = Join-Path $themeDir "icons-theme.json"

if ([string]::IsNullOrWhiteSpace($ThemePath)) {
    throw "ThemePath resolved as null/empty"
}

Write-Host "[DEBUG] ThemePath FINAL = $ThemePath" -ForegroundColor Cyan

if (-not $config) {
    throw "CONFIG FAILED TO LOAD (ConvertFrom-Json returned null)"
}

Write-Host "[DEBUG] config.registry = $($config.registry)" -ForegroundColor Cyan
Write-Host "[DEBUG] RepoRoot = $RepoRoot" -ForegroundColor Cyan

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
# STEP 3: INTELLIGENCE LAYER (SAFE PASS-THROUGH)
# =========================

$registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json

if (-not $registry) {
    throw "Registry is null"
}

# Ensure structure exists (DO NOT overwrite real data)
if (-not $registry.PSObject.Properties.Name.Contains("fileNames")) {
    $registry | Add-Member -NotePropertyName fileNames -NotePropertyValue @{} -Force
}

if (-not $registry.PSObject.Properties.Name.Contains("fileExtensions")) {
    $registry | Add-Member -NotePropertyName fileExtensions -NotePropertyValue @{} -Force
}

# SAFE merge (ONLY if needed)
function Merge-Hashtable {
    param($source)

    $ht = @{}

    if ($source) {
        foreach ($prop in $source.PSObject.Properties) {
            $ht[$prop.Name] = $prop.Value
        }
    }

    return $ht
}

if ($registry.fileNames -isnot [hashtable]) {
    $registry.fileNames = Merge-Hashtable $registry.fileNames
}

if ($registry.fileExtensions -isnot [hashtable]) {
    $registry.fileExtensions = Merge-Hashtable $registry.fileExtensions
}

# WRITE BACK (THIS IS WHAT ENABLES THE THEME STEP)
$registry | ConvertTo-Json -Depth 50 | Set-Content $RegistryPath -Encoding UTF8

###########################
Write-Host "[DEBUG] ThemePath RAW = $ThemePath"
Write-Host "[DEBUG] Test Parent Exists = $(Test-Path (Split-Path $ThemePath -Parent))"
###########################

# =========================
# STEP 4: THEME
# =========================
Write-Host "[THEME] Building theme..." -ForegroundColor Yellow

# HARD GUARDS
if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
    throw "[FATAL] RegistryPath is empty"
}

if ([string]::IsNullOrWhiteSpace($Processed)) {
    throw "[FATAL] Processed path is empty"
}

if ([string]::IsNullOrWhiteSpace($ThemePath)) {
    throw "[FATAL] ThemePath is empty"
}

# DEBUG (keep for now)
Write-Host "[DEBUG] RegistryPath = $RegistryPath"
Write-Host "[DEBUG] Processed = $Processed"
Write-Host "[DEBUG] ThemePath = $ThemePath"

# SINGLE CALL ONLY
& "$RepoRoot\Core\Invoke-IconMatrixTheme.ps1" `
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