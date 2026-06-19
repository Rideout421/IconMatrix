function Export-AutoMappings {
    param(
        [string]$InputPath,
        [string]$OutputPath
    )

    Write-Host "[AUTO-MAP] Scanning: $InputPath" -ForegroundColor Cyan

    # ========================= FILE SCAN =========================
    $files = Get-ChildItem -Path $InputPath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -and $_.Extension.Trim() -match '\.(svg|png|jpg|jpeg|ico)$'
        }

    if (-not $files -or $files.Count -eq 0) {
        throw "[AUTO-MAP] No files found in input path: $InputPath"
    }

    Write-Host "[AUTO-MAP] Files found: $($files.Count)" -ForegroundColor Cyan

    # ========================= OUTPUT STRUCTURES =========================
    $extensions  = @{}
    $fileNames   = @{}
    $folderNames = @{}

    # ========================= SAFE ADD FUNCTION =========================
    function Add-ToMap {
        param(
            [hashtable]$map,
            [string]$key,
            [string]$value
        )

        if (-not $key -or -not $value) { return }

        if (-not $map[$key]) {
            $map[$key] = @()
        }

        if ($map[$key] -notcontains $value) {
            $map[$key] += $value
        }
    }

    # ========================= NORMALIZATION =========================
    function Normalize-Key {
        param([string]$name)

        $n = $name.ToLower().Trim()

        # unify separators
        $n = $n -replace '[_\s]+', '-'

        # strip VSCode icon prefixes
        $n = $n -replace '^folder-type-', ''
        $n = $n -replace '^file-type-', ''
        $n = $n -replace '^type-', ''
        $n = $n -replace '^folder-', ''
        $n = $n -replace '^file-', ''

        # strip suffixes
        $n = $n -replace '-opened$', ''
        $n = $n -replace '-icon$', ''

        return $n
    }

    # ========================= PIPELINE =========================
    foreach ($f in $files) {

        $rawBase = $f.BaseName.ToLower().Trim()
        if ([string]::IsNullOrWhiteSpace($rawBase)) { continue }

        # detect folder vs file from RAW name ONLY
        #
        # NOTE: the original pattern '^folder[_-]' assumed every folder icon
        # is literally named like "folder-docker.svg". In this icon set none
        # of them are - the real folder icons are named:
        #   default-folder, default-root-folder, ps1folder, rootfolder
        # which don't share one prefix/suffix convention. Matching only the
        # old prefix classified 100% of files (including all folder icons)
        # as "file", which is why folderNames came out empty downstream.
        #
        # Match "folder" anywhere in the name (as a whole word-ish token),
        # which covers all four known conventions. This $kind value is now
        # ONLY used for cosmetic bookkeeping (it doesn't gate which map the
        # name goes into below) - see FOLDER / FILE MAPPING section.
        $kind = if ($rawBase -match 'folder') { "folder" } else { "file" }

        # normalize semantic key
        $key = Normalize-Key $rawBase

        # ========================= EXTENSIONS =========================
        switch -Regex ($rawBase) {

            'powershell|pwsh' {
                Add-ToMap $extensions 'powershell' 'ps1'
                Add-ToMap $extensions 'powershell' 'psm1'
                Add-ToMap $extensions 'powershell' 'psd1'
                Add-ToMap $extensions 'powershell' 'ps1xml'
            }

            'docker' {
                Add-ToMap $extensions 'docker' 'dockerfile'
                Add-ToMap $extensions 'docker' 'yml'
                Add-ToMap $extensions 'docker' 'yaml'
            }

            'json' {
                Add-ToMap $extensions 'json' 'json'
                Add-ToMap $extensions 'json' 'jsonc'
            }

            'yaml' {
                Add-ToMap $extensions 'yaml' 'yaml'
                Add-ToMap $extensions 'yaml' 'yml'
            }
        }

        # ========================= FOLDER / FILE MAPPING =========================
        # Every icon is eligible as BOTH a fileName match and a folderName
        # match. Previously this was an if/else that routed each icon into
        # only ONE map based on $kind, so e.g. "fedora" and "gemini" (kind
        # = "file") never got a folderNames entry at all, even though a
        # folder literally named "fedora" or "gemini" should reasonably
        # show that same icon. Per design: all icons can map to a folder;
        # files resolve via extensions (or this fileNames fallback).
        Add-ToMap $fileNames $key $key
        Add-ToMap $folderNames $key $key
    }

    # ========================= OUTPUT =========================
    $out = [ordered]@{
        extensions  = $extensions
        fileNames   = $fileNames
        folderNames = $folderNames
    }

    $json = $out | ConvertTo-Json -Depth 20

    if ([string]::IsNullOrWhiteSpace($json) -or $json -eq "{}") {
        throw "[AUTO-MAP] Generated JSON is empty - pipeline failure detected"
    }

    Set-Content -Path $OutputPath -Value $json -Encoding UTF8

    Write-Host "[OK] Auto mappings generated -> $OutputPath" -ForegroundColor Green
    Write-Host "[AUTO-MAP] Extensions : $($extensions.Count)" -ForegroundColor Cyan
    Write-Host "[AUTO-MAP] Files      : $($fileNames.Count)" -ForegroundColor Cyan
    Write-Host "[AUTO-MAP] Folders    : $($folderNames.Count)" -ForegroundColor Cyan
}