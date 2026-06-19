function Invoke-RegistryBuild {
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [string]$MappingsPath,

        [switch]$DryRun
    )

    Write-Host "`n=== Registry Build (IconMatrix v2 - CLEAN FIX) ===" -ForegroundColor Cyan

    # -------------------------
    # PATH RESOLUTION
    # -------------------------
    if (-not (Test-Path $InputPath)) {
        $InputPath = Join-Path $PSScriptRoot $InputPath
    }

    $resolvedInput = (Resolve-Path $InputPath -ErrorAction Stop).Path

    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    . "$PSScriptRoot\..\utils\IconResolver.ps1"

    # -------------------------
    # LOAD MAPPINGS
    # -------------------------
    $autoMappingsPath = if ($MappingsPath) {
        Join-Path (Split-Path $MappingsPath -Parent) "mappings.auto.json"
    }

    if ($autoMappingsPath -and (Test-Path $autoMappingsPath)) {
        Write-Host "[INFO] Using AUTO mappings: $autoMappingsPath" -ForegroundColor Cyan
        $mappingsJson = Get-Content $autoMappingsPath -Raw | ConvertFrom-Json
    }
    elseif ($MappingsPath -and (Test-Path $MappingsPath)) {
        Write-Host "[WARN] Using manual mappings fallback" -ForegroundColor Yellow
        $mappingsJson = Get-Content $MappingsPath -Raw | ConvertFrom-Json
    }
    else {
        throw "Mappings not found"
    }

    # -------------------------
    # MAP NORMALIZER (SAFE)
    # -------------------------
    function To-Map($obj) {
        $map = @{}
        if ($null -eq $obj) { return $map }

        $obj.PSObject.Properties | ForEach-Object {
            $map[$_.Name] = @($_.Value)
        }

        return $map
    }

    $extMappings        = To-Map $mappingsJson.extensions
    $fileNameMappings   = To-Map $mappingsJson.fileNames
    $folderNameMappings = To-Map $mappingsJson.folderNames

    # -------------------------
    # FILE SCAN (SVG FIRST ALREADY ASSUMED STABLE)
    # -------------------------
    $files = Get-ChildItem -Path $resolvedInput -Recurse -File |
        Where-Object { $_.Extension -match '\.(svg|png|jpg|jpeg|ico)$' } |
        Group-Object BaseName |
        ForEach-Object {
            $_.Group | Select-Object -First 1
        }

    if (-not $files) {
        throw "No icon files found"
    }

    # -------------------------
    # OUTPUT STRUCTURES
    # -------------------------
    $iconDefinitions = [ordered]@{}
    $fileExtensions  = [ordered]@{}
    $fileNames       = [ordered]@{}
    $folderNames     = [ordered]@{}

    $basePath = (Get-Item $resolvedInput).FullName

    # -------------------------
    # BUILD LOOP
    # -------------------------
    foreach ($file in $files) {

        $base = $file.BaseName.ToLower()
        $ext  = $file.Extension.ToLower()

        $kind = if ($base -like "folder*") { "folder" } else { "file" }

        $iconId = "$kind-$base-icon"

        $rel = $file.FullName.Substring($basePath.Length).TrimStart('\','/') -replace '\\','/'

        # icon definition (ONLY ONCE)
        if (-not $iconDefinitions.Contains($iconId)) {
            $iconDefinitions[$iconId] = @{
                iconPath = "./processed-icons/$rel"
            }
        }

        # -------------------------
        # EXTENSIONS
        # -------------------------
        if ($extMappings.ContainsKey($base)) {
            foreach ($e in $extMappings[$base]) {
                $clean = $e.ToLower().TrimStart('.')
                if ($clean) {
                    $fileExtensions[$clean] = $iconId
                }
            }
        }

        # -------------------------
        # FILE NAMES
        # -------------------------
        if ($fileNameMappings.ContainsKey($base)) {
            foreach ($n in $fileNameMappings[$base]) {
                $fileNames[$n] = $iconId
            }
        }

        # -------------------------
        # FOLDER NAMES
        # -------------------------
        if ($folderNameMappings.ContainsKey($base)) {
            foreach ($n in $folderNameMappings[$base]) {
                $folderNames[$n] = $iconId
            }
        }
    }

    # -------------------------
    # GUARANTEED DEFAULT ICONS (NO FALLBACK CHAOS)
    # -------------------------
    function Find($pattern) {
        return ($iconDefinitions.Keys | Where-Object { $_ -like $pattern } | Select-Object -First 1)
    }

    $fileDefault   = Find "*default-file*" 
    $folderDefault = Find "*default-folder*"
    $rootFolder    = Find "*rootfolder*"
    $general       = Find "*general*"

    # HARD GUARANTEES (your requirement)
    if (-not $fileDefault)   { $fileDefault = Find "*file*" }
    if (-not $folderDefault) { $folderDefault = $fileDefault }
    if (-not $rootFolder)    { $rootFolder = Find "*rootfolder*" }
    if (-not $general)       { $general = $fileDefault }

    # VS CODE REQUIRED FALLBACKS
    if (-not $fileNames.Contains("*")) {
        $fileNames["*"] = $fileDefault
    }

    if (-not $folderNames.Contains("*")) {
        $folderNames["*"] = $folderDefault
    }

    # -------------------------
    # OUTPUT
    # -------------------------
    $out = @{
        iconDefinitions = $iconDefinitions
        fileExtensions  = $fileExtensions
        fileNames       = $fileNames
        folderNames     = $folderNames

        defaults = @{
            file       = $fileDefault
            folder     = $folderDefault
            rootFolder = $rootFolder
            general    = $general
        }
    }

    $out | ConvertTo-Json -Depth 60 |
        Set-Content -Path $OutputPath -Encoding UTF8 -Force

    Write-Host "[OK] Registry built -> $OutputPath" -ForegroundColor Green
}