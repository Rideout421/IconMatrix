Write-Host "Cleaning IconMatrix outputs..."

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$Paths = @(
    "$Root\processed-icons",
    "$Root\theme\icons-theme.json"
)

foreach ($p in $Paths) {
    if (Test-Path $p) {
        Remove-Item $p -Recurse -Force
        Write-Host "Removed: $p"
    }
}

Write-Host "Clean complete."