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

    $validExt = @(".png", ".jpg", ".jpeg", ".svg", ".ico")
    $seen = @{}   # canonical -> best file (prefer SVG)

    Get-ChildItem -Path $Source -Recurse -File | ForEach-Object {
    
        $file = $_
    
        $ext = $file.Extension.ToLower()
        if ($validExt -notcontains $ext) { return }
    
        # Skip corrupt non-SVG images
        if ($ext -ne ".svg") {
            try {
                Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue | Out-Null
                $img = [System.Drawing.Image]::FromFile($file.FullName)
                $img.Dispose()
            }
            catch {
                Write-Host "[SKIP CORRUPT]" -ForegroundColor Red
                Write-Host "    File : $($file.FullName)" -ForegroundColor Yellow
                Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor DarkYellow
                return
            }
        }

        $canonical = Get-CanonicalName $_.BaseName
        $targetPath = Join-Path $Destination "$canonical$ext"

        # ========================= PREFER SVG LOGIC =========================
        $existing = $seen[$canonical]

        if ($existing) {
            # If we already have a file for this canonical, keep the best one
            if ($ext -eq '.svg' -and $existing.Extension -ne '.svg') {
                # SVG beats PNG/JPG
                Write-Host "[REPLACE] $($existing.Name) -> $($_.Name) (SVG preferred)" -ForegroundColor Cyan
                $seen[$canonical] = $_
            } else {
                Write-Host "[SKIP DUP] $($_.Name) -> $canonical (keeping existing)" -ForegroundColor DarkGray
                return
            }
        } else {
            $seen[$canonical] = $_
        }
    }

    # Now actually copy the best version for each canonical
    if (-not $DryRun) {
        foreach ($item in $seen.Values) {
            $canonical = Get-CanonicalName $item.BaseName
            $targetPath = Join-Path $Destination "$canonical$($item.Extension)"
            
            Copy-Item $item.FullName $targetPath -Force
            Write-Host "[COPY] $($item.Name) -> $canonical$($item.Extension)" -ForegroundColor Green
        }
    } else {
        Write-Host "[DRYRUN] Would copy $($seen.Count) icons (SVG preferred)" -ForegroundColor Yellow
    }
}