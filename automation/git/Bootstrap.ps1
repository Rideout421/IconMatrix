# =====================================================================
# GitHub Repository Bootstrap - IconMatrix (Idempotent)
# =====================================================================

# --- Variables ---
$RepoPath   = (Join-Path $env:GIT_ROOT "IconMatrix")
$GitHubRepo = "https://github.com/Rideout421/IconMatrix.git"
$CommitMsg  = "Initial repository structure and README"

# --- Validation ---
if (-not (Test-Path $RepoPath)) {
    Write-Error "Repository path does not exist: $RepoPath"
    exit 1
}

Set-Location $RepoPath
Write-Host "Working Directory: $RepoPath" -ForegroundColor Cyan

# --- Ensure Git repo exists ---
if (-not (Test-Path ".git")) {
    Write-Host "Initializing Git repository..." -ForegroundColor Yellow
    git init | Out-Null
} else {
    Write-Host "Git already initialized." -ForegroundColor Green
}

# --- Ensure main branch ---
$currentBranch = git branch --show-current 2>$null
if ($currentBranch -ne "main") {
    Write-Host "Setting branch to main..." -ForegroundColor Yellow
    git branch -M main
}

# --- Stage changes ---
Write-Host "Staging files..." -ForegroundColor Yellow
git add . | Out-Null

# --- Commit only if changes exist ---
$changes = git status --porcelain

if ($changes) {
    Write-Host "Creating commit..." -ForegroundColor Yellow
    git commit -m $CommitMsg | Out-Null
} else {
    Write-Host "No changes to commit." -ForegroundColor Green
}

# --- Remote handling (safe + silent check) ---
$remotes = git remote

if ($remotes -notcontains "origin") {
    Write-Host "Adding remote origin..." -ForegroundColor Yellow
    git remote add origin $GitHubRepo
} else {
    Write-Host "Remote origin already exists." -ForegroundColor Green

    # Optional: ensure URL is correct
    $currentUrl = git remote get-url origin 2>$null
    if ($currentUrl -ne $GitHubRepo) {
        Write-Host "Updating remote URL..." -ForegroundColor Yellow
        git remote set-url origin $GitHubRepo
    }
}

# --- Push safely ---
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push -u origin main

Write-Host "Done: IconMatrix is live." -ForegroundColor Green