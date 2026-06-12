<#
===============================================================================
 ICON MATRIX INTELLIGENCE ENGINE (STABLE + NORMALIZED - FIXED WRITE SAFETY)
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
# VALIDATION
# =========================
if (-not $Registry) {
    throw "[INTEL] Registry is null"
}

if (-not (Test-Path $IconsPath)) {
    throw "[INTEL] Icons path not found: $IconsPath"
}

# =========================
# NORMALIZE SAFE HASHTABLES (CRITICAL FIX)
# =========================

function Ensure-Hashtable($obj) {

    if ($null -eq $obj) { return @{} }

    if ($obj -is [hashtable]) { return $obj }

    $ht = @{}

    $obj.PSObject.Properties | ForEach-Object {
        $ht[$_.Name] = $_.Value
    }

    return $ht
}

$Registry.fileNames       = Ensure-Hashtable $Registry.fileNames
$Registry.fileExtensions  = Ensure-Hashtable $Registry.fileExtensions
$Registry.folder          = Ensure-Hashtable $Registry.folder
$Registry.file            = Ensure-Hashtable $Registry.file

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

$hitCount = 0

# =========================
# INTELLIGENCE MAPPING (FIXED WRITE SAFETY)
# =========================
foreach ($file in $files) {

    $fileName = $file.BaseName.ToLower()
    $assignedIcon = "default-icon"

    foreach ($rule in $rules) {
        if ($fileName -match $rule.Pattern) {
            $assignedIcon = $rule.Icon
            break
        }
    }

    # SAFE WRITE (NO PSOBJECT INDEXING ISSUES)
    $Registry.fileNames[$file.Name] = $assignedIcon
    $hitCount++
}

# =========================
# EXTENSIONS SAFETY
# =========================
if (-not $Registry.fileExtensions.ContainsKey("docx")) {
    $Registry.fileExtensions["docx"] = "word-icon"
}

# =========================
# META
# =========================
$Registry.file["totalFiles"] = $files.Count
$Registry.file["lastRun"] = (Get-Date).ToString("s")

# =========================
# OUTPUT
# =========================
Write-Host "[INTEL] Completed mappings: $hitCount" -ForegroundColor Green

if ($DryRun) {
    Write-Host "[INTEL] DryRun enabled - no persistence expected" -ForegroundColor Yellow
}

return $Registry