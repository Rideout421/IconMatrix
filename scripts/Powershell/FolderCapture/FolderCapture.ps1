$Root = "D:\Users\Rideout421\Documents\GitHub"

Get-ChildItem $Root -Directory -Recurse -Force |
Where-Object {
    $_.FullName -notmatch '\\\.git\\' -and
    $_.Name -ne '.git' -and
    $_.FullName -notmatch '\\node_modules\\'
} |
Select-Object -ExpandProperty Name |
Sort-Object -Unique |
Set-Content "D:\Users\Rideout421\Documents\GitHub\IconMatrix\logs\FolderNames.txt"