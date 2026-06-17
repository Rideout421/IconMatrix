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
    if (-not $registry -or -not $registry.iconDefinitions) { 
        throw "Registry JSON invalid or missing iconDefinitions" 
    }

    Write-Host "[DEBUG] Registry loaded - $($registry.iconDefinitions.Count) icons"

    # -------------------------
    # RESOLVE PATHS
    # -------------------------
    $ThemeFilePath = [System.IO.Path]::GetFullPath($ThemeFilePath)
    $outDir        = Split-Path -Parent $ThemeFilePath
    $IconsPath     = [System.IO.Path]::GetFullPath($IconsPath)

    $fromUri       = [Uri]("$outDir\")
    $toUri         = [Uri]($IconsPath)
    $iconRelPrefix = $fromUri.MakeRelativeUri($toUri).ToString() -replace '%20',' '

    Write-Host "[DEBUG] Icon relative prefix = $iconRelPrefix"

    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # -------------------------
    # REUSE REGISTRY iconDefinitions
    # -------------------------
    $iconDefinitions = [ordered]@{}
    foreach ($entry in $registry.iconDefinitions.PSObject.Properties) {
        $iconId = $entry.Name
        $oldPath = $entry.Value.iconPath

        if ($oldPath -like "./processed-icons/*") {
            $relName = $oldPath.Substring("./processed-icons/".Length)
            $newPath = "$iconRelPrefix/$relName" -replace '//','/'
        } else {
            $newPath = $oldPath
        }
        
        $iconDefinitions[$iconId] = [ordered]@{ iconPath = $newPath }
    }

    Write-Host "[DEBUG] iconDefinitions reused = $($iconDefinitions.Count)"

    # -------------------------
    # BUILD MAPPINGS (filtered)
    # -------------------------
    $fileExtensions = [ordered]@{}
    $fileNames      = [ordered]@{}
    $folderNames    = [ordered]@{}
    $folderNamesExpanded = [ordered]@{}

    $mappedExt = 0; $mappedName = 0; $mappedFolder = 0

    if ($registry.fileExtensions) {
        foreach ($p in $registry.fileExtensions.PSObject.Properties) {
            $iconId = $p.Value
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
                $mappedName++
            } else {
                Write-Host "[SKIP-NAME] '$($p.Name)' -> '$iconId' (icon not found)" -ForegroundColor DarkYellow
            }
        }
    }

    if ($registry.folderNames) {
        foreach ($p in $registry.folderNames.PSObject.Properties) {
            $iconId = $p.Value
            if ($iconDefinitions.Contains($iconId)) {
                $folderNames[$p.Name] = $iconId
                $folderNamesExpanded[$p.Name] = $iconId
                $mappedFolder++
            }
        }
    }

    Write-Host "[DEBUG] fileExtensions mapped = $mappedExt"
    Write-Host "[DEBUG] fileNames mapped      = $mappedName"
    Write-Host "[DEBUG] folderNames mapped    = $mappedFolder"

    # -------------------------
    # DEFAULT ICON
    # -------------------------
    $defaultIconId = "general-icon"
    if (-not $iconDefinitions.Contains($defaultIconId)) {
        $defaultIconId = if ($iconDefinitions.Contains("file-icon")) { 
            "file-icon" 
        } else {
            $iconDefinitions.Keys | Where-Object { $_ -like "*file*" } | Select-Object -First 1
        }
        if (-not $defaultIconId) {
            $defaultIconId = $iconDefinitions.Keys | Select-Object -First 1
        }
    }

    Write-Host "[DEBUG] Default icon = $defaultIconId" -ForegroundColor Cyan

    # -------------------------
    # FINAL THEME
    # -------------------------
    $theme = [ordered]@{
        iconDefinitions     = $iconDefinitions
        fileExtensions      = $fileExtensions
        fileNames           = $fileNames
        folderNames         = $folderNames
        folderNamesExpanded = $folderNamesExpanded
        file                = $defaultIconId
        folder              = $defaultIconId
        folderExpanded      = $defaultIconId
        rootFolder          = if ($iconDefinitions.Contains("rootfolder-icon")) { "rootfolder-icon" } else { $defaultIconId }
        rootFolderExpanded  = if ($iconDefinitions.Contains("rootfolder-icon")) { "rootfolder-icon" } else { $defaultIconId }
    }

    $json = $theme | ConvertTo-Json -Depth 50
    Set-Content -Path $ThemeFilePath -Value $json -Encoding UTF8 -Force

    $size = (Get-Item $ThemeFilePath).Length
    Write-Host "[SUCCESS] Theme written ($size bytes) -> $ThemeFilePath" -ForegroundColor Green
}