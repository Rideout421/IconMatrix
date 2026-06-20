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
    function ConvertTo-NormalizedKey {
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

    # ========================= KNOWN EXTENSIONS (ALLOWLIST) =========================
    # Used so an icon literally named after a real extension (e.g. "vsix",
    # "rs", "go", "tf") auto-registers itself for that extension, WITHOUT
    # risking false positives from icon names that merely resemble an
    # extension but aren't one (e.g. an icon named "app" should not claim
    # a nonexistent ".app" extension just because the word sounds plausible).
    # This list intentionally excludes ambiguous/shared extensions that are
    # already hand-routed to a specific owner below (ps1, yml, yaml, json,
    # jsonc, dockerfile) so one icon doesn't silently steal another
    # vendor's extension - e.g. yml stays with whichever icon the explicit
    # switch block below assigns it to, not whichever icon happens to be
    # named "yml" if one ever gets added.
    $knownExtensions = @(
        'ps1','psm1','psd1','ps1xml','jsonc','md','mdx','markdown','txt',
        'xml','xsd','xsl','xslt','csproj','vbproj','props','targets',
        'js','jsx','mjs','cjs','ts','tsx','py','pyw','pyi','sh','bash',
        'zsh','fish','bat','cmd','css','less','scss','sass','html','htm',
        'svg','png','jpg','jpeg','gif','bmp','webp','ico','tiff','docx',
        'doc','xlsx','xls','xlsm','csv','pptx','ppt','pdf','tf','tfvars',
        'tfstate','bicep','rs','go','rb','erb','php','java','class','jar',
        'cs','cpp','cc','cxx','hpp','c','h','sql','graphql','gql','toml',
        'ini','cfg','conf','env','zip','tar','gz','7z','rar','crt','cer',
        'pem','key','pfx','ttf','otf','woff','woff2','tofu','vsix','vsixmanifest',
        'gitattributes','gitignore','dockerignore','editorconfig'
    )

    # ========================= PIPELINE =========================
    foreach ($f in $files) {

        $rawBase = $f.BaseName.ToLower().Trim()
        if ([string]::IsNullOrWhiteSpace($rawBase)) { continue }

        # NOTE: folder-vs-file classification used to gate which map an
        # icon was added to (fileNames vs folderNames). That logic was
        # removed in favor of every icon being eligible for both maps
        # unconditionally (see FOLDER / FILE MAPPING below), so there's
        # no classification variable to compute here anymore.

        # normalize semantic key
        $key = ConvertTo-NormalizedKey $rawBase

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

        # Generic auto-detection: if the icon's own normalized name IS a
        # real, known extension (e.g. icon "vsix.png" -> extension "vsix"),
        # register it automatically. Skipped for names already handled by
        # the explicit switch block above, so a hardcoded multi-extension
        # owner (e.g. "docker" owning yml/yaml/dockerfile) is never
        # silently overridden by this generic pass - Add-ToMap is additive
        # and de-duplicating, but we still avoid creating a NEW competing
        # owner for an extension that already has one assigned above.
        if ($knownExtensions -contains $key) {
            $alreadyOwned = $extensions.Values | Where-Object { $_ -contains $key }
            if (-not $alreadyOwned) {
                Add-ToMap $extensions $key $key
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