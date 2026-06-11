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

    $validExt = @(".png", ".jpg", ".jpeg", ".ico")

    # Track canonical uniqueness (prevents -1 and duplicates)
    $seen = @{}

    Get-ChildItem -Path $Source -Recurse -File | ForEach-Object {

        if ($validExt -notcontains $_.Extension.ToLower()) {
            return
        }

        # -----------------------------
        # VALIDATE IMAGE INTEGRITY
        # -----------------------------
        try {
            Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue | Out-Null
            $img = [System.Drawing.Image]::FromFile($_.FullName)
            $img.Dispose()
        }
        catch {
            Write-Host "[SKIP CORRUPT IMAGE] $($_.Name)" -ForegroundColor Red
            return
        }

        $canonical = Get-CanonicalName $_.BaseName
        $targetName = "$canonical$($_.Extension.ToLower())"
        $targetPath = Join-Path $Destination $targetName

        # -----------------------------
        # ONE ICON PER CANONICAL NAME
        # -----------------------------
        if ($seen.ContainsKey($canonical)) {
            Write-Host "[SKIP DUPLICATE CANONICAL] $($_.Name) -> $canonical" -ForegroundColor DarkGray
            return
        }

        $seen[$canonical] = $true

        if ($DryRun) {
            Write-Host "[DRYRUN] COPY $($_.FullName) -> $targetPath"
            return
        }

        Copy-Item $_.FullName $targetPath -Force
        Write-Host "[COPY] $targetName" -ForegroundColor Green
    }
}