<#
.SYNOPSIS
Builds, packages, and optionally installs the IconMatrix VS Code extension.

.DESCRIPTION
This script:
1. Moves to the repo root
2. Packages the extension using @vscode/vsce
3. Optionally installs the generated VSIX into VS Code

REQUIREMENTS:
- Node.js installed
- @vscode/vsce available (npx recommended)
- Run from anywhere (auto-resolves repo path)
#>

param(
    [switch]$Install,
    [switch]$Clean
)

# -----------------------------
# CONFIG
# -----------------------------
$RepoRoot = Split-Path -Parent $PSScriptRoot
$VsixPattern = "iconmatrix-*.vsix"

Write-Host "=== IconMatrix Publish Pipeline ===" -ForegroundColor Cyan

# -----------------------------
# VALIDATE PATH
# -----------------------------
if (-not (Test-Path $RepoRoot)) {
    throw "Repo path not found: $RepoRoot"
}

Set-Location $RepoRoot
Write-Host "[OK] Working directory set to $RepoRoot" -ForegroundColor Green

# -----------------------------
# CLEAN OLD BUILDS (optional)
# -----------------------------
if ($Clean) {
    Write-Host "[CLEAN] Removing old VSIX files..." -ForegroundColor Yellow
    Get-ChildItem -Path $RepoRoot -Filter $VsixPattern -ErrorAction SilentlyContinue |
        Remove-Item -Force
}

# -----------------------------
# PACKAGE EXTENSION
# -----------------------------
Write-Host "[BUILD] Packaging extension..." -ForegroundColor Cyan

$npxCmd = Get-Command npx -ErrorAction SilentlyContinue
if (-not $npxCmd) {
    throw "npx not found. Install Node.js first."
}

npx @vscode/vsce package

$vsix = Get-ChildItem -Path $RepoRoot -Filter $VsixPattern |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $vsix) {
    throw "VSIX package not found after build."
}

Write-Host "[OK] Package created: $($vsix.Name)" -ForegroundColor Green

# -----------------------------
# INSTALL (optional)
# -----------------------------
if ($Install) {
    Write-Host "[INSTALL] Installing extension into VS Code..." -ForegroundColor Cyan

    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if (-not $codeCmd) {
        throw "VS Code CLI not found (code). Enable 'code' command in PATH."
    }

    code --install-extension $vsix.FullName

    Write-Host "[OK] Extension installed successfully" -ForegroundColor Green
}

# -----------------------------
# SUMMARY
# -----------------------------
Write-Host "`n=== COMPLETE ===" -ForegroundColor Cyan
Write-Host "VSIX: $($vsix.FullName)" -ForegroundColor White

if (-not $Install) {
    Write-Host "Tip: rerun with -Install to install into VS Code" -ForegroundColor DarkGray
}