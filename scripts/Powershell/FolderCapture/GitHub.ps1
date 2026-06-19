$Root = $env:GIT_ROOT

Get-ChildItem $Root -Directory -Recurse -Force |
Where-Object {
    $_.FullName -notmatch '\\\.git\\' -and
    $_.Name -ne '.git' -and
    $_.FullName -notmatch '\\node_modules\\'
} |
Select-Object -ExpandProperty Name |
Sort-Object -Unique |
Set-Content (Join-Path $env:GIT_ROOT 'IconMatrix\logs\GitHubFolders.txt')