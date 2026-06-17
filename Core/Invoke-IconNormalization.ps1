function Invoke-IconNormalization {
    param(
        [string]$Path,
        [switch]$DryRun
    )

    . "$PSScriptRoot\..\utils\Naming.ps1"

    $validExt = @(".png")

    Write-Host "`n=== ICON NORMALIZATION (BADASS MODE) ===" -ForegroundColor Cyan

    Get-ChildItem $Path -File |
        Where-Object { $validExt -contains $_.Extension.ToLower() } |
        Group-Object { Get-CanonicalName $_.BaseName } |
        ForEach-Object {

            $group = $_.Group
            $canonical = $_.Name

            $keep = $group | Sort-Object Name | Select-Object -First 1
            $target = "$canonical.png"

            # Remove duplicates
            foreach ($file in $group) {

                if ($file.FullName -ne $keep.FullName) {

                    if ($DryRun) {
                        Write-Host "[DRYRUN DELETE DUP] $($file.Name)"
                        continue
                    }

                    Write-Host "[REMOVE DUP] $($file.Name)" -ForegroundColor Yellow
                    Remove-Item $file.FullName -Force
                }
            }

            # Canonical rename first
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

            # Normalize image
            if ($DryRun) {
                Write-Host "[DRYRUN NORMALIZE] $($keep.Name)"
                continue
            }

            Write-Host "[NORMALIZE] $($keep.Name)" -ForegroundColor Green

            $tempFile = Join-Path $env:TEMP "$([guid]::NewGuid()).png"

            try {

                magick $keep.FullName `
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

                Move-Item $tempFile $keep.FullName -Force
            }
            finally {
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        }

    Write-Host "`n=== ICON NORMALIZATION COMPLETE ===" -ForegroundColor Cyan
}