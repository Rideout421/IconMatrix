$root = Join-Path $env:GIT_ROOT "IconMatrix\"
$logFile = Join-Path $env:GIT_ROOT "IconMatrix\logs\IconMatrixStructure.txt"

# Extensions to exclude
$excludeExt = @(".png", ".jpg", ".jpeg", ".svg")

New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

Write-Host "`n=== ICONMATRIX FULL STRUCTURE (EXPANDED VIEW) ===`n" -ForegroundColor Cyan

# Build hierarchical structure
$structure = Get-ChildItem $root -Recurse -File |
    Where-Object { $_.Extension -notin $excludeExt } |
    Group-Object { $_.DirectoryName } |
    Sort-Object Name

$output = @()

foreach ($group in $structure) {

    # Convert full path to relative folder path
    $folder = $group.Name.Replace($root, "")

    $output += "`n[$folder]"

    foreach ($file in ($group.Group | Sort-Object Name)) {
        $relative = $file.FullName.Replace($root, "")
        $output += "  - $relative"
    }
}

# Write output
$output | Set-Content -Path $logFile -Encoding UTF8

Write-Host "`n[OK] Expanded structure exported -> $logFile`n" -ForegroundColor Green