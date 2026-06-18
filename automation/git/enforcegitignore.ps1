$ErrorActionPreference = 'Stop'

$scriptPath = $PSCommandPath
$scriptDir = Split-Path -Parent $scriptPath
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

if (-not (Test-Path (Join-Path $repoRoot '.git'))) {
    Write-Host "Error: repo root not found from script location."
    Write-Host "Script path: $scriptPath"
    Write-Host "Computed repo root: $repoRoot"
    exit 1
}

Set-Location $repoRoot

Write-Host "Repo root: $repoRoot"
$confirm = Read-Host "Run gitignore enforcement in this repo? [y/N]"
if ($confirm -notmatch '^(y|yes)$') {
    Write-Host "Cancelled."
    exit 0
}

git rm -r --cached .
git add .
git commit -m "Apply .gitignore and stop tracking ignored files"