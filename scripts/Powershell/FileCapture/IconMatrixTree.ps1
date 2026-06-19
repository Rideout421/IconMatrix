$root = Join-Path $env:GIT_ROOT "IconMatrix\"
$logFile = Join-Path $env:GIT_ROOT "IconMatrix\logs\IconMatrixTree.txt"

Write-Host "`n=== ICONMATRIX STRUCTURE (TREE VIEW) ===`n" -ForegroundColor Cyan
tree $root /A

# Ensure log directory exists
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

# Base inventory (excluding PNGs)
$inventory = Get-ChildItem $root -Recurse -File |
    Where-Object Extension -NotIn ".png", ".svg", ".jpeg", ".jpg" |
    Select-Object @{
        Name = "RelativePath"
        Expression = { $_.FullName.Replace($root, "") }
    }, Extension, Length

# Script inventory
$ps1 = Get-ChildItem $root -Recurse -Filter *.ps1 |
    Select-Object @{
        Name = "RelativePath"
        Expression = { $_.FullName.Replace($root, "") }
    }, Extension

# JSON inventory
$json = Get-ChildItem $root -Recurse -Filter *.json |
    Select-Object @{
        Name = "RelativePath"
        Expression = { $_.FullName.Replace($root, "") }
    }, Extension

# Build final output
$output = @()

$output += "`n=== FILTERED FILE INVENTORY (NO PNGS) ===`n"
$output += $inventory.RelativePath

$output += "`n=== SCRIPTS (.ps1) ===`n"
$output += $ps1.RelativePath

$output += "`n=== CONFIG (.json) ===`n"
$output += $json.RelativePath

# Write single source file
$output | Set-Content -Path $logFile -Encoding UTF8

Write-Host "`n[OK] Export complete -> $logFile`n" -ForegroundColor Green