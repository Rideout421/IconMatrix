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

    Write-Host "`n=== ICONMATRIX THEME BUILD (ENTERPRISE STABLE) ===" -ForegroundColor Cyan

    if (-not (Test-Path $RegistryPath)) { throw "Registry missing: $RegistryPath" }

    $registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json

    if (-not $registry.iconDefinitions) {
        throw "Invalid registry: missing iconDefinitions"
    }

    # ================= NORMALIZE ICON DEFINITIONS =================
    $iconDefinitions = [ordered]@{}

    foreach ($p in $registry.iconDefinitions.PSObject.Properties) {

        $iconId = $p.Name
        $value  = $p.Value

        if ($value -is [string]) {
            $iconDefinitions[$iconId] = @{ iconPath = $value }
        }
        elseif ($value.iconPath) {
            $iconDefinitions[$iconId] = @{ iconPath = $value.iconPath }
        }
    }

    # ================= LOOKUP =================
    function Find-Icon($pattern) {
        return ($iconDefinitions.Keys |
            Where-Object { $_ -like $pattern } |
            Select-Object -First 1)
    }

    # ================= STRICT DEFAULT RULES =================

    # FILE DEFAULT = GENERAL (fallback chain enforced)
    $fileDefault = Find-Icon "*general*"
    if (-not $fileDefault) { $fileDefault = Find-Icon "*file-default*" }
    if (-not $fileDefault) { $fileDefault = Find-Icon "*file*" }

    # ROOT FOLDER MUST BE ROOT ICON (NOT GENERIC FOLDER)
    $rootFolder = Find-Icon "*rootfolder*"
    if (-not $rootFolder) { $rootFolder = Find-Icon "*root-folder*" }

    # NORMAL FOLDER DEFAULT
    $folderDefault = Find-Icon "*folder-default*"
    if (-not $folderDefault) { $folderDefault = Find-Icon "*folder*" }

    # HARD GUARANTEE FALLBACKS
    if (-not $folderDefault) { $folderDefault = $rootFolder }
    if (-not $rootFolder) { $rootFolder = $folderDefault }
    if (-not $fileDefault) { $fileDefault = $folderDefault }

    Write-Host "[DEBUG] file default   = $fileDefault"
    Write-Host "[DEBUG] folder default = $folderDefault"
    Write-Host "[DEBUG] root folder    = $rootFolder"

    # ================= MAP BUILD (NO GUESSING) =================
    $fileExtensions      = [ordered]@{}
    $fileNames           = [ordered]@{}
    $folderNames         = [ordered]@{}
    $folderNamesExpanded = [ordered]@{}

    foreach ($p in $registry.fileExtensions.PSObject.Properties) {
        if ($iconDefinitions.Contains($p.Value)) {
            $fileExtensions[$p.Name.ToLower()] = $p.Value
        }
    }

    foreach ($p in $registry.fileNames.PSObject.Properties) {
        if ($iconDefinitions.Contains($p.Value)) {
            $fileNames[$p.Name.ToLower()] = $p.Value
        }
    }

    foreach ($p in $registry.folderNames.PSObject.Properties) {
        if ($iconDefinitions.Contains($p.Value)) {
            $key = $p.Name.ToLower()
            $folderNames[$key] = $p.Value
            $folderNamesExpanded[$key] = $p.Value
        }
    }

    # ================= FINAL THEME (VS CODE VALID) =================
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
        Write-Host "[DRYRUN] No output written" -ForegroundColor Yellow
        return
    }

    $json = $theme | ConvertTo-Json -Depth 100
    Set-Content -Path $ThemeFilePath -Value $json -Encoding UTF8 -Force

    Write-Host "[SUCCESS] Theme written -> $ThemeFilePath" -ForegroundColor Green
}