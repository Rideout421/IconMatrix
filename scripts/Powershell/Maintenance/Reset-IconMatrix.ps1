<#
================================================================================
 ICONMATRIX CLEAN RESET TOOL
 SAFE PIPELINE RESET UTILITY
================================================================================

USAGE

Pipeline health check (recommended first):
& (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Powershell\Maintenance\PipelineHealthCheck.ps1")

Dry run (no changes):
& (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Powershell\Maintenance\Reset-IconMatrix.ps1")

Execute reset:
& (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Powershell\Maintenance\Reset-IconMatrix.ps1") -Confirm

Full reset (includes source icons):
& (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Powershell\Maintenance\Reset-IconMatrix.ps1") -Confirm -FullReset


PARAMETERS

- Default  → Dry-run mode (safe)
- -Confirm → Executes cleanup
- -FullReset → Includes source-icons (destructive)

================================================================================
#>

param(
    [switch]$Confirm,
    [switch]$FullReset
)

Write-Host "`n=== ICONMATRIX CLEAN RESET ===`n" -ForegroundColor Cyan

# ========================= BASE PATH =========================
$RepoRoot = Join-Path $env:GIT_ROOT "IconMatrix"

Write-Host "RepoRoot = $RepoRoot" -ForegroundColor Cyan
Write-Host "STEP 1: Run PipelineHealthCheck first" -ForegroundColor Yellow
Write-Host "STEP 2: Confirm system state before cleanup`n" -ForegroundColor Yellow

# ========================= DRY RUN =========================
if (-not $Confirm) {

    Write-Host "DRY RUN MODE (NO CHANGES)`n" -ForegroundColor Yellow

    $previewTargets = @(
        "$RepoRoot\processed-icons\*",
        "$RepoRoot\config\icon-manifest.json",
        "$RepoRoot\config\mappings.auto.json",
        "$RepoRoot\config\semantic.map.json",
        "$RepoRoot\registry\icons.json",
        "$RepoRoot\theme\icons-theme.json"
    )

    foreach ($t in $previewTargets) {
        if (Test-Path $t) {
            Write-Host "WOULD CLEAN -> $t" -ForegroundColor Yellow
        }
        else {
            Write-Host "SKIP -> $t (not found)" -ForegroundColor DarkGray
        }
    }

    if ($FullReset) {
        Write-Host "WOULD CLEAN -> $RepoRoot\source-icons\*" -ForegroundColor Red
    }
    else {
        Write-Host "PRESERVE -> source-icons" -ForegroundColor Green
    }

    Write-Host "`nRun with -Confirm to execute cleanup.`n" -ForegroundColor Cyan
    return
}

# ========================= TARGETS =========================
$targets = @(
    "$RepoRoot\processed-icons\*",
    "$RepoRoot\config\icon-manifest.json",
    "$RepoRoot\config\mappings.auto.json",
    "$RepoRoot\config\semantic.map.json",
    "$RepoRoot\registry\icons.json",
    "$RepoRoot\theme\icons-theme.json"
)

# ========================= OPTIONAL FULL RESET =========================
if ($FullReset) {
    Write-Host "FULL RESET ENABLED -> source-icons WILL BE DELETED" -ForegroundColor Red
    $targets += "$RepoRoot\source-icons\*"
}
else {
    Write-Host "SAFE MODE -> source-icons preserved" -ForegroundColor Green
}

# ========================= EXECUTION =========================
foreach ($t in $targets) {
    try {
        if (Test-Path $t) {
            Remove-Item $t -Recurse -Force -ErrorAction Stop
            Write-Host "CLEANED -> $t" -ForegroundColor Green
        }
        else {
            Write-Host "SKIP -> $t (not found)" -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "FAILED -> $t | $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nRESET COMPLETE`n" -ForegroundColor Green