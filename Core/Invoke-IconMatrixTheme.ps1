function Invoke-IconMatrixTheme {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryPath,

        [Parameter(Mandatory)]
        [string]$IconsPath,

        [Parameter(Mandatory)]
        [string]$ThemeFilePath,

        [switch]$DryRun
    )

    Write-Host "`n=== ICONMATRIX THEME DEBUG START ===" -ForegroundColor Cyan

    Write-Host "[DEBUG] RegistryPath   = $RegistryPath"
    Write-Host "[DEBUG] IconsPath      = $IconsPath"
    Write-Host "[DEBUG] ThemeFilePath  = $ThemeFilePath"

    # -------------------------
    # DRY RUN
    # -------------------------
    if ($DryRun) {
        Write-Host "[DRYRUN] Exiting before execution" -ForegroundColor Yellow
        return
    }

    # -------------------------
    # VALIDATION
    # -------------------------
    if (-not (Test-Path $RegistryPath)) {
        throw "Registry missing: $RegistryPath"
    }

    if (-not (Test-Path $IconsPath)) {
        throw "Icons missing: $IconsPath"
    }

    # -------------------------
    # LOAD REGISTRY
    # -------------------------
    $registryRaw = Get-Content $RegistryPath -Raw
    $registry = $registryRaw | ConvertFrom-Json

    if (-not $registry) {
        throw "Registry JSON invalid"
    }

    Write-Host "[DEBUG] Registry loaded OK"

    # -------------------------
    # FORCE OUTPUT PATH
    # -------------------------
    $ThemeFilePath = [System.IO.Path]::GetFullPath($ThemeFilePath)
    $outDir = Split-Path -Parent $ThemeFilePath

    Write-Host "[DEBUG] Output directory = $outDir"

    if (-not (Test-Path $outDir)) {
        Write-Host "[DEBUG] Creating output directory..."
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # -------------------------
    # LOAD ICONS (CRITICAL DEBUG POINT)
    # -------------------------
    $icons = Get-ChildItem -Path $IconsPath -Recurse -File -Filter *.png -ErrorAction SilentlyContinue

    Write-Host "[DEBUG] Icons found = $($icons.Count)"

    if ($icons.Count -eq 0) {
        Write-Host "[ERROR] NO ICONS FOUND - theme will be empty" -ForegroundColor Red
    }

    # -------------------------
    # BUILD THEME OBJECT
    # -------------------------
    $theme = @{
        iconDefinitions = @{}
        fileExtensions  = @{}
        fileNames       = @{}
        folder          = @{}
        file            = @{}
    }

    foreach ($icon in $icons) {
        $id = "$($icon.BaseName)-icon"

        $theme.iconDefinitions[$id] = @{
            iconPath = "../processed-icons/$($icon.Name)"
        }
    }

    Write-Host "[DEBUG] iconDefinitions = $($theme.iconDefinitions.Count)"

    # -------------------------
    # MAP REGISTRY
    # -------------------------
    if ($registry.fileNames) {
        foreach ($p in $registry.fileNames.PSObject.Properties) {
            $theme.fileNames[$p.Name] = $p.Value
        }
    }

    if ($registry.fileExtensions) {
        foreach ($p in $registry.fileExtensions.PSObject.Properties) {
            $theme.fileExtensions[$p.Name] = $p.Value
        }
    }

    Write-Host "[DEBUG] fileNames = $($theme.fileNames.Count)"
    Write-Host "[DEBUG] fileExtensions = $($theme.fileExtensions.Count)"

    # -------------------------
    # SERIALIZE JSON
    # -------------------------
    $json = $theme | ConvertTo-Json -Depth 50

    Write-Host "[DEBUG] JSON length = $($json.Length)"

    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "JSON generation failed (empty output)"
    }

    # -------------------------
    # WRITE FILE (CRITICAL SECTION)
    # -------------------------
    Write-Host "[DEBUG] Writing file -> $ThemeFilePath" -ForegroundColor Yellow

    try {
        Set-Content -Path $ThemeFilePath -Value $json -Encoding UTF8 -Force -ErrorAction Stop
    }
    catch {
        throw "WRITE FAILED: $($_.Exception.Message)"
    }

    # -------------------------
    # VERIFY
    # -------------------------
    if (-not (Test-Path $ThemeFilePath)) {
        throw "FILE NOT CREATED AFTER WRITE"
    }

    $size = (Get-Item $ThemeFilePath).Length

    Write-Host "[SUCCESS] Theme created successfully ($size bytes)" -ForegroundColor Green
    Write-Host "[SUCCESS] Output -> $ThemeFilePath`n" -ForegroundColor Green
}