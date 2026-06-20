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

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host " THIS IS THE REPO YOU ARE RUNNING ON:" -ForegroundColor Green
Write-Host " $repoRoot" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
$confirm = Read-Host "Run gitignore enforcement in this repo? [y/N]"
if ($confirm -notmatch '^(y|yes)$') {
    Write-Host "Cancelled."
    exit 0
}

# Pull first so we're enforcing against the latest remote state,
# and so the upcoming push doesn't get rejected as non-fast-forward.
Write-Host "Pulling latest changes..."
git pull

# Untrack everything, then re-add only what .gitignore currently allows.
git rm -r --cached . | Out-Null
git add .

# Only commit if there's actually something staged — otherwise
# `git commit` errors out and (with ErrorActionPreference = Stop) kills the script.
$staged = git diff --cached --name-only
if ($staged) {
    git commit -m "Apply .gitignore and stop tracking ignored files"
    Write-Host "Committed enforcement changes."
} else {
    Write-Host "No changes to commit — repo already matches .gitignore."
}

# Push regardless, in case there's a prior local commit (e.g. from this
# script's own last run) that never made it to the remote.
$ahead = git rev-list '@{u}..HEAD' --count 2>$null
if ($LASTEXITCODE -eq 0 -and [int]$ahead -gt 0) {
    $pushMsg = "Pushing " + $ahead + " local commit to remote..."
    Write-Host $pushMsg
    git push
} else {
    Write-Host "Nothing to push — local and remote are in sync."
}

Write-Host "Done."