function Invoke-RegistryBuild {
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [string]$MappingsPath,

        [switch]$DryRun
    )

    Write-Host "`n=== Registry Build (IconMatrix v2 - Strong SVG Prefer) ===" -ForegroundColor Cyan

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

    # ========================= LOAD MAPPINGS (AUTO-FIRST PIPELINE) =========================

    $extMappings        = @{}
    $fileNameMappings   = @{}
    $folderNameMappings = @{}

    # Prefer auto-generated mappings (pipeline output)
    $autoMappingsPath = Join-Path (Split-Path $MappingsPath -Parent) "mappings.auto.json"

    $mappingsToLoad = $null

    if (-not [string]::IsNullOrWhiteSpace($autoMappingsPath) -and (Test-Path $autoMappingsPath)) {
        Write-Host "[INFO] Using AUTO mappings: $autoMappingsPath" -ForegroundColor Cyan
        $mappingsToLoad = $autoMappingsPath
    }
    elseif (-not [string]::IsNullOrWhiteSpace($MappingsPath) -and (Test-Path $MappingsPath)) {
        Write-Host "[WARN] Auto mappings not found, falling back to manual: $MappingsPath" -ForegroundColor Yellow
        $mappingsToLoad = $MappingsPath
    }
    else {
        throw "No mappings found. Run MappingGenerator.ps1 first to generate mappings.auto.json"
    }

    $mappingsJson = Get-Content $mappingsToLoad -Raw | ConvertFrom-Json

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

    # ========================= SCAN FILES - FIXED SVG-SAFE DEDUPE =========================
    $allFiles = Get-ChildItem -Path $resolvedInput -Recurse -File -Include "*.png", "*.svg", "*.jpg", "*.jpeg", "*.ico"
    
    # Extension priority (lower = better)
    $extPriority = @{
        '.svg'  = 0
        '.png'  = 1
        '.ico'  = 2
        '.jpg'  = 3
        '.jpeg' = 4
    }
    
    $files = $allFiles | ForEach-Object {

    $file = $_

    # Normalize ONLY for identity grouping (no semantic stripping)
    $baseName = $file.BaseName.ToLower()
    $ext      = $file.Extension.ToLower()

    # Detect type (used only for logging / future extension)
    $kind = if ($baseName -like "folder*") { "folder" } else { "file" }

    # 🔥 CRITICAL FIX:
    # Do NOT use Resolve-IconName for dedupe grouping.
    # It collapses valid variants like light/opened/config/etc.
    $canonical = "$kind|$baseName"

    [PSCustomObject]@{
        File      = $file
        Canonical = $canonical
        Priority  = if ($extPriority.ContainsKey($ext)) { $extPriority[$ext] } else { 99 }
    }
}

