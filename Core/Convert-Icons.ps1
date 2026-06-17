function Convert-Icons {
    param(
        [string]$Path,
        [string]$Output,
        [switch]$DryRun
    )

    if (-not (Test-Path $Output)) {
        New-Item -ItemType Directory -Path $Output -Force | Out-Null
    }

    $magick = (Get-Command magick -ErrorAction Stop).Source

    . "$PSScriptRoot\..\utils\Naming.ps1"
    . "$PSScriptRoot\..\utils\Hashing.ps1"

    # Include SVG, but DO NOT convert it
    $validExt = @(".png", ".jpg", ".jpeg", ".svg")

    Write-Host "`n=== ICON CONVERT (SVG-AWARE MODE) ===" -ForegroundColor Cyan

    # -----------------------------
    # LOAD MANIFEST
    # -----------------------------
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    $manifestPath = Join-Path $RepoRoot "config\icon-manifest.json"
    $manifest = @{}

    if (Test-Path $manifestPath) {
        $raw = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($raw) {
            $raw.PSObject.Properties | ForEach-Object {
                $manifest[$_.Name] = $_.Value
            }
        }
    }

    # -----------------------------
    # GROUP BY CANONICAL NAME
    # -----------------------------
    $grouped = Get-ChildItem $Path -File |
        Where-Object { $validExt -contains $_.Extension.ToLower() } |
        Group-Object { Get-CanonicalName $_.BaseName }

    foreach ($group in $grouped) {

        # PRIORITY: SVG > PNG > others
        $file = $group.Group |
            Sort-Object @{
                Expression = {
                    switch ($_.Extension.ToLower()) {
                        ".svg" { 0 }
                        ".png" { 1 }
                        default { 2 }
                    }
                }
            }, Name |
            Select-Object -First 1

        $sourceHash = Get-FileHashSHA256 $file.FullName

        $outFile   = "$($group.Name)$($file.Extension.ToLower())"
        $finalPath = Join-Path $Output $outFile

        Write-Host "PROCESSING: $($file.FullName)" -ForegroundColor Cyan

        # -----------------------------
        # HASH SKIP
        # -----------------------------
        if ($manifest[$outFile] -and $manifest[$outFile].hash -eq $sourceHash) {
            Write-Host "[SKIP UNCHANGED] $($file.Name)" -ForegroundColor DarkGray
            continue
        }

        # -----------------------------
        # SVG PASS-THROUGH (NO MAGICK)
        # -----------------------------
        if ($file.Extension -eq ".svg") {

            Write-Host "[PASS SVG] $($file.Name)" -ForegroundColor Green

            if (-not $DryRun) {
                Copy-Item $file.FullName $finalPath -Force
            }

            $manifest[$outFile] = @{
                hash   = $sourceHash
                source = $file.Name
                mode   = "svg-pass"
            }

            continue
        }

        # -----------------------------
        # IMAGE VALIDATION (RASTER ONLY)
        # -----------------------------
        $identify = & $magick identify -format "%w %h" $file.FullName
        if ($LASTEXITCODE -ne 0 -or -not $identify) {
            Write-Host "[SKIP INVALID IMAGE] $($file.Name)" -ForegroundColor Red
            continue
        }

        $w, $h = $identify -split " "

        # -----------------------------
        # PASS-THROUGH SMALL PNG
        # -----------------------------
        if ([int]$w -le 128 -and [int]$h -le 128) {

            Write-Host "[PASS PNG] $($file.Name)" -ForegroundColor Green

            if (-not $DryRun) {
                Copy-Item $file.FullName $finalPath -Force
            }

            $manifest[$outFile] = @{
                hash   = $sourceHash
                source = $file.Name
                mode   = "png-pass"
            }

            continue
        }

        # -----------------------------
        # RESIZE LARGE PNG ONLY
        # -----------------------------
        if ($DryRun) {
            Write-Host "[DRYRUN] $($file.Name) -> $finalPath"
            continue
        }

        try {
            & $magick $file.FullName `
                -resize 128x128^> `
                -background none `
                -gravity center `
                -extent 128x128 `
                -filter Lanczos `
                -unsharp 0x1.0 `
                $finalPath

            if (Test-Path $finalPath) {
                Write-Host "[OK] $($file.Name)" -ForegroundColor Green

                $manifest[$outFile] = @{
                    hash   = $sourceHash
                    source = $file.Name
                    mode   = "converted"
                }
            }
        }
        catch {
            Write-Host "[ERROR] $($file.Name) -> $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # -----------------------------
    # SAVE MANIFEST
    # -----------------------------
    $manifest | ConvertTo-Json -Depth 10 | Out-File $manifestPath -Encoding UTF8

    Write-Host "`n=== CONVERT COMPLETE (SVG SAFE MODE) ===" -ForegroundColor Cyan
}