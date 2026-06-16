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
    # LOAD ICONS
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
            iconPath = "processed-icons/$($icon.Name)"
        }
    }

    Write-Host "[DEBUG] iconDefinitions = $($theme.iconDefinitions.Count)"

    # -------------------------
    # MAP REGISTRY (Supports BOTH formats)
    # -------------------------
    $mappedExtensions = 0
    $mappedNames = 0

    # Case 1: Original mappings.json format (with "extensions" and "fileNames" containing arrays)
    if ($registry.extensions) {
        Write-Host "[DEBUG] Using original mappings.json format (extensions + fileNames arrays)" -ForegroundColor Cyan

        if ($registry.extensions) {
            foreach ($group in $registry.extensions.PSObject.Properties) {
                $iconId = "$($group.Name)-icon"
                if ($theme.iconDefinitions.ContainsKey($iconId)) {
                    foreach ($ext in $group.Value) {
                        $theme.fileExtensions[$ext] = $iconId
                        $mappedExtensions++
                    }
                }
            }
        }

        if ($registry.fileNames) {
            foreach ($group in $registry.fileNames.PSObject.Properties) {
                $iconId = "$($group.Name)-icon"
                if ($theme.iconDefinitions.ContainsKey($iconId)) {
                    foreach ($name in $group.Value) {
                        $theme.fileNames[$name] = $iconId
                        $mappedNames++
                    }
                }
            }
        }
    }
    # Case 2: Flat format (generated icons.json with fileExtensions/fileNames already processed)
    elseif ($registry.fileExtensions -or $registry.fileNames) {
        Write-Host "[DEBUG] Using flat registry format" -ForegroundColor Cyan

        if ($registry.fileExtensions) {
            foreach ($p in $registry.fileExtensions.PSObject.Properties) {
                $theme.fileExtensions[$p.Name] = $p.Value
                $mappedExtensions++
            }
        }
        if ($registry.fileNames) {
            foreach ($p in $registry.fileNames.PSObject.Properties) {
                $theme.fileNames[$p.Name] = $p.Value
                $mappedNames++
            }
        }
    }

    Write-Host "[DEBUG] fileExtensions mapped = $mappedExtensions"
    Write-Host "[DEBUG] fileNames mapped = $mappedNames"

    # -------------------------
    # SET DEFAULTS (Critical for icons to show at all)
    # -------------------------
    $defaultIcon = "general-icon"

    if (-not $theme.iconDefinitions.ContainsKey($defaultIcon)) {
        $defaultIcon = $theme.iconDefinitions.Keys | Select-Object -First 1
        Write-Host "[WARN] 'general-icon' not found, using fallback: $defaultIcon" -ForegroundColor Yellow
    }

    if ($defaultIcon) {
        $theme.file = $defaultIcon
        $theme.folder = $defaultIcon
        Write-Host "[DEBUG] Default file/folder icon set to: $defaultIcon" -ForegroundColor Green
    } else {
        Write-Host "[WARN] No default icon could be set" -ForegroundColor Yellow
    }

    # -------------------------
    # SERIALIZE JSON
    # -------------------------
    $json = $theme | ConvertTo-Json -Depth 50

    Write-Host "[DEBUG] JSON length = $($json.Length)"

    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "JSON generation failed (empty output)"
    }

    # -------------------------
    # WRITE FILE
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