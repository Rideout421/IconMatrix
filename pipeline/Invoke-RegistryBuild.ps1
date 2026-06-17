function Invoke-RegistryBuild {
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [string]$MappingsPath,

        [switch]$DryRun
    )

    Write-Host "`n=== Registry Build (IconMatrix) ===" -ForegroundColor Cyan

    # ========================= VALIDATION =========================
    if ([string]::IsNullOrWhiteSpace($InputPath))  { throw "InputPath is empty" }
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw "OutputPath is empty" }

    if (-not [System.IO.Path]::IsPathRooted($InputPath)) {
        $InputPath = Join-Path $PSScriptRoot $InputPath
    }

    $resolvedInput = (Resolve-Path $InputPath -ErrorAction Stop).Path

    if (-not (Test-Path $resolvedInput)) { throw "Input folder not found: $resolvedInput" }

    if (Test-Path $OutputPath -PathType Container) {
        throw "OutputPath must be a FILE not a DIRECTORY: $OutputPath"
    }

    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # ========================= LOAD MAPPINGS =========================
    $extMappings        = @{}
    $fileNameMappings   = @{}
    $folderNameMappings = @{}

    if (-not [string]::IsNullOrWhiteSpace($MappingsPath) -and (Test-Path $MappingsPath)) {
        Write-Host "[INFO] Loading mappings: $MappingsPath" -ForegroundColor Cyan
        $mappingsJson = Get-Content $MappingsPath -Raw | ConvertFrom-Json

        if ($mappingsJson.extensions) {
            $mappingsJson.extensions.PSObject.Properties | ForEach-Object {
                $extMappings[$_.Name] = @($_.Value)
            }
        }

        if ($mappingsJson.fileNames) {
            $mappingsJson.fileNames.PSObject.Properties | ForEach-Object {
                $fileNameMappings[$_.Name] = @($_.Value)
            }
        }

        if ($mappingsJson.folderNames) {
            $mappingsJson.folderNames.PSObject.Properties | ForEach-Object {
                $folderNameMappings[$_.Name] = @($_.Value)
            }
        }

        Write-Host "[INFO] Extensions: $($extMappings.Count)  FileNames: $($fileNameMappings.Count)  FolderNames: $($folderNameMappings.Count)" -ForegroundColor Cyan
    } else {
        Write-Host "[WARN] No mappings file - using basename fallback" -ForegroundColor Yellow
    }

    # ========================= SCAN PNGS =========================
    $files = Get-ChildItem -Path $resolvedInput -Recurse -File -Filter "*.png"

    if (-not $files -or $files.Count -eq 0) { throw "No PNG files found: $resolvedInput" }

    Write-Host "[INFO] PNG files found: $($files.Count)" -ForegroundColor Cyan

    # ========================= BUILD REGISTRY =========================
    $iconDefinitions    = [ordered]@{}
    $fileExtensions     = [ordered]@{}
    $fileNames          = [ordered]@{}
    $folderNames        = [ordered]@{}
    $folderNamesExpanded= [ordered]@{}

    $basePath = (Get-Item $resolvedInput).FullName

    foreach ($file in ($files | Sort-Object BaseName)) {

        $base   = $file.BaseName.ToLower()
        $iconId = "$base-icon"
        $rel    = $file.FullName.Substring($basePath.Length).TrimStart('\','/') -replace '\\','/'

        # --- iconDefinitions: every PNG gets an entry ---
        $iconDefinitions[$iconId] = [ordered]@{
            iconPath = "./processed-icons/$rel"
        }

        # --- fileExtensions ---
        if ($extMappings.Contains($base)) {
            # Explicit mapping exists
            foreach ($ext in $extMappings[$base]) {
                $ext = $ext.ToLower().TrimStart('.')
                if (-not [string]::IsNullOrWhiteSpace($ext) -and -not $fileExtensions.Contains($ext)) {
                    $fileExtensions[$ext] = $iconId
                }
            }
        } elseif (-not $extMappings.Contains($base)) {
            # No entry at all: auto-map basename as extension
            if (-not $fileExtensions.Contains($base)) {
                $fileExtensions[$base] = $iconId
            }
        }
        # Empty array [] = filename-only icon, skip extensions

        # --- fileNames ---
        if ($fileNameMappings.Contains($base)) {
            foreach ($fname in $fileNameMappings[$base]) {
                if (-not [string]::IsNullOrWhiteSpace($fname) -and -not $fileNames.Contains($fname)) {
                    $fileNames[$fname] = $iconId
                }
            }
        }

        # --- folderNames ---
        if ($folderNameMappings.Contains($base)) {
            foreach ($fname in $folderNameMappings[$base]) {
                if (-not [string]::IsNullOrWhiteSpace($fname) -and -not $folderNames.Contains($fname)) {
                    $folderNames[$fname]         = $iconId
                    $folderNamesExpanded[$fname]  = $iconId
                }
            }
        }
    }

    Write-Host "[INFO] iconDefinitions : $($iconDefinitions.Count)" -ForegroundColor Cyan
    Write-Host "[INFO] fileExtensions  : $($fileExtensions.Count)"  -ForegroundColor Cyan
    Write-Host "[INFO] fileNames       : $($fileNames.Count)"       -ForegroundColor Cyan
    Write-Host "[INFO] folderNames     : $($folderNames.Count)"     -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "[DRYRUN] No file written" -ForegroundColor Yellow
        return
    }

    # ========================= WRITE OUTPUT =========================
    $out = [ordered]@{
        iconDefinitions     = $iconDefinitions
        fileExtensions      = $fileExtensions
        fileNames           = $fileNames
        folderNames         = $folderNames
        folderNamesExpanded = $folderNamesExpanded
    }

    $json = $out | ConvertTo-Json -Depth 50

    if ([string]::IsNullOrWhiteSpace($json)) { throw "JSON serialization produced empty output" }

    Set-Content -Path $OutputPath -Value $json -Encoding UTF8
    Write-Host "[OK] Registry written -> $OutputPath" -ForegroundColor Green
}