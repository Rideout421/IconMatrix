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

    Write-Host "`n=== ICONMATRIX THEME BUILD ===" -ForegroundColor Cyan
    Write-Host "[DEBUG] RegistryPath  = $RegistryPath"
    Write-Host "[DEBUG] IconsPath     = $IconsPath"
    Write-Host "[DEBUG] ThemeFilePath = $ThemeFilePath"

    if ($DryRun) {
        Write-Host "[DRYRUN] Exiting before execution" -ForegroundColor Yellow
        return
    }

    # -------------------------
    # VALIDATION
    # -------------------------
    if (-not (Test-Path $RegistryPath)) { throw "Registry missing: $RegistryPath" }
    if (-not (Test-Path $IconsPath))    { throw "Icons folder missing: $IconsPath" }

    # -------------------------
    # LOAD REGISTRY
    # -------------------------
    $registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json
    if (-not $registry) { throw "Registry JSON invalid or empty" }

    Write-Host "[DEBUG] Registry loaded OK"

    # -------------------------
    # RESOLVE PATHS
    # -------------------------
    $ThemeFilePath = [System.IO.Path]::GetFullPath($ThemeFilePath)
    $outDir        = Split-Path -Parent $ThemeFilePath

    # The iconPath in the theme JSON must be relative to the theme file location.
    # Theme lives at:  theme/icons-theme.json
    # Icons live at:   processed-icons/
    # So relative path from theme/ to processed-icons/ is: ../processed-icons/
    # Using Uri-based relative path for PS 5.1 compatibility (no GetRelativePath)
    $IconsPath     = [System.IO.Path]::GetFullPath($IconsPath)
    $fromUri       = [Uri]("$outDir\")
    $toUri         = [Uri]($IconsPath)
    $iconRelPrefix = $fromUri.MakeRelativeUri($toUri).ToString() -replace '%20',' '

    Write-Host "[DEBUG] Icon relative prefix = $iconRelPrefix"

    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # -------------------------
    # SCAN ICON FILES
    # -------------------------
    $icons = Get-ChildItem -Path $IconsPath -Recurse -File -Filter "*.png" -ErrorAction SilentlyContinue

    Write-Host "[DEBUG] Icons found = $($icons.Count)"

    if ($icons.Count -eq 0) {
        Write-Host "[ERROR] No PNG files found - theme will be empty" -ForegroundColor Red
    }

    # -------------------------
    # BUILD iconDefinitions
    # Key:   "terraform-icon"
    # Value: { iconPath: "../processed-icons/terraform.png" }
    # -------------------------
    $iconDefinitions = [ordered]@{}

    foreach ($icon in ($icons | Sort-Object BaseName)) {
        $id  = "$($icon.BaseName.ToLower())-icon"
        # path relative to theme file
        $rel = "$iconRelPrefix/$($icon.Name)" -replace '//','/'
        $iconDefinitions[$id] = [ordered]@{ iconPath = $rel }
    }

    Write-Host "[DEBUG] iconDefinitions built = $($iconDefinitions.Count)"

    # -------------------------
    # BUILD fileExtensions + fileNames FROM REGISTRY
    # Registry (icons.json) is the flat format:
    #   fileExtensions: { "tf": "terraform-icon", "ps1": "ps1-icon" }
    #   fileNames:      { "Dockerfile": "docker-icon" }
    # -------------------------
    $fileExtensions  = [ordered]@{}
    $fileNames       = [ordered]@{}
    $mappedExt       = 0
    $mappedNames     = 0

    if ($registry.fileExtensions) {
        foreach ($p in $registry.fileExtensions.PSObject.Properties) {
            $iconId = $p.Value
            # Only include if the icon actually exists in our definitions
            if ($iconDefinitions.Contains($iconId)) {
                $fileExtensions[$p.Name] = $iconId
                $mappedExt++
            } else {
                Write-Host "[SKIP-EXT] '$($p.Name)' -> '$iconId' (icon not found)" -ForegroundColor DarkYellow
            }
        }
    }

    if ($registry.fileNames) {
        foreach ($p in $registry.fileNames.PSObject.Properties) {
            $iconId = $p.Value
            if ($iconDefinitions.Contains($iconId)) {
                $fileNames[$p.Name] = $iconId
                $mappedNames++
            } else {
                Write-Host "[SKIP-NAME] '$($p.Name)' -> '$iconId' (icon not found)" -ForegroundColor DarkYellow
            }
        }
    }

    Write-Host "[DEBUG] fileExtensions mapped = $mappedExt"
    Write-Host "[DEBUG] fileNames mapped      = $mappedNames"

    # -------------------------
    # DEFAULT ICON
    # Used for any file/folder with no specific mapping.
    # Prefer "general-icon", fall back to first available.
    # -------------------------
    $defaultIconId = if ($iconDefinitions.Contains("general-icon")) {
        "general-icon"
    } else {
        $iconDefinitions.Keys | Select-Object -First 1
    }

    Write-Host "[DEBUG] Default icon = $defaultIconId" -ForegroundColor Cyan

    # -------------------------
    # ASSEMBLE THEME
    # VS Code icon theme contract:
    #   iconDefinitions  - all icon definitions with iconPath
    #   fileExtensions   - extension -> iconId
    #   fileNames        - exact filename -> iconId
    #   file             - iconId string (default for any file)
    #   folder           - iconId string (default for any folder)
    #   folderExpanded   - iconId string (optional, open folder)
    # -------------------------
    $theme = [ordered]@{
        iconDefinitions = $iconDefinitions
        fileExtensions  = $fileExtensions
        fileNames       = $fileNames
        file            = $defaultIconId
        folder          = $defaultIconId
        folderExpanded  = $defaultIconId
    }

    # -------------------------
    # SERIALIZE + WRITE
    # -------------------------
    $json = $theme | ConvertTo-Json -Depth 50

    Write-Host "[DEBUG] JSON length = $($json.Length)"

    if ([string]::IsNullOrWhiteSpace($json)) { throw "JSON serialization produced empty output" }

    Set-Content -Path $ThemeFilePath -Value $json -Encoding UTF8 -Force -ErrorAction Stop

    if (-not (Test-Path $ThemeFilePath)) { throw "FILE NOT CREATED AFTER WRITE" }

    $size = (Get-Item $ThemeFilePath).Length
    Write-Host "[SUCCESS] Theme written ($size bytes) -> $ThemeFilePath" -ForegroundColor Green
}