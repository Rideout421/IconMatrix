$root = "D:\Users\Rideout421\Documents\GitHub\IconMatrix"

Write-Host "`n=== ICONMATRIX STRUCTURE (SAFE TREE VIEW) ===`n" -ForegroundColor Cyan

# 1. Pure structure only (NO file enumeration here)
tree $root /A

Write-Host "`n=== FILTERED FILE INVENTORY (NO PNGS) ===`n" -ForegroundColor Cyan

Get-ChildItem $root -Recurse -File |
    Where-Object {
        $_.Extension -notin ".png"
    } |
    Select-Object FullName |
    Sort-Object FullName

Write-Host "`n=== SCRIPTS ONLY (.ps1) ===`n" -ForegroundColor Cyan

Get-ChildItem $root -Recurse -Filter *.ps1 |
    Select-Object FullName |
    Sort-Object FullName

Write-Host "`n=== CONFIG ONLY (.json) ===`n" -ForegroundColor Cyan

Get-ChildItem $root -Recurse -Filter *.json |
    Select-Object FullName |
    Sort-Object FullName