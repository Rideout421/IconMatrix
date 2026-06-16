<#
Perfect — you've got a fully working pipeline now. Just to summarize your workflow going forward:
Adding new icons:

Download PNG, name it correctly (e.g. excel.png, image.png)
Drop it in E:\Users\Rideout421\Pictures\Keypass_Icons
Run & (Join-Path $env:GIT_ROOT "IconMatrix\Tools\Publish-IconMatrix.ps1") -Install
Close and reopen VS Code

If an extension isn't mapping (showing gear instead of icon) — check if the icon name matches an entry in mappings.json. If not, either rename the PNG to match or add a new entry to mappings.json.
Quick reference for your shopping list:
#>
$root     = Join-Path $env:GIT_ROOT "IconMatrix"
$mappings = Get-Content "$root\config\mappings.json" | ConvertFrom-Json
$processed = Get-ChildItem "$root\processed-icons" | Select-Object -ExpandProperty BaseName

$mappings.extensions.PSObject.Properties | ForEach-Object {
    if ($processed -notcontains $_.Name) {
        Write-Host "MISSING ICON: $($_.Name).png  ->  maps to: $($_.Value -join ', ')" -ForegroundColor Yellow
    }
}
<#
Run that anytime to see exactly which icons you still need to hunt down. Great work getting this all the way from broken JSON mappings to a fully functional custom icon theme!
#>