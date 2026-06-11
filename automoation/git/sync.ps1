param(
    [string]$Message = ""
)

$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot
$RepoPath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoPath

if (-not (Test-Path ".git")) {
    throw "No git repository found at $RepoPath"
}

# --- BULLETPROOF AUTOMATION RESILIENCY ---
# 1. Ensure we are on main
git checkout main

# 2. Stash any current file modifications so pull won't error out
$hasLocalChanges = (git status --porcelain)
$stashApplied = $false
if ($hasLocalChanges) {
    $stashResult = git stash 2>&1
    if ($stashResult -notmatch "No local changes to save") {
        $stashApplied = $true
    }
}

# 3. Pull down upstream updates cleanly
git pull origin main --rebase

# 4. Bring active modifications back into the workspace
if ($stashApplied) {
    $popResult = git stash pop 2>&1
    # SAFETY: Detect stash pop conflicts before proceeding
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: git stash pop failed - conflict detected." -ForegroundColor Red
        Write-Host $popResult
        Write-Host "Run 'git stash list' and 'git stash show' to inspect. Aborting to protect your files." -ForegroundColor Yellow
        exit 1
    }
}
# ----------------------------------------

# Check for changes
$changed = git status --porcelain
if (-not $changed) {
    Write-Host "No changes to commit."
    exit 0
}

# --- SAFETY: Abort if any deletions are pending ---
# git add -A stages deletions too - remote-sourced deletions could wipe local files.
$pendingDeletes = git status --porcelain | Where-Object { $_ -match "^ D|^D " }
if ($pendingDeletes) {
    Write-Host ""
    Write-Host "WARNING: The following files are marked for deletion:" -ForegroundColor Yellow
    $pendingDeletes | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "These may have been deleted by a remote change, not by you." -ForegroundColor Yellow
    Write-Host "Aborting commit to protect your files. Review manually with 'git status'." -ForegroundColor Yellow
    Write-Host "If these deletions are intentional, run 'git add -A' and commit manually." -ForegroundColor Cyan
    exit 1
}

$files = $changed | ForEach-Object { $_.Substring(3) } | Sort-Object -Unique
$stamp = Get-Date -Format "MM-dd-yyyy hh-mm-tt"
$versionFile = Join-Path $RepoPath "version.txt"

$version = 1
if (Test-Path $versionFile) {
    $current = Get-Content $versionFile -Raw
    if ($current -match 'Version:\s*(\d+)') {
        $version = [int]$matches[1] + 1
    }
}

$versionContent = "Version: $version`r`nTimestamp: $stamp`r`nChanged files:`r`n$($files -join "`r`n")"
Set-Content $versionFile $versionContent

$changedAfterUpdate = git status --porcelain
$filesAfterUpdate = $changedAfterUpdate | ForEach-Object { $_.Substring(3) } | Sort-Object -Unique

$leafNames = $filesAfterUpdate | ForEach-Object { Split-Path $_ -Leaf }
$subjectFiles = ($leafNames | Select-Object -First 5) -join ", "
if ([string]::IsNullOrWhiteSpace($subjectFiles)) {
    $subjectFiles = "version.txt"
}

$bodyFiles = ($filesAfterUpdate | ForEach-Object { "- $_" }) -join "`r`n"

$commitMessage = "chore: update $subjectFiles`r`n`r`nChanged files:`r`n$bodyFiles`r`n`r`nVersion: $version`r`nTimestamp: $stamp`r`nNote: Automated commit and push from VS Code save-trigger workflow."

Write-Host ""
Write-Host "Changed files ($($filesAfterUpdate.Count)):"
$filesAfterUpdate | ForEach-Object { Write-Host " - $_" }
Write-Host "Version file updated: version.txt"
Write-Host "Timestamp: $stamp"
Write-Host ""

$commitFile = Join-Path $RepoPath ".git\AUTO_COMMIT_MSG.txt"
Set-Content -Path $commitFile -Value $commitMessage

# Stage only modifications and new files - NOT deletions
git add --update
git add version.txt

git commit -F $commitFile
git push origin main

Remove-Item $commitFile -ErrorAction SilentlyContinue