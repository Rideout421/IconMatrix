function Export-AutoMappings {
    param(
        [string]$InputPath,
        [string]$OutputPath
    )

    . "$PSScriptRoot\IconResolver.ps1"

    $files = Get-ChildItem -Path $InputPath -Recurse -File -Include *.svg, *.png, *.jpg, *.jpeg, *.ico

    $extensions   = @{}
    $fileNames    = @{}
    $folderNames  = @{}

    foreach ($f in $files) {

        $rawBase = $f.BaseName.ToLower()

        $kind = if ($rawBase -like "folder*") { "folder" } else { "file" }

        # IMPORTANT: use SAME identity rule as registry build
        $resolved = Resolve-IconName -Key $rawBase -Kind $kind
        $base = if ($resolved) { $resolved | Select-Object -First 1 } else { $rawBase }

        if ([string]::IsNullOrWhiteSpace($base)) {
            $base = $rawBase
        }

        $key = if ($kind -eq "folder" -and $base -like "folder-*") {
            $base.Substring("folder-".Length)
        } else {
            $base
        }

        # ---------- EXTENSIONS ----------
        if ($kind -ne "folder") {
            $ext = $f.Extension.ToLower().TrimStart('.')
            if (-not $extensions.ContainsKey($ext)) {
                $extensions[$ext] = @($key)
            }
        }

        # ---------- FILE / FOLDER ----------
        if ($kind -eq "folder") {
            if (-not $folderNames.ContainsKey($key)) {
                $folderNames[$key] = @($base)
            }
        } else {
            if (-not $fileNames.ContainsKey($key)) {
                $fileNames[$key] = @($base)
            }
        }
    }

    $out = [ordered]@{
        extensions  = $extensions
        fileNames   = $fileNames
        folderNames = $folderNames
    }

    $out | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

    Write-Host "[OK] Auto mappings generated -> $OutputPath" -ForegroundColor Green
}