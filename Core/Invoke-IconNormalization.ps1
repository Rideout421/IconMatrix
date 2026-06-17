function Invoke-IconNormalization {
    param(
        [string]$Path,
        [switch]$DryRun
    )

    . "$PSScriptRoot\..\utils\Naming.ps1"

    $seen = @{}
    $validExt = @(".ico", ".png", ".jpg", ".jpeg")

    Get-ChildItem $Path -File |
        Where-Object { $validExt -contains $_.Extension.ToLower() } |
        Group-Object { Get-CanonicalName $_.BaseName } |
        ForEach-Object {

            $group = $_.Group

            # pick deterministic file (no renaming, no suffixes)
            $keep = $group | Sort-Object Name | Select-Object -First 1

            $canonical = $_.Name
            $target = "$canonical.png"
            
            $seen[$canonical] = $true

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

            # ensure canonical file exists under correct name
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