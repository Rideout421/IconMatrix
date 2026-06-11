# tools/extension/Build-Extension.ps1

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Write-Host "Building IconMatrix VS Code extension..." -ForegroundColor Cyan

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw "npm/npx not found"
}

Set-Location $RepoRoot

npx @vscode/vsce package

Write-Host "Build complete -> VSIX generated" -ForegroundColor Green