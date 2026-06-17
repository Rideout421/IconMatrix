function Invoke-IconNormalization {
    param(
        [string]$Path,
        [switch]$DryRun
    )

    . "$PSScriptRoot\..\utils\Naming.ps1"

    Write-Host "`n=== ICON NORMALIZATION (HARDENED MODE) ===" -ForegroundColor Cyan

    Get-ChildItem $Path -File |
        Group-Object { Get-CanonicalName $_.BaseName } |
        ForEach-Object {

            $group = $_.Group
            $canonical = $_.Name

            # -------------------------------------------------
            # STRICT INPUT POLICY (ONLY PNG CAN BE NORMALIZED)
            # SVG + ICO = PASS THROUGH ONLY
            # -------------------------------------------------
            $pngGroup = $group | Where-Object { $_.Extension.ToLower() -eq ".png" }

            $svgGroup = $group | Where-Object { $_.Extension.ToLower() -eq ".svg" }
            $icoGroup = $group | Where-Object { $_.Extension.ToLower() -eq ".ico" }

            # -------------------------------------------------
            # HANDLE SVG (PASS THROUGH)
            # -------------------------------------------------
            if ($svgGroup) {
                $svgKeep = $svgGroup | Select-Object -First 1
                Write-Host "[PASS SVG] $($svgKeep.Name)" -ForegroundColor Cyan
            }

            # -------------------------------------------------
            # HANDLE ICO (PASS THROUGH ONLY, NEVER MAGICK)
            # -------------------------------------------------
            if ($icoGroup) {
                $icoKeep = $icoGroup | Select-Object -First 1
                Write-Host "[PASS ICO] $($icoKeep.Name)" -ForegroundColor Cyan
            }

            # -------------------------------------------------
            # NO PNG = NOTHING TO NORMALIZE
            # -------------------------------------------------
            if (-not $pngGroup) {
                Write-Host "[SKIP GROUP - NO PNG] $canonical" -ForegroundColor DarkGray
                return
            }

            $keep = $pngGroup | Sort-Object Name | Select-Object -First 1
            $target = "$canonical.png"

            # -------------------------------------------------
            # REMOVE PNG DUPLICATES ONLY
            # -------------------------------------------------
            foreach ($file in $pngGroup) {
                if ($file.FullName -ne $keep.FullName) {
                    if ($DryRun) {
                        Write-Host "[DRYRUN DELETE DUP] $($file.Name)"
                        continue
                    }

                    Write-Host "[REMOVE DUP] $($file.Name)" -ForegroundColor Yellow
                    Remove-Item $file.FullName -Force
                }
            }

            # -------------------------------------------------
            # CANONICAL RENAME
            # -------------------------------------------------
            if ($keep.Name -ne $target) {
                if ($DryRun) {
                    Write-Host "[DRYRUN RENAME] $($keep.Name) -> $target"
                }
                else {
                    Rename-Item -LiteralPath $keep.FullName -NewName $target -Force
                    Write-Host "[CANONICAL] $($keep.Name) -> $target" -ForegroundColor Green
                    $keep = Get-Item (Join-Path $keep.DirectoryName $target)
                }
            }

            # -------------------------------------------------
            # DRY RUN EXIT
            # -------------------------------------------------
            if ($DryRun) {
                Write-Host "[DRYRUN NORMALIZE] $($keep.Name)"
                return
            }

            # -------------------------------------------------
            # PNG ONLY NORMALIZATION (SAFE GUARANTEE)
            # -------------------------------------------------
            Write-Host "[NORMALIZE PNG] $($keep.Name)" -ForegroundColor Green

            $tempFile = Join-Path $env:TEMP "$([guid]::NewGuid()).png"

            try {

                & magick $keep.FullName `
                    -alpha set `
                    -fuzz 25% `
                    -fill none `
                    -draw "color 0,0 floodfill" `
                    -trim `
                    +repage `
                    -resize 220x220 `
                    -gravity center `
                    -background none `
                    -extent 256x256 `
                    PNG32:$tempFile

                # -------------------------------------------------
                # HARD VALIDATION (NO FALSE POSITIVES)
                # -------------------------------------------------
                if (Test-Path $tempFile) {

                    $size = (Get-Item $tempFile).Length

                    if ($size -gt 100) {
                        Move-Item $tempFile $keep.FullName -Force
                        Write-Host "[OK] $($keep.Name)" -ForegroundColor Green
                    }
                    else {
                        Write-Host "[SKIP - EMPTY OUTPUT] $($keep.Name)" -ForegroundColor Red
                        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                    }
                }
                else {
                    Write-Host "[SKIP - NO OUTPUT FILE] $($keep.Name)" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "[ERROR] $($keep.Name) -> $($_.Exception.Message)" -ForegroundColor Red
            }
            finally {
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        }

    Write-Host "`n=== ICON NORMALIZATION COMPLETE ===" -ForegroundColor Cyan
}