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
    # LOAD MAPPINGS (THREE-WAY MERGE)
    # -------------------------
    # Priority, highest first:
    #   1. mappings.json        - manual hand edits/overrides
    #   2. semantic.map.json    - curated semantic inference (e.g. 107 folderNames)
    #   3. mappings.auto.json   - dumb filename-derived fallback, fills any gaps
    #
    # Previously this only ever loaded ONE of these (auto if present, else
    # manual as a fallback) which meant semantic.map.json's curated folder
    # mappings never reached the registry at all, even when present.
    if (-not $MappingsPath) {
        throw "Mappings not found: -MappingsPath was not supplied"
    }

    $mappingsDir = Split-Path $MappingsPath -Parent

    $manualMappingsPath   = Join-Path $mappingsDir "mappings.json"
    $semanticMappingsPath = Join-Path $mappingsDir "semantic.map.json"
    $autoMappingsPath     = Join-Path $mappingsDir "mappings.auto.json"

    function Load-MappingFile($path, $label) {
        if (Test-Path $path) {
            Write-Host "[INFO] Loading $label mappings: $path" -ForegroundColor Cyan
            return (Get-Content $path -Raw | ConvertFrom-Json)
        }
        Write-Host "[INFO] $label mappings not found, skipping: $path" -ForegroundColor DarkGray
        return $null
    }

    $manualJson   = Load-MappingFile $manualMappingsPath   "MANUAL"
    $semanticJson = Load-MappingFile $semanticMappingsPath "SEMANTIC"
    $autoJson     = Load-MappingFile $autoMappingsPath     "AUTO"

    if (-not $manualJson -and -not $semanticJson -and -not $autoJson) {
        # Nothing by convention next to MappingsPath - fall back to treating
        # MappingsPath itself as a single mapping file (legacy behavior).
        if (Test-Path $MappingsPath) {
            Write-Host "[WARN] No conventional mapping files found; using -MappingsPath directly: $MappingsPath" -ForegroundColor Yellow
            $manualJson = Get-Content $MappingsPath -Raw | ConvertFrom-Json
        }
        else {
            throw "Mappings not found"
        }
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

    # Merge three layers for one mapping section (extensions/fileNames/folderNames).
    # Lowest priority is merged in first, then higher-priority layers overwrite
    # keys they also define - but values are UNIONED per key (not replaced),
    # so e.g. auto-derived extension matches aren't lost just because a
    # manual override also touches that same icon key.
    function Merge-MapLayer {
        param($autoObj, $semanticObj, $manualObj)

        $merged = @{}

        foreach ($layer in @($autoObj, $semanticObj, $manualObj)) {
            $layerMap = To-Map $layer
            foreach ($key in $layerMap.Keys) {
                if (-not $merged.ContainsKey($key)) {
                    $merged[$key] = @()
                }
                foreach ($v in $layerMap[$key]) {
                    if ($merged[$key] -notcontains $v) {
                        $merged[$key] += $v
                    }
                }
            }
        }

        return $merged
    }

    $extMappings        = Merge-MapLayer $autoJson.extensions  $semanticJson.extensions  $manualJson.extensions
    $fileNameMappings   = Merge-MapLayer $autoJson.fileNames   $semanticJson.fileNames   $manualJson.fileNames
    $folderNameMappings = Merge-MapLayer $autoJson.folderNames $semanticJson.folderNames $manualJson.folderNames

    Write-Host "[INFO] Merged folderName keys: $($folderNameMappings.Keys.Count)" -ForegroundColor Cyan

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

        # Same fix as MappingGenerator.ps1: real folder icon filenames in
        # this set (default-folder, default-root-folder, ps1folder,
        # rootfolder) don't start with "folder", so -like "folder*" never
        # matched and every icon (including folders) got minted as
        # "file-*-icon". Match "folder" anywhere in the name instead.
        $kind = if ($base -match 'folder') { "folder" } else { "file" }

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