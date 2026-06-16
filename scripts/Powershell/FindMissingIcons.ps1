$root     = Join-Path $env:GIT_ROOT "IconMatrix"
$mappings = Get-Content "$root\config\mappings.json" | ConvertFrom-Json
$processed = Get-ChildItem "$root\processed-icons" | Select-Object -ExpandProperty BaseName

$mappings.extensions.PSObject.Properties | ForEach-Object {
    if ($processed -notcontains $_.Name) {
        Write-Host "MISSING ICON: $($_.Name).png  ->  maps to: $($_.Value -join ', ')" -ForegroundColor Yellow
    }
}