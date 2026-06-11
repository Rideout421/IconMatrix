function Invoke-ReviewReport {
    param(
        [string]$LogPath,
        [switch]$DryRun
    )

    $target = Join-Path $LogPath "review.log"

    if ($DryRun) {
        Write-Host "[DRYRUN] REVIEW LOG -> $target"
        return
    }

    $dir = Split-Path $target -Parent

    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    "" | Out-File -FilePath $target -Encoding UTF8
}