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

    # ========================= INPUT RESOLVE =========================
    if ([string]::IsNullOrWhiteSpace($InputPath)) { throw "InputPath is empty" }

    if (-not [System.IO.Path]::IsPathRooted($InputPath)) {
        $InputPath = Join-Path $PSScriptRoot $InputPath
    }

    $resolvedInput = (Resolve-Path $InputPath -ErrorAction Stop).Path

    if (-not (Test-Path $resolvedInput)) {
        throw "Input folder not found: $resolvedInput"
    }

    # ========================= OUTPUT VALIDATION =========================
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw "OutputPath is empty" }

    if (Test-Path $OutputPath -PathType Container) {
        throw "OutputPath must be a FILE, not a DIRECTORY: $OutputPath"
    }

    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # ========================= LOAD MAPPINGS =========================
    # Mappings tell us: icon basename -> file extensions + exact filenames
    # e.g. "terraform" -> extensions: [tf, tfvars], fileNames: [terraform.tfvars]
    # If no mappings file, we fall back to using the icon basename as the extension.

    $extMappings      = @{}   # iconBaseName -> [ext1, ext2, ...]
    $fileNameMappings = @{}   # iconBaseName -> [Dockerfile, .gitignore, ...]

    if (-not [string]::IsNullOrWhiteSpace($MappingsPath) -and (Test-Path $MappingsPath)) {
        Write-Host "[INFO] Loading mappings from: $MappingsPath" -ForegroundColor Cyan
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

        Write-Host "[INFO] Loaded $($extMappings.Count) extension mappings, $($fileNameMappings.Count) filename mappings" -ForegroundColor Cyan
    } else {
        Write-Host "[WARN] No mappings file found - falling back to basename-as-extension mode" -ForegroundColor Yellow
    }

    # ========================= SCAN PNG FILES =========================
    $files = Get-ChildItem -Path $resolvedInput -Recurse -File -Filter "*.png"

    if (-not $files -or $files.Count -eq 0) {
        throw "No PNG files found in: $resolvedInput"
    }

    Write-Host "[INFO] Found $($files.Count) PNG files" -ForegroundColor Cyan

    # ========================= BUILD REGISTRY =========================
    $iconDefinitions = [ordered]@{}
    $fileExtensions  = [ordered]@{}
    $fileNames       = [ordered]@{}

    $basePath = (Get-Item $resolvedInput).FullName

    foreach ($file in ($files | Sort-Object BaseName)) {

        $base     = $file.BaseName.ToLower()
        $iconId   = "$base-icon"
        $relPath  = $file.FullName.Substring($basePath.Length).TrimStart('\','/') -replace '\\','/'

        # --- iconDefinitions: always add every PNG ---
        $iconDefinitions[$iconId] = [ordered]@{
            iconPath = "../processed-icons/$relPath"
        }

        # --- fileExtensions: map via mappings file if available ---
        if ($extMappings.Contains($base) -and $extMappings[$base].Count -gt 0) {
            # Use explicit mappings
            foreach ($ext in $extMappings[$base]) {
                $ext = $ext.ToLower().TrimStart('.')
                if (-not [string]::IsNullOrWhiteSpace($ext) -and -not $fileExtensions.Contains($ext)) {
                    $fileExtensions[$ext] = $iconId
                    Write-Host "  [MAP] .$ext -> $iconId" -ForegroundColor DarkGreen
                }
            }
        } elseif (-not $extMappings.Contains($base)) {
            # No mapping entry at all: use basename as extension (fallback)
            # This means bicep.png -> .bicep automatically with zero config
            if (-not $fileExtensions.Contains($base)) {
                $fileExtensions[$base] = $iconId
                Write-Host "  [AUTO] .$base -> $iconId" -ForegroundColor DarkCyan
            }
        }
        # If mapping entry exists but extensions array is empty ([]) 
        # it means icon is filename-only (e.g. github, docker) - skip extensions

        # --- fileNames: map via mappings file ---
        if ($fileNameMappings.Contains($base)) {
            foreach ($fname in $fileNameMappings[$base]) {
                if (-not [string]::IsNullOrWhiteSpace($fname) -and -not $fileNames.Contains($fname)) {
                    $fileNames[$fname] = $iconId
                    Write-Host "  [FILE] $fname -> $iconId" -ForegroundColor DarkGreen
                }
            }
        }
    }

    # ========================= CONFLICT REPORT =========================
    Write-Host "`n[INFO] iconDefinitions : $($iconDefinitions.Count)" -ForegroundColor Cyan
    Write-Host "[INFO] fileExtensions  : $($fileExtensions.Count)"  -ForegroundColor Cyan
    Write-Host "[INFO] fileNames       : $($fileNames.Count)"       -ForegroundColor Cyan

    # ========================= DRY RUN =========================
    if ($DryRun) {
        Write-Host "[DRYRUN] Registry build complete - no file written" -ForegroundColor Yellow
        return
    }

    # ========================= WRITE OUTPUT =========================
    $out = [ordered]@{
        iconDefinitions = $iconDefinitions
        fileExtensions  = $fileExtensions
        fileNames       = $fileNames
    }

    $json = $out | ConvertTo-Json -Depth 50

    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "JSON serialization produced empty output"
    }

    Set-Content -Path $OutputPath -Value $json -Encoding UTF8
    Write-Host "[OK] Registry written -> $OutputPath" -ForegroundColor Green
}