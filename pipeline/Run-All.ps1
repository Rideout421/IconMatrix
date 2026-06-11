Write-Host "=== IconMatrix Pipeline START ===" -ForegroundColor Cyan

# =========================
# ROOT RESOLUTION (ANCHOR-BASED - WORKSPACE SAFE)
# =========================

function Get-RepoRoot {
    param([string]$StartPath)

    $current = Split-Path -Parent $StartPath

    while ($current -and $current -ne [System.IO.Path]::GetPathRoot($current)) {

        if (
            (Test-Path (Join-Path $current "package.json")) -and
            (Test-Path (Join-Path $current "theme\icons-theme.json")) -and
            (Test-Path (Join-Path $current "config\paths.json"))
        ) {
            return $current
        }

        $current = Split-Path -Parent $current
    }

    throw "Failed to locate IconMatrix repo root"
}

# Works whether launched from VS Code, terminal, or script click
$Root = Get-RepoRoot $PSCommandPath

$Core = Join-Path $Root "Core"
$RegistryPath = Join-Path $Root "registry\icons.json"
$ProcessedIcons = Join-Path $Root "processed-icons"
$ThemeOutput = Join-Path $Root "theme\icons-theme.json"
$ConfigPath = Join-Path $Root "config\paths.json"

Write-Host "Root: $Root"
Write-Host "Core: $Core"
Write-Host "Config: $ConfigPath"