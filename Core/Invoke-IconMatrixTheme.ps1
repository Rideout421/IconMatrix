function Invoke-IconMatrixTheme {
    param(
        [string]$RegistryPath,
        [string]$IconsPath,
        [string]$ThemeFilePath,
        [switch]$DryRun
    )

    Write-Host "=== IconMatrix Compiler Starting ==="

    # -------------------------
    # DRY RUN GUARD (CRITICAL)
    # -------------------------
    if ($DryRun) {
        Write-Host "[DRYRUN] Theme compilation skipped" -ForegroundColor Yellow
        Write-Host "[DRYRUN] Registry: $RegistryPath"
        Write-Host "[DRYRUN] Icons: $IconsPath"
        Write-Host "[DRYRUN] Output: $ThemeFilePath"
        return
    }

    # -------------------------
    # VALIDATION
    # -------------------------
    if (-not (Test-Path $RegistryPath)) {
        throw "Registry file not found: $RegistryPath"
    }

    if (-not (Test-Path $IconsPath)) {
        throw "Icons path not found: $IconsPath"
    }

    # -------------------------
    # LOAD REGISTRY
    # -------------------------
    $registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json

    $theme = @{
        iconDefinitions = @{}
        fileExtensions  = @{}
        fileNames       = @{}
        folder          = @{}
        file            = @{}
    }

    # -------------------------
    # BUILD ICON DEFINITIONS
    # -------------------------
    Get-ChildItem $IconsPath -Filter *.png | ForEach-Object {
        $name = $_.BaseName
        $theme.iconDefinitions[$name] = @{
            iconPath = "./processed-icons/$($_.Name)"
        }
    }

    # -------------------------
    # MAP REGISTRY
    # -------------------------
    foreach ($entry in $registry.PSObject.Properties) {

        $iconName = $entry.Name
        $data = $entry.Value

        if ($data.extensions) {
            foreach ($ext in $data.extensions) {
                $theme.fileExtensions[$ext] = $iconName
            }
        }

        if ($data.files) {
            foreach ($file in $data.files) {
                $theme.fileNames[$file] = $iconName
            }
        }
    }

    # -------------------------
    # ENSURE OUTPUT DIR
    # -------------------------
    $dir = Split-Path $ThemeFilePath -Parent

    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # -------------------------
    # WRITE OUTPUT
    # -------------------------
    $json = $theme | ConvertTo-Json -Depth 20

    $json | Out-File $ThemeFilePath -Encoding UTF8

    Write-Host "[OK] Theme compiled -> $ThemeFilePath"
}