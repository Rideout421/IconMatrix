<#
================================================================================
 ICONMATRIX CLEAN RESET TOOL
================================================================================

USAGE FLOW (IMPORTANT):

1. ALWAYS RUN FIRST:

   & (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Tools\PipelineHealthCheck.ps1")

2. DRY RUN (SAFE / NO CHANGES):

   & (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Tools\Reset-IconMatrix.ps1")

3. IF EVERYTHING LOOKS GOOD:

   & (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Tools\Reset-IconMatrix.ps1") -Confirm

4. OPTIONAL FULL WIPE (SOURCE MACHINE ONLY):

   & (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Tools\Reset-IconMatrix.ps1") -Confirm -FullReset

================================================================================
 MODES:

- Default (no flags)
  → Dry-run preview only (safe mode / no changes)

- -Confirm
  → Required to execute cleanup

- -FullReset
  → ALSO deletes source-icons (ONLY use on source machine)

================================================================================
#>
param(
    [switch]$Confirm,
    [switch]$FullReset
)

Write-Host "`n=== ICONMATRIX CLEAN RESET ===`n" -ForegroundColor Cyan

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Write-Host "STEP 1: Run PipelineHealthCheck first" -ForegroundColor Yellow
Write-Host "STEP 2: Confirm system state before cleanup`n" -ForegroundColor Yellow

# =========================
# DRY RUN MODE
# =========================
if (-not $Confirm) {

    Write-Host "DRY RUN MODE (NO CHANGES)`n" -ForegroundColor Yellow

    $previewTargets = @(
        "$RepoRoot\processed-icons\*",
        "$RepoRoot\config\icon-manifest.json",
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

# =========================
# SAFE TARGETS (ALWAYS CLEANED)
# =========================
$targets = @(
    "$RepoRoot\processed-icons\*",
    "$RepoRoot\config\icon-manifest.json",
    "$RepoRoot\registry\icons.json",
    "$RepoRoot\theme\icons-theme.json"
)

# =========================
# OPTIONAL SOURCE CLEAN (ONLY FULL RESET)
# =========================
if ($FullReset) {
    Write-Host "FULL RESET ENABLED -> source-icons WILL BE DELETED" -ForegroundColor Red
    $targets += "$RepoRoot\source-icons\*"
} else {
    Write-Host "SAFE MODE -> source-icons preserved" -ForegroundColor Green
}

# =========================
# EXECUTION
# =========================
foreach ($t in $targets) {
    if (Test-Path $t) {
        Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "CLEANED -> $t" -ForegroundColor Green
    } else {
        Write-Host "SKIP -> $t (not found)" -ForegroundColor DarkGray
    }
}

Write-Host "`nRESET COMPLETE`n" -ForegroundColor Green