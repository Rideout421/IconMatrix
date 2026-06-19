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

    Write-Host "`n=== ICONMATRIX THEME BUILD (FINAL SAFE MODE) ===" -ForegroundColor Cyan

    if (-not (Test-Path $RegistryPath)) { throw "Registry missing: $RegistryPath" }

    $registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json

    if (-not $registry.iconDefinitions) {
        throw "Invalid registry: missing iconDefinitions"
    }

    # ================= ICON DEFINITIONS (STRICT VS CODE FORMAT) =================
    $iconDefinitions = [ordered]@{}

    foreach ($p in $registry.iconDefinitions.PSObject.Properties) {

        $iconId = $p.Name
        $value  = $p.Value

        # FIX: enforce correct structure ALWAYS
        if ($value -is [string]) {
            $iconDefinitions[$iconId] = @{ iconPath = $value }
        }
        elseif ($value.iconPath) {
            $iconDefinitions[$iconId] = @{ iconPath = $value.iconPath }
        }
    }

    # ================= ICON LOOKUP =================
    function Find-Icon($pattern) {
        return ($iconDefinitions.Keys |
            Where-Object { $_ -like $pattern } |
            Select-Object -First 1)
    }

    # ================= DEFAULT RULES (HARD GUARANTEED) =================

    $fileDefault = Find-Icon "*general*"
    if (-not $fileDefault) { $fileDefault = Find-Icon "*file*" }

    $rootFolder = Find-Icon "*rootfolder*"
    if (-not $rootFolder) { $rootFolder = Find-Icon "*folder*" }

    $folderDefault = $rootFolder
    if (-not $folderDefault) { $folderDefault = $fileDefault }

    # ================= SAFE MAP MERGE =================
    $fileExtensions      = @{}
    $fileNames           = @{}
    $folderNames         = @{}
    $folderNamesExpanded = @{}

    foreach ($p in $registry.fileExtensions.PSObject.Properties) {
        if ($iconDefinitions[$p.Value]) {
            $fileExtensions[$p.Name.ToLower()] = $p.Value
        }
    }

    foreach ($p in $registry.fileNames.PSObject.Properties) {
        if ($iconDefinitions[$p.Value]) {
            $fileNames[$p.Name.ToLower()] = $p.Value
        }
    }

    foreach ($p in $registry.folderNames.PSObject.Properties) {
        if ($iconDefinitions[$p.Value]) {
            $key = $p.Name.ToLower()
            $folderNames[$key] = $p.Value
            $folderNamesExpanded[$key] = $p.Value
        }
    }

    # ================= THEME =================
    $theme = [ordered]@{
        iconDefinitions = $iconDefinitions

        fileExtensions = $fileExtensions
        fileNames      = $fileNames

        folderNames         = $folderNames
        folderNamesExpanded = $folderNamesExpanded

        file           = $fileDefault
        folder         = $folderDefault
        folderExpanded = $folderDefault

        rootFolder         = $rootFolder
        rootFolderExpanded = $rootFolder

        folderOpen         = $folderDefault
        folderOpenExpanded = $folderDefault

        fileExtensionsDefault = $fileDefault
    }

    if ($DryRun) {
        Write-Host "[DRYRUN] Skipping write" -ForegroundColor Yellow
        return
    }

    $json = $theme | ConvertTo-Json -Depth 100
    Set-Content -Path $ThemeFilePath -Value $json -Encoding UTF8 -Force

    Write-Host "[SUCCESS] Theme written -> $ThemeFilePath" -ForegroundColor Green
}