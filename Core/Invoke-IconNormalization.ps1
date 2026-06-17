function Invoke-IconNormalization {
    param(
        [string]$Path,
        [switch]$DryRun
    )

    . "$PSScriptRoot\..\utils\Naming.ps1"

    $validExt = @(".png")   # HARD ENFORCEMENT: PNG ONLY

    Write-Host "`n=== ICON NORMALIZATION (BADASS MODE) ===" -ForegroundColor Cyan

    Get-ChildItem $Path -File |
        Where-Object { $validExt -contains $_.Extension.ToLower() } |
        Group-Object { Get-CanonicalName $_.BaseName } |
        ForEach-Object {

            $group = $_.Group
            $canonical = $_.Name

            # pick deterministic file
            $keep = $group | Sort-Object Name | Select-Object -First 1
            $target = "$canonical.png"

            foreach ($file in $group) {

                # skip duplicates safely
                if ($file.FullName -ne $keep.FullName) {
                    if ($DryRun) {
                        Write-Host "[DRYRUN DELETE DUP] $($file.Name)"
                        continue
                    }

                    Write-Host "[REMOVE DUP] $($file.Name)" -ForegroundColor Yellow
                    Remove-Item $file.FullName -Force
                }
            }

            # 🔥 ENFORCE FLOATING ICON TRANSFORMATION
            if ($keep.Extension.ToLower() -ne ".png") {
                if ($DryRun) {
                    Write-Host "[DRYRUN CONVERT] $($keep.Name) -> $target"
                }
                else {
                    Write-Host "[CONVERT + NORMALIZE] $($keep.Name) -> $target" -ForegroundColor Green

                    magick $keep.FullName `
                        -background none `
                        -alpha set `
                        -fuzz 10% -transparent white `
                        -fuzz 10% -transparent "#ffffff" `
                        -resize 256x256 `
                        -gravity center `
                        -extent 256x256 `
                        $target

                    Remove-Item $keep.FullName -Force
                }

                return
            }

            # ensure canonical naming
            if ($keep.Name -ne $target) {

                if ($DryRun) {
                    Write-Host "[DRYRUN RENAME] $($keep.Name) -> $target"
                    return
                }

                Rename-Item -LiteralPath $keep.FullName -NewName $target -Force
                Write-Host "[CANONICAL] $($keep.Name) -> $target" -ForegroundColor Green
            }
        }
}