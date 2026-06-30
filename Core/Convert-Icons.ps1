function Convert-Icons {
    param(
        [string]$Path,
        [string]$Output,
        [switch]$DryRun
    )

    # -------------------------------------------------
    # Processing Settings
    # -------------------------------------------------
    $TargetSize = 128
    $MinScaleThreshold = 64   # ← Only very small icons get scaled now
    
    if (-not (Test-Path $Output)) {
        New-Item -ItemType Directory -Path $Output -Force | Out-Null
    }

    $magick = (Get-Command magick -ErrorAction Stop).Source

    . "$PSScriptRoot\..\utils\Naming.ps1"
    . "$PSScriptRoot\..\utils\Hashing.ps1"

    $validExt = @(".png", ".jpg", ".jpeg", ".svg")

    Write-Host "`n=== ICON CONVERT (SMART MODE) ===" -ForegroundColor Cyan

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

    $grouped = Get-ChildItem $Path -File |
        Where-Object { $validExt -contains $_.Extension.ToLower() } |
        Group-Object { Get-CanonicalName $_.BaseName }

    foreach ($group in $grouped) {

        $file = $group.Group |
            Sort-Object @{
                Expression = { switch ($_.Extension.ToLower()) { ".svg" { 0 } ".png" { 1 } default { 2 } } }
            }, Name |
            Select-Object -First 1

        $sourceHash = Get-FileHashSHA256 $file.FullName
        $outFile = "$($group.Name)$($file.Extension.ToLower())"
        $finalPath = Join-Path $Output $outFile

        Write-Host "PROCESSING: $($file.Name)" -ForegroundColor Cyan

        if ($manifest[$outFile] -and $manifest[$outFile].hash -eq $sourceHash) {
            Write-Host "[SKIP UNCHANGED]" -ForegroundColor DarkGray
            continue
        }

        if ($file.Extension.ToLower() -eq ".svg") {
            Write-Host "[PASS SVG] $($file.Name)" -ForegroundColor Green
            if (-not $DryRun) { Copy-Item $file.FullName $finalPath -Force }
            $manifest[$outFile] = @{ hash = $sourceHash; source = $file.Name; mode = "svg-pass" }
            continue
        }

        $original = & $magick $file.FullName -format "%w %h" info:
        $trimmed  = & $magick $file.FullName -trim +repage -format "%w %h" info:

        $origW,$origH = $original -split " "
        $trimW,$trimH = $trimmed -split " "

        $origW = [int]$origW; $origH = [int]$origH
        $trimW = [int]$trimW; $trimH = [int]$trimH

        $longestTrimmed = [Math]::Max($trimW, $trimH)

        # PASS THROUGH most icons
        if ($longestTrimmed -ge $MinScaleThreshold) {
            Write-Host "[PASS] Already good size" -ForegroundColor Green
            if (-not $DryRun) { Copy-Item $file.FullName $finalPath -Force }
            $manifest[$outFile] = @{ hash = $sourceHash; source = $file.Name; mode = "pass-through" }
            continue
        }

        # Only very tiny icons get scaled
        $MaxUpscale = 2.0
        $neededScale = $TargetSize / $longestTrimmed
        $scale = [Math]::Min($neededScale, $MaxUpscale)

        $resizeW = [Math]::Round($trimW * $scale)
        $resizeH = [Math]::Round($trimH * $scale)

        Write-Host "[PROCESS] $($file.Name) -> ${resizeW}x${resizeH} (tiny icon)" -ForegroundColor Yellow

        if ($DryRun) { 
            Write-Host "[DRYRUN]" 
            continue 
        }

        try {
            & $magick `
                $file.FullName `
                -trim +repage `
                -resize "${resizeW}x${resizeH}" `
                -background none `
                -gravity center `
                -extent "${TargetSize}x${TargetSize}" `
                -filter Mitchell `
                -unsharp 0x2.0+0.8+0.08 `   # Strong sharpening for tiny icons
                $finalPath

            Write-Host "[OK] $($file.Name)" -ForegroundColor Green
            $manifest[$outFile] = @{ hash = $sourceHash; source = $file.Name; mode = "scaled" }
        }
        catch {
            Write-Host "[ERROR] $($file.Name)" -ForegroundColor Red
        }
    }

    $manifest | ConvertTo-Json -Depth 10 | Out-File $manifestPath -Encoding UTF8
    Write-Host "`n=== CONVERT COMPLETE (SMART MODE) ===" -ForegroundColor Cyan
}