$files = $files |
    Group-Object Canonical |
    ForEach-Object {

        # Prefer SVG strictly, otherwise lowest priority number wins
        $best = $_.Group | Sort-Object Priority | Select-Object -First 1

        if ($_.Group.Count -gt 1) {
            $skipped = $_.Group |
                Where-Object { $_.File.FullName -ne $best.File.FullName } |
                ForEach-Object { $_.File.Name }

            Write-Host "[DEDUPE] '$($_.Name)' -> keeping $($best.File.Name), skipping: $($skipped -join ', ')" -ForegroundColor DarkYellow
        }

        $best.File
    } |
    Sort-Object @{Expression={$_.Extension}}, @{Expression={$_.BaseName}}

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

        $kind = if ($rawBase -like "folder*") { "folder" } else { "file" }

        # DO NOT normalize identity here (scan stage already handled it)
        $base = $rawBase

        if ([string]::IsNullOrWhiteSpace($base)) {
            $base = $rawBase
        }

        # $base now carries a "folder-" prefix for folder-kind icons (e.g.
        # "folder-docker") so file and folder variants of the same name get
        # distinct icon IDs. mappings.json, however, was written using the
        # bare name as the key (e.g. folderNames["docker"] = [...]) and is
        # the curated, hand-maintained source of truth -- it should not have
        # to know about this internal prefixing scheme. $lookupKey strips
        # that prefix back off ONLY for the purpose of matching against
        # mappings.json; $base/$iconId (used for identity/storage) keep the
        # prefix so file vs folder icons still don't collide.
        $lookupKey = if ($kind -eq "folder" -and $base -like "folder-*") {
            $base.Substring("folder-".Length)
        } else {
            $base
        }
        if ([string]::IsNullOrWhiteSpace($lookupKey)) {
            $lookupKey = $base
        }

        $iconId = "$kind-$base-icon"

        $rel = $file.FullName.Substring($basePath.Length).TrimStart('\','/') -replace '\\','/'

        if ($iconDefinitions.Contains($iconId)) {
            Write-Host "[WARN] Duplicate iconId '$iconId' from '$($file.Name)' -- keeping first-seen definition ($($iconDefinitions[$iconId].iconPath))" -ForegroundColor Yellow
        } else {
            $iconDefinitions[$iconId] = [ordered]@{
                iconPath = "./processed-icons/$rel"
            }
        }

        # ========================= EXTENSIONS (Mapped only - no bogus fallback) =========================
        # NOTE: previously this had a fallback that registered $base itself as a
        # "file extension" whenever no mapping existed (e.g. "acorns", "at&t",
        # "airwatch"). Those are icon/brand names, not real file extensions, and
        # VS Code will never match a file against them -- they were dead weight
        # in the theme. Only register real extensions explicitly defined in
        # mappings.json -> extensions.
        $mapped = $false
        if ($extMappings.Contains($lookupKey)) {
            foreach ($ext in $extMappings[$lookupKey]) {
                $ext = $ext.ToLower().TrimStart('.')
                if (-not [string]::IsNullOrWhiteSpace($ext)) {
                    $fileExtensions[$ext] = $iconId
                    $mapped = $true
                }
            }
        }

        # ========================= FILE / FOLDER NAMES (Mapped + Auto fallback) =========================
        # Explicit mappings from mappings.json always take priority and are
        # applied first (looked up via $lookupKey, the unprefixed name). If
        # an icon has no explicit fileName/folderName mapping at all, fall
        # back to registering its own canonical name ($lookupKey) as an
        # exact fileName or folderName match (e.g. "aws-icon" becomes
        # selectable for a folder or file literally named "aws"), so every
        # icon in the set is reachable in VS Code without needing
        # fileExtensions abuse.
        $hasFileNameMapping   = $fileNameMappings.Contains($lookupKey)
        $hasFolderNameMapping = $folderNameMappings.Contains($lookupKey)

        if ($hasFileNameMapping) {
            foreach ($fname in $fileNameMappings[$lookupKey]) {
                if (-not [string]::IsNullOrWhiteSpace($fname) -and -not $fileNames.Contains($fname)) {
                    $fileNames[$fname] = $iconId
                }
            }
        }

        if ($hasFolderNameMapping) {
            foreach ($fname in $folderNameMappings[$lookupKey]) {
                if (-not [string]::IsNullOrWhiteSpace($fname) -and -not $folderNames.Contains($fname)) {
                    $folderNames[$fname]        = $iconId
                    $folderNamesExpanded[$fname]= $iconId
                }
            }
        }

        if (-not $hasFileNameMapping -and -not $hasFolderNameMapping -and -not $mapped) {
            if ($kind -eq "folder") {
                if (-not $folderNames.Contains($lookupKey)) {
                    $folderNames[$lookupKey]         = $iconId
                    $folderNamesExpanded[$lookupKey] = $iconId
                }
            } else {
                if (-not $fileNames.Contains($lookupKey)) {
                    $fileNames[$lookupKey] = $iconId
                }
            }
        }
    }

    # ========================= DEFAULTS & FALLBACK =========================
    $defaults = @("file-icon", "folder-icon", "folder-expanded-icon", "folder-open-icon", "general-icon")
    foreach ($def in $defaults) {
        if (-not $iconDefinitions.Contains($def)) {
            Write-Host "[WARN] Missing default icon: $def" -ForegroundColor Yellow
        }
    }

    # Auto-create general-icon fallback if missing
    if (-not $iconDefinitions.Contains("general-icon") -and $iconDefinitions.Count -gt 0) {
        $fallback = $iconDefinitions.Keys | Where-Object { $_ -like "*file*" } | Select-Object -First 1
        if ($fallback) {
            $iconDefinitions["general-icon"] = $iconDefinitions[$fallback]
            Write-Host "[INFO] Created general-icon fallback from $fallback" -ForegroundColor Yellow
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