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

    Write-Host "`n=== ICONMATRIX THEME BUILD (SCHEMA FIXED) ===" -ForegroundColor Cyan

    if (-not (Test-Path $RegistryPath)) {
        throw "Registry missing: $RegistryPath"
    }

    $registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json

    if (-not $registry.iconDefinitions) {
        throw "Invalid registry: missing iconDefinitions"
    }

    # ================= ICON DEFINITIONS =================
    # NOTE: must be an ORDERED dict. A plain @{} hashtable's key iteration
    # order is bucket order, not insertion order, which made Resolve-Icon's
    # "first match" wildcard search non-deterministic (e.g. picking
    # folder-default-root-folder-icon instead of folder-default-folder-icon
    # for the *folder* pattern, even though the latter was added first).
    $iconDefinitions = [ordered]@{}

    foreach ($p in $registry.iconDefinitions.PSObject.Properties) {

        $id  = $p.Name
        $val = $p.Value

        $path =
            if ($val -is [string]) { $val }
            elseif ($val.iconPath) { $val.iconPath }
            else { continue }

        # normalize paths only
        $path = $path -replace '^\./', '../'

        $iconDefinitions[$id] = @{
            iconPath = $path
        }
    }

    # ================= NORMALIZE MAPPINGS =================
    # VS Code's icon theme schema requires extensions / fileNames / folderNames
    # to map name -> SINGLE icon definition id (a string), not an array.
    # Source maps (mappings.auto.json / semantic.map.json) may store arrays
    # of candidate icon ids per key, so we must collapse each to one string
    # here, not pass the array straight through.
    function NormalizeMap($map) {
        $out = @{}

        if (-not $map) { return $out }

        foreach ($p in $map.PSObject.Properties) {

            $key = $p.Name.ToLower()
            $rawValues = @($p.Value)

            if ($rawValues -isnot [System.Array]) {
                $rawValues = @($rawValues)
            }

            # Collapse to the first value that is actually a known icon id.
            # This is the line that was missing before: previously the
            # whole array was assigned to $out[$key], which VS Code
            # silently ignores for folderNames (and is invalid for
            # extensions/fileNames too).
            # NOTE: $iconDefinitions is an OrderedDictionary (see [ordered]@{}
            # above), and that type's key-lookup method is .Contains(), not
            # .ContainsKey() like a plain Hashtable - using the wrong method
            # name throws "Method invocation failed... does not contain a
            # method named 'ContainsKey'" at runtime.
            $resolved = $rawValues | Where-Object { $iconDefinitions.Contains($_) } | Select-Object -First 1

            if (-not $resolved -and $rawValues.Count -gt 0) {
                # Fall back to first raw value even if not yet validated,
                # so we can surface a warning instead of silently dropping it.
                $resolved = $rawValues[0]
                Write-Warning "Mapping '$key' -> '$resolved' has no matching iconDefinition; folder/file may show default icon."
            }

            if ($resolved) {
                $out[$key] = $resolved
            }
        }

        return $out
    }

    # ================= SCHEMA (CORRECT) =================
    # NOTE: the registry's key is "fileExtensions", not "extensions".
    # Reading $registry.extensions silently returned $null (no error),
    # so NormalizeMap produced an empty map every time - this is why
    # extensions were never applied even though icons.json had 104+ of
    # them correctly built.
    $fileExtensions = NormalizeMap $registry.fileExtensions
    $fileNames      = NormalizeMap $registry.fileNames
    $folderNames    = NormalizeMap $registry.folderNames

    # ================= DEFAULT ICON RESOLUTION =================
    function Resolve-Icon($pattern) {
        return ($iconDefinitions.Keys |
            Where-Object { $_ -like $pattern } |
            Select-Object -First 1)
    }

    # Intent (per user spec):
    #   general.png        -> universal fallback for anything that doesn't map to anything else
    #   default-folder.svg / default-root-folder.svg -> generic "this is just a folder" fallback
    #   rootfolder.png      -> the actual repository/workspace root folder ONLY, never a generic fallback
    #
    # Patterns below are written to be mutually exclusive so they can't
    # cross-match each other (previously "*folder*" matched all 4 folder
    # icons ambiguously, including rootfolder and ps1folder).
    $fileDefault = Resolve-Icon "*general*"
    if (-not $fileDefault) { $fileDefault = Resolve-Icon "*default-file*" }
    if (-not $fileDefault) { $fileDefault = Resolve-Icon "*file*" }

    $folderDefault = Resolve-Icon "*default-folder*"
    if (-not $folderDefault) { $folderDefault = Resolve-Icon "*default-root-folder*" }

    $rootFolder = Resolve-Icon "*rootfolder*"

    if (-not $fileDefault)   { throw "Missing file default icon" }
    if (-not $folderDefault) { $folderDefault = $fileDefault }
    if (-not $rootFolder)    { $rootFolder = $folderDefault }

    Write-Host "[DEBUG] file default   = $fileDefault"
    Write-Host "[DEBUG] folder default = $folderDefault"
    Write-Host "[DEBUG] root folder    = $rootFolder"

    # ================= BUILD THEME =================
    $theme = [ordered]@{
        iconDefinitions = $iconDefinitions

        extensions = $fileExtensions
        fileNames  = $fileNames
        folderNames = $folderNames

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
        Write-Host "[DRYRUN] Theme build complete (not written)" -ForegroundColor Yellow
        return
    }

    $json = $theme | ConvertTo-Json -Depth 100
    Set-Content -Path $ThemeFilePath -Value $json -Encoding UTF8 -Force

    Write-Host "[SUCCESS] Theme written -> $ThemeFilePath" -ForegroundColor Green
}