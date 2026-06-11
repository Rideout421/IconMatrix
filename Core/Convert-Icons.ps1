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

    $validExt = @(".png", ".jpg", ".jpeg", ".ico")

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

        $file = $group.Group | Sort-Object Name | Select-Object -First 1

        $outFile   = "$($group.Name).png"
        $finalPath = Join-Path $Output $outFile

        Write-Host "CONVERTING: $($file.FullName)" -ForegroundColor Cyan

        # -----------------------------
        # HASH SKIP
        # -----------------------------
        $sourceHash = Get-FileHashSHA256 $file.FullName
        if ($manifest[$outFile] -and $manifest[$outFile].hash -eq $sourceHash) {
            Write-Host "[SKIP UNCHANGED] $($file.Name)" -ForegroundColor DarkGray
            continue
        }

        # -----------------------------
        # IMAGE VALIDATION (NO FALSE FAILS)
        # -----------------------------
        $identify = & $magick identify -format "%w %h" $file.FullName
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0 -or -not $identify) {
            Write-Host "[SKIP INVALID IMAGE] $($file.Name)" -ForegroundColor Red
            continue
        }

        $w, $h = $identify -split " "

        # -----------------------------
        # PASS-THROUGH (NO RESIZE = NO BLUR)
        # -----------------------------
        if ([int]$w -le 128 -and [int]$h -le 128) {

            Write-Host "[PASS THROUGH] $($file.Name)" -ForegroundColor Green

            if (-not $DryRun) {
                Copy-Item $file.FullName $finalPath -Force
            }

            $manifest[$outFile] = @{
                hash   = $sourceHash
                source = $file.Name
                mode   = "passthrough"
            }

            continue
        }

        # -----------------------------
        # RESIZE ONLY WHEN NECESSARY
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
}