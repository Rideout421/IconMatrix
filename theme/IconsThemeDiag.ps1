param(
    [string]$ThemePath
)

Write-Host "`n=== ICONMATRIX THEME DIAGNOSTIC ===`n" -ForegroundColor Cyan

# =========================
# AUTO-RESOLVE ROOT
# =========================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# assume: ...\IconMatrix\theme\IconsThemeDiag.ps1
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..")

# default theme path if not provided
if ([string]::IsNullOrWhiteSpace($ThemePath)) {
    $ThemePath = Join-Path $RepoRoot "theme\icons-theme.json"
}

Write-Host "RepoRoot   : $RepoRoot"
Write-Host "ThemePath  : $ThemePath"
Write-Host ""

if (-not (Test-Path $ThemePath)) {
    throw "Theme file not found: $ThemePath"
}

$json = Get-Content $ThemePath -Raw | ConvertFrom-Json

# =========================
# STRUCTURE CHECK
# =========================
Write-Host "1. STRUCTURE CHECK" -ForegroundColor Yellow

$hasIconDefs = $null -ne $json.iconDefinitions
$hasFileExt  = $null -ne $json.fileExtensions
$hasFileName = $null -ne $json.fileNames

Write-Host "iconDefinitions : $hasIconDefs"
Write-Host "fileExtensions  : $hasFileExt"
Write-Host "fileNames       : $hasFileName"

# =========================
# DEFAULT ICON ANALYSIS
# =========================
Write-Host "`n2. DEFAULT ICON USAGE" -ForegroundColor Yellow

$defaultCount = 0

if ($json.fileExtensions) {
    $defaultCount += ($json.fileExtensions.PSObject.Properties | Where-Object Value -eq "default-icon").Count
}

if ($json.fileNames) {
    $defaultCount += ($json.fileNames.PSObject.Properties | Where-Object Value -eq "default-icon").Count
}

Write-Host "default-icon occurrences: $defaultCount"

# =========================
# ICON DEFINITIONS CHECK
# =========================
Write-Host "`n3. ICON DEFINITIONS CHECK" -ForegroundColor Yellow

if ($json.iconDefinitions) {
    $iconCount = ($json.iconDefinitions.PSObject.Properties).Count
    Write-Host "iconDefinitions count: $iconCount"

    $hasDefault = $json.iconDefinitions.PSObject.Properties.Name -contains "default-icon"
    Write-Host "default-icon defined: $hasDefault"
} else {
    Write-Host "iconDefinitions MISSING" -ForegroundColor Red
}

# =========================
# SAMPLE OUTPUT
# =========================
Write-Host "`n4. SAMPLE MAPPINGS" -ForegroundColor Yellow

if ($json.fileExtensions) {
    Write-Host "`nfileExtensions sample:"
    $json.fileExtensions.PSObject.Properties |
        Select-Object -First 10 |
        ForEach-Object { Write-Host "  $($_.Name) -> $($_.Value)" }
}

if ($json.fileNames) {
    Write-Host "`nfileNames sample:"
    $json.fileNames.PSObject.Properties |
        Select-Object -First 10 |
        ForEach-Object { Write-Host "  $($_.Name) -> $($_.Value)" }
}

# =========================
# HEALTH SUMMARY
# =========================
Write-Host "`n5. HEALTH SUMMARY" -ForegroundColor Yellow

if (-not $hasIconDefs) {
    Write-Host "❌ CRITICAL: Missing iconDefinitions" -ForegroundColor Red
}

if ($defaultCount -gt 20) {
    Write-Host "❌ WARNING: Excessive default-icon usage ($defaultCount)" -ForegroundColor Red
}

if ($hasIconDefs -and $defaultCount -eq 0) {
    Write-Host "✅ Theme structure looks healthy" -ForegroundColor Green
}

Write-Host "`n=== END DIAGNOSTIC ===`n"