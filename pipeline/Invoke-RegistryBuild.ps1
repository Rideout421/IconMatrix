function Invoke-RegistryBuild {
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [string]$MappingsPath,

        [switch]$DryRun
    )

    Write-Host "`n=== Registry Build (IconMatrix v2 - Multi-Format + SVG Prefer) ===" -ForegroundColor Cyan

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

    # ========================= LOAD RESOLVER =========================
    . "$PSScriptRoot\..\utils\IconResolver.ps1"

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
    }

    # ========================= SCAN FILES (Prefer SVG) =========================
    $allFiles = Get-ChildItem -Path $resolvedInput -Recurse -File -Include "*.png", "*.svg", "*.jpg", "*.jpeg", "*.ico"

    # Group by BaseName and prefer .svg
    $files = $allFiles | Group-Object { $_.BaseName.ToLower() } | ForEach-Object {
        $group = $_.Group
        $svg = $group | Where-Object Extension -eq '.svg' | Select-Object -First 1
        if ($svg) { $svg } else { $group | Select-Object -First 1 }
    } | Sort-Object BaseName

    if (-not $files -or $files.Count -eq 0) {
        throw "No icon files found: $resolvedInput"
    }

    Write-Host "[INFO] Icon files found (SVG preferred): $($files.Count)" -ForegroundColor Cyan

    # ========================= OUTPUT STRUCTURES =========================
    $iconDefinitions     = [ordered]@{}
    $fileExtensions      = [ordered]@{}
    $fileNames           = [ordered]@{}
    $folderNames         = [ordered]@{}
    $folderNamesExpanded = [ordered]@{}

    $basePath = (Get-Item $resolvedInput).FullName

    foreach ($file in $files) {

        $rawBase = $file.BaseName.ToLower()

        $kind = if ($rawBase -like "folder*") { "folder" }
                elseif ($rawBase -like "file*") { "file" }
                else { "file" }

        $resolvedKeys = Resolve-IconName -Key $rawBase -Kind $kind
        $base = if ($resolvedKeys) { $resolvedKeys | Select-Object -First 1 } else { $rawBase }

        if ([string]::IsNullOrWhiteSpace($base)) {
            $base = $rawBase
        }

        $iconId = "$base-icon"

        $rel = $file.FullName.Substring($basePath.Length).TrimStart('\','/') -replace '\\','/'

        # ========================= ICON DEFINITIONS =========================
        $iconDefinitions[$iconId] = [ordered]@{
            iconPath = "./processed-icons/$rel"
        }

        # ========================= EXTENSIONS (Auto + Mapped) =========================
        $mapped = $false

        if ($extMappings.Contains($base)) {
            foreach ($ext in $extMappings[$base]) {
                $ext = $ext.ToLower().TrimStart('.')
                if (-not [string]::IsNullOrWhiteSpace($ext)) {
                    $fileExtensions[$ext] = $iconId
                    $mapped = $true
                }
            }
        }

        # Auto-map base name if nothing else matched
        if (-not $mapped -and -not $fileExtensions.Contains($base)) {
            $fileExtensions[$base] = $iconId
        }

        # ========================= FILE NAMES =========================
        if ($fileNameMappings.Contains($base)) {
            foreach ($fname in $fileNameMappings[$base]) {
                if (-not [string]::IsNullOrWhiteSpace($fname) -and -not $fileNames.Contains($fname)) {
                    $fileNames[$fname] = $iconId
                }
            }
        }

        # ========================= FOLDER NAMES =========================
        if ($folderNameMappings.Contains($base)) {
            foreach ($fname in $folderNameMappings[$base]) {
                if (-not [string]::IsNullOrWhiteSpace($fname) -and -not $folderNames.Contains($fname)) {
                    $folderNames[$fname]        = $iconId
                    $folderNamesExpanded[$fname]= $iconId
                }
            }
        }
    }

    # ========================= DEFAULTS =========================
    $defaults = @("file-icon", "folder-icon", "folder-expanded-icon", "folder-open-icon")
    foreach ($def in $defaults) {
        if (-not $iconDefinitions.Contains($def)) {
            Write-Host "[WARN] Missing default icon: $def" -ForegroundColor Yellow
        }
    }

    # ========================= OUTPUT =========================
    Write-Host "[INFO] iconDefinitions : $($iconDefinitions.Count)" -ForegroundColor Cyan
    Write-Host "[INFO] fileExtensions  : $($fileExtensions.Count)" -ForegroundColor Cyan
    Write-Host "[INFO] fileNames       : $($fileNames.Count)" -ForegroundColor Cyan
    Write-Host "[INFO] folderNames     : $($folderNames.Count)" -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "[DRYRUN] No file written" -ForegroundColor Yellow
        return
    }

    $out = [ordered]@{
        iconDefinitions     = $iconDefinitions
        fileExtensions      = $fileExtensions
        fileNames           = $fileNames
        folderNames         = $folderNames
        folderNamesExpanded = $folderNamesExpanded
    }

    $json = $out | ConvertTo-Json -Depth 50
    Set-Content -Path $OutputPath -Value $json -Encoding UTF8

    Write-Host "[OK] Registry written -> $OutputPath" -ForegroundColor Green
}