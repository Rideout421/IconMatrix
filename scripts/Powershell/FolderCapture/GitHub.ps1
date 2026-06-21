$Root = $env:GIT_ROOT
$LogPath = Join-Path $env:GIT_ROOT 'IconMatrix\logs\GitHubFolders.txt'

Write-Host "Scanning workspace for folders (this may take a moment)..." -ForegroundColor Cyan

$folders = Get-ChildItem $Root -Directory -Recurse -Force |
    Where-Object {
        $_.FullName -notmatch '\\\.git\\' -and
        $_.Name -ne '.git' -and
        $_.FullName -notmatch '\\node_modules\\'
    } |
    ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
        if ([string]::IsNullOrEmpty($relative)) {
            $relative = $_.Name  # root folder itself
        }
        "$($_.Name)|$relative"
    } |
    Sort-Object

$folders | Set-Content $LogPath -Encoding UTF8

Write-Host "GitHub folder scan complete: $($folders.Count) entries written to $LogPath" -ForegroundColor Green
Write-Host "Example line: FolderName|path\to\FolderName" -ForegroundColor DarkGray