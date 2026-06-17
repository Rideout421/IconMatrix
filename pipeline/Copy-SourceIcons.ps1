function Copy-SourceIcons {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$DryRun
    )

    . "$PSScriptRoot\..\utils\Naming.ps1"

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    # ✅ SVG ADDED
    $validExt = @(".png", ".jpg", ".jpeg", ".svg", ".ico")

    $seen = @{}

    Get-ChildItem -Path $Source -Recurse -File | ForEach-Object {

        $ext = $_.Extension.ToLower()

        if ($validExt -notcontains $ext) {
            return
        }

        # -----------------------------
        # SVG BYPASS (CRITICAL FIX)
        # -----------------------------
        if ($ext -eq ".svg") {
            # no System.Drawing validation for SVG
        }
        else {
            try {
                Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue | Out-Null
                $img = [System.Drawing.Image]::FromFile($_.FullName)
                $img.Dispose()
            }
            catch {
                Write-Host "[SKIP CORRUPT IMAGE] $($_.Name)" -ForegroundColor Red
                return
            }
        }

        $canonical = Get-CanonicalName $_.BaseName
        $targetName = "$canonical$ext"
        $targetPath = Join-Path $Destination $targetName

        # -----------------------------
        # ONE ICON PER CANONICAL NAME
        # -----------------------------
        if ($seen.ContainsKey($canonical)) {
            Write-Host "[SKIP DUP CANONICAL] $($_.Name) -> $canonical" -ForegroundColor DarkGray
            return
        }

        $seen[$canonical] = $true

        if ($DryRun) {
            Write-Host "[DRYRUN COPY] $($_.FullName) -> $targetPath"
            return
        }

        Copy-Item $_.FullName $targetPath -Force
        Write-Host "[COPY] $targetName" -ForegroundColor Green
    }
}