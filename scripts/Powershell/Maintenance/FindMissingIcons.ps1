<#
.SYNOPSIS
    Audits workspace folder names against available icons and shows ONLY items needing action.
#>

<#
USAGE:

# Standard run (refreshes folder/icon data, then audits)
& (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Powershell\Maintenance\FindMissingIcons.ps1")

# Audit only -- skip re-running GitHub.ps1 / Icons.ps1, use existing logs as-is
& (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Powershell\Maintenance\FindMissingIcons.ps1") -SkipRefresh

# Force a fresh start -- ignore any previous report, don't carry forward Status
& (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Powershell\Maintenance\FindMissingIcons.ps1") -NoCarryForward
#>

[CmdletBinding()]
param(
    [string]$GitHubCaptureScript = (Join-Path $env:GIT_ROOT 'IconMatrix\scripts\Powershell\FolderCapture\GitHub.ps1'),
    [string]$IconsCaptureScript  = (Join-Path $env:GIT_ROOT 'IconMatrix\scripts\Powershell\FileCapture\Icons.ps1'),
    [switch]$SkipRefresh,
    [string]$FoldersPath = (Join-Path $env:GIT_ROOT 'IconMatrix\logs\GitHubFolders.txt'),
    [string]$IconsPath   = (Join-Path $env:GIT_ROOT 'IconMatrix\logs\Icons.txt'),
    [string]$OutputPath  = (Join-Path $env:GIT_ROOT 'IconMatrix\logs\'),
    [string]$PreviousResultsPath,
    [switch]$NoCarryForward
)

$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------------
# Refresh
# ----------------------------------------------------------------------------
if (-not $SkipRefresh) {
    Write-Host 'Refreshing folder list...' -ForegroundColor Cyan
    if (Test-Path $GitHubCaptureScript) { & $GitHubCaptureScript }

    Write-Host 'Refreshing icon list...' -ForegroundColor Cyan
    if (Test-Path $IconsCaptureScript) { & $IconsCaptureScript }
}

# ----------------------------------------------------------------------------
# Load data
# ----------------------------------------------------------------------------
$folderLines = Get-Content $FoldersPath -Encoding UTF8 | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }
$iconFilesRaw = Get-Content $IconsPath -Encoding UTF8 | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }

Write-Host "Loaded $($folderLines.Count) folders and $($iconFilesRaw.Count) icons." -ForegroundColor Green

$folderEntries = $folderLines | ForEach-Object {
    if ($_ -match '^(.*)\|(.*)$') {
        [PSCustomObject]@{ Name = $Matches[1]; RelativePath = $Matches[2] }
    } else {
        [PSCustomObject]@{ Name = $_; RelativePath = $_ }
    }
}

Write-Host "Parsed $($folderEntries.Count) folder entries." -ForegroundColor Cyan

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
function Get-IconBaseName { 
    param([string]$f) 
    [regex]::Replace($f, '\.(png|jpe?g|svg)$', '', 'IgnoreCase') 
}

function Get-IconCoreName { 
    param([string]$b) 
    [regex]::Replace($b, '^(file_type_|folder_type_)', '', 'IgnoreCase') 
}

function Get-NormalizedKey { 
    param([string]$n) 
    [regex]::Replace($n.ToLowerInvariant(), '[^a-z0-9]', '') 
}

function Get-ExactIconKey {
    param([string]$name)
    $base = Get-IconBaseName $name
    $core = Get-IconCoreName $base
    return @($base, $core) | Select-Object -Unique
}

function Get-LevenshteinDistance {
    param([string]$A, [string]$B, [int]$MaxDistance = [int]::MaxValue)
    $lenA = $A.Length; $lenB = $B.Length
    if ([Math]::Abs($lenA - $lenB) -gt $MaxDistance) { return $MaxDistance + 1 }
    if ($lenA -eq 0) { return $lenB }
    if ($lenB -eq 0) { return $lenA }

    $prev = New-Object int[] ($lenB + 1)
    for ($j = 0; $j -le $lenB; $j++) { $prev[$j] = $j }

    for ($i = 1; $i -le $lenA; $i++) {
        $cur = New-Object int[] ($lenB + 1)
        $cur[0] = $i
        $charA = $A[$i-1]
        $rowMin = $cur[0]
        for ($j = 1; $j -le $lenB; $j++) {
            $cost = if ($charA -eq $B[$j-1]) { 0 } else { 1 }
            $cur[$j] = [Math]::Min([Math]::Min($prev[$j] + 1, $cur[$j-1] + 1), $prev[$j-1] + $cost)
            if ($cur[$j] -lt $rowMin) { $rowMin = $cur[$j] }
        }
        if ($rowMin -gt $MaxDistance) { return $MaxDistance + 1 }
        $prev = $cur
    }
    return $prev[$lenB]
}

function Get-FuzzyThreshold { 
    param([int]$Length)
    if ($Length -lt 5) { return 0 }
    if ($Length -le 7) { return 1 }
    if ($Length -le 12) { return 2 }
    return 3
}

# ----------------------------------------------------------------------------
# Ignore & Junk
# ----------------------------------------------------------------------------
$IgnoreFolders = @(
    '.vscode','.git','node_modules','.github','.idea','.vs','.NET', 
    '.secret-scan-output', 'Archive'
) | ForEach-Object { $_.ToLowerInvariant() }

$JunkPatterns = @(
    @{ Regex = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; Reason = 'GUID' },
    @{ Regex = '^(CHG|INC|CTASK|TASK|PRJ|REQ|RITM|WO|KB)\d{4,}'; Reason = 'Ticket' },
    @{ Regex = '_\d{2}-\d{2}-\d{4}_\d{2}-\d{2}-(AM|PM)$'; Reason = 'Auto-duplicate' },
    @{ Regex = '^\d{1,2}[-.]\d{1,2}[-.]\d{4}$'; Reason = 'Date' },
    @{ Regex = '^\d{4}-\d{2}-\d{2}$'; Reason = 'ISO Date' },
    @{ Regex = '^\d+(\.\d+){2,}$'; Reason = 'Version' },
    @{ Regex = '^[A-Za-z]$'; Reason = 'Single letter' }
)

function Get-JunkReason { param([string]$Name)
    foreach ($p in $JunkPatterns) { if ($Name -match $p.Regex) { return $p.Reason } }
    return $null
}

# ----------------------------------------------------------------------------
# Previous Results Carry-Forward (Status only)
# ----------------------------------------------------------------------------
$PreviousByKey = @{}
if (-not $NoCarryForward) {
    $autoFound = Get-ChildItem $OutputPath -Filter 'IconAlignmentReport_*.csv' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'IconAlignmentReport_Latest.csv' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($autoFound) { $PreviousResultsPath = $autoFound.FullName }

    if ($PreviousResultsPath -and (Test-Path $PreviousResultsPath)) {
        Write-Host "Carrying forward Status from previous report..." -ForegroundColor Cyan
        $prevRows = Import-Csv $PreviousResultsPath
        foreach ($row in $prevRows) {
            $k = if ($row.RelativePath) { "$($row.FolderName)|$($row.RelativePath)" } else { $row.FolderName }
            $PreviousByKey[$k] = $row.Status
        }
    }
}

# ----------------------------------------------------------------------------
# Icon Index (Exact + Normalized)
# ----------------------------------------------------------------------------
Write-Host "Building icon index..." -ForegroundColor Cyan

$ExactIconKeys = @{}      # For fast exact matching
$IconIndex = @{}          # Normalized for fuzzy
$IconKeysByLength = @{}

foreach ($iconFile in $iconFilesRaw) {
    $base = Get-IconBaseName $iconFile
    $core = Get-IconCoreName $base
    
    # Exact match keys
    foreach ($cand in @($base, $core) | Select-Object -Unique) {
        $exactKey = $cand.ToLowerInvariant()
        if ($exactKey -ne '') {
            $ExactIconKeys[$exactKey] = $true
        }
    }
    
    # Normalized index
    foreach ($cand in @($base, $core) | Select-Object -Unique) {
        $key = Get-NormalizedKey $cand
        if ($key -eq '') { continue }
        if (-not $IconIndex.ContainsKey($key)) { 
            $IconIndex[$key] = New-Object System.Collections.Generic.List[string] 
        }
        $IconIndex[$key].Add($iconFile) | Out-Null
    }
}

foreach ($key in $IconIndex.Keys) {
    $len = $key.Length
    if (-not $IconKeysByLength.ContainsKey($len)) { 
        $IconKeysByLength[$len] = New-Object System.Collections.Generic.List[string] 
    }
    $IconKeysByLength[$len].Add($key)
}

Write-Host "Indexed $($ExactIconKeys.Count) exact icon keys." -ForegroundColor Cyan

# ----------------------------------------------------------------------------
# Classify
# ----------------------------------------------------------------------------
$totalCount = $folderEntries.Count
Write-Host "Classifying $totalCount folder entries..." -ForegroundColor Cyan

$results     = New-Object System.Collections.Generic.List[object]
$processed   = 0
$progressTimer = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($entry in $folderEntries) {
    $folder = $entry.Name
    $relativePath = $entry.RelativePath

    $processed++

    if ($processed % 100 -eq 0 -or $progressTimer.Elapsed.TotalSeconds -ge 2) {
        $pct = [Math]::Round(($processed / $totalCount) * 100, 1)
        Write-Host "  ...$processed / $totalCount processed ($pct%)" -ForegroundColor DarkGray
        $progressTimer.Restart()
    }

    $folderLower = $folder.ToLowerInvariant()

    # Exact match (primary fix)
    if ($ExactIconKeys.ContainsKey($folderLower)) {
        continue
    }

    # Normalized exact match safety net
    $normKey = Get-NormalizedKey -Name $folder
    if ($normKey -ne '' -and $IconIndex.ContainsKey($normKey)) {
        continue
    }

    if ($IgnoreFolders -contains $folderLower) { 
        continue 
    }

    $junkReason = Get-JunkReason -Name $folder
    if ($junkReason) {
        # Still include Junk items but without extra columns
    }
    else {
        # For non-junk items that reach here → they need attention
    }

    # Carry forward Status only
    $status = ''
    $compositeKey = "$folder|$relativePath"
    if ($PreviousByKey.ContainsKey($compositeKey)) {
        $status = $PreviousByKey[$compositeKey]
    }

    $results.Add([PSCustomObject]@{
        FolderName    = $folder
        RelativePath  = $relativePath
        Status        = $status
    })
}

Write-Progress -Activity 'Classifying folders' -Completed
Write-Host "Classification complete: $($results.Count) items need attention." -ForegroundColor Green

# ----------------------------------------------------------------------------
# Output
# ----------------------------------------------------------------------------
$latestPath = Join-Path $OutputPath 'IconAlignmentReport_Latest.csv'
$results | Sort-Object FolderName | Export-Csv -Path $latestPath -NoTypeInformation -Encoding UTF8

Write-Host "`nReport complete: $latestPath" -ForegroundColor Green
Write-Host "Found $($results.Count) items needing attention." -ForegroundColor Yellow