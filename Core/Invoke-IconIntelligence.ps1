<#
===============================================================================
 ICON MATRIX INTELLIGENCE ENGINE
===============================================================================
#>

param(
    [Parameter(Mandatory)]
    [object]$Registry,

    [Parameter(Mandatory)]
    [string]$IconsPath,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "`n[INTEL] Applying icon intelligence..." -ForegroundColor Cyan

# =========================
# SAFETY CHECKS
# =========================
if (-not $Registry) {
    throw "[INTEL] Registry is null"
}

if (-not (Test-Path $IconsPath)) {
    throw "[INTEL] Icons path not found: $IconsPath"
}

# =========================
# RULE ENGINE
# =========================
$rules = @(
    @{ Pattern = "azure";   Icon = "azure-icon" },
    @{ Pattern = "aws";     Icon = "aws-icon" },
    @{ Pattern = "cisco";   Icon = "cisco-icon" },
    @{ Pattern = "dell";    Icon = "dell-icon" },
    @{ Pattern = "vmware";  Icon = "vmware-icon" }
)

# =========================
# FILE SCAN
# =========================
$files = Get-ChildItem -Path $IconsPath -File -Recurse

# =========================
# FORCE HASHTABLE NORMALIZATION (CRITICAL FIX)
# =========================
if (-not $Registry.fileNames -or $Registry.fileNames -isnot [hashtable]) {
    $Registry.fileNames = @{}
}

if (-not $Registry.fileExtensions -or $Registry.fileExtensions -isnot [hashtable]) {
    $Registry.fileExtensions = @{}
}

$hitCount = 0

# =========================
# INTELLIGENCE MAPPING
# =========================
foreach ($file in $files) {

    $fileName = $file.BaseName.ToLower()
    $assignedIcon = $null

    foreach ($rule in $rules) {
        if ($fileName -match $rule.Pattern) {
            $assignedIcon = $rule.Icon
            break
        }
    }

    if (-not $assignedIcon) {
        $assignedIcon = "default-icon"
    }

    $Registry.fileNames[$file.Name] = $assignedIcon
    $hitCount++
}

# =========================
# DOCX SAFETY DEFAULT
# =========================
$Registry.fileExtensions["docx"] = "word-icon"

# =========================
# OUTPUT
# =========================
Write-Host "[INTEL] Completed mappings: $hitCount" -ForegroundColor Green

if ($DryRun) {
    Write-Host "[INTEL] DryRun enabled - no changes persisted" -ForegroundColor Yellow
}

return $Registry