# tools/extension/Install-Extension.ps1

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$vsix = Get-ChildItem $RepoRoot -Filter "*.vsix" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $vsix) {
    throw "No VSIX found. Run Build-Extension.ps1 first."
}

Write-Host "Installing IconMatrix extension -> $($vsix.Name)" -ForegroundColor Cyan

code --install-extension $vsix.FullName --force

Write-Host "Install complete" -ForegroundColor Green