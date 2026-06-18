$BasePath   = 'E:\Users\Rideout421\Pictures\Keypass_Icons'
$OutputPath = Join-Path $env:GIT_ROOT 'VSCode-Icons\Powershell\FileCapture\Icons.txt'

# Ensure output folder exists
$OutputFolder = Split-Path $OutputPath -Parent

if (-not (Test-Path -LiteralPath $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

# Capture icon inventory
Get-ChildItem -Path $BasePath -Recurse -File |
    Sort-Object FullName |
    ForEach-Object {
        $_.FullName.Replace($BasePath, '').TrimStart('\')
    } |
    Set-Content -Path $OutputPath -Encoding UTF8

Write-Host ""
Write-Host "Inventory complete." -ForegroundColor Green
Write-Host "File: $OutputPath" -ForegroundColor Cyan