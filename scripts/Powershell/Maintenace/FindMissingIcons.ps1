<#
.SYNOPSIS
    Audits IconMatrix folder names against available icon files and reports what aligns,
    what's a near-miss (rename folder OR get new icon), and what's junk that should never
    get an icon.

.DESCRIPTION
    This replaces the old mappings.json-based MISSING ICON checker. That approach only worked
    against vscode-icons' file-extension mapping file and doesn't reflect how this workspace
    actually works: a flat library of icon images (PNG/JPG/SVG) in Keypass_Icons /
    processed-icons, matched against real GitHub workspace folder names by NAME, not by a
    JSON config.

    [Updated] Now handles Name|RelativePath format from GitHub.ps1 so duplicate folder
    names in different locations are preserved as separate rows in the report.

    ALWAYS FRESH DATA: before anything else, this script runs GitHub.ps1 and Icons.ps1 itself.
    Those two scripts already write their output straight to
    IconMatrix\logs\GitHubFolders.txt and IconMatrix\logs\Icons.txt, so by the time this script
    reads those files, they reflect whatever folders/icons exist on disk AT THIS MOMENT --
    including any renames or deletions you just made. You never need to manually re-run them
    first; this script does it for you on every run. Pass -SkipRefresh if you ever want to audit
    against whatever GitHubFolders.txt/Icons.txt already exist without re-capturing (e.g. you're
    iterating quickly on the matching logic itself and don't need a fresh folder scan).

    Workflow this script supports:
      1. Run THIS script -- it refreshes GitHubFolders.txt/Icons.txt for you, then produces ONE
         master CSV with every folder classified into a section, plus a Status column you fill
         in by hand as you fix things.
      2. Fix folders/icons (rename, delete, add new icons).
      3. Re-run this script. It re-captures fresh data, and anything already marked "Done" in
         the previous run is carried forward automatically (now matched by Name|RelativePath)
         so you don't lose your progress. The MissingIcon/CloseMatch/Junk lists should get
         smaller each time as you clean things up.

    Matching logic:
      - "Matched"     : folder name and an icon name are identical once both are normalized
                        (case, spaces, dashes, underscores, punctuation all stripped). This is
                        why "IP-Route" maps to a folder named "IPRoute" -- dashes are fine and
                        DO map.
      - "CloseMatch"  : not an exact normalized match, but a small edit-distance away from an
                        existing icon (e.g. plural/singular: "certs" vs "cert", or a near-typo).
                        These are YOUR call: rename the folder to match the icon exactly, or go
                        get/rename an icon to match the folder.
      - "Junk"        : folder names that should NEVER get an icon -- GUIDs, change/incident
                        ticket numbers, pure date stamps, auto-generated dated duplicates,
                        version-number-only folders, and person names.
      - "MissingIcon" : everything left over. Legitimate category folders that need a new icon.

    The script is intentionally conservative about auto-classifying "Junk". When it isn't sure,
    it leaves the folder in MissingIcon/CloseMatch for YOU to decide.

.PARAMETER GitHubCaptureScript
    Path to GitHub.ps1, which scans the workspace and refreshes GitHubFolders.txt.
    Default: $env:GIT_ROOT\IconMatrix\scripts\Powershell\FolderCapture\GitHub.ps1

.PARAMETER IconsCaptureScript
    Path to Icons.ps1, which scans the icon library and refreshes Icons.txt.
    Default: $env:GIT_ROOT\IconMatrix\scripts\Powershell\FileCapture\Icons.ps1

.PARAMETER SkipRefresh
    Switch. If set, GitHub.ps1 and Icons.ps1 are NOT run, and this script reads whatever
    GitHubFolders.txt/Icons.txt already exist as-is.

.PARAMETER FoldersPath
    Path to the folder-list file that GitHub.ps1 writes to.
    Default: $env:GIT_ROOT\IconMatrix\logs\GitHubFolders.txt

.PARAMETER IconsPath
    Path to the icon-list file that Icons.ps1 writes to.
    Default: $env:GIT_ROOT\IconMatrix\logs\Icons.txt

.PARAMETER OutputPath
    Folder where the dated output CSV/log is written.
    Default: $env:GIT_ROOT\IconMatrix\logs\

.PARAMETER PreviousResultsPath
    Optional: path to a previously-exported CSV from this same script. If given (or if one is
    auto-discovered in OutputPath), any folder marked "Done" / "Ignore" in that file keeps that
    Status and your Notes in the new run.

.PARAMETER NoCarryForward
    Switch. If set, Status/Notes are NOT carried forward from any previous report.

.EXAMPLE
    .\FindMissingIcons.ps1
    Refreshes folder/icon data, then runs the audit.

.EXAMPLE
    .\FindMissingIcons.ps1 -SkipRefresh
    Audits whatever GitHubFolders.txt/Icons.txt already exist, without re-capturing.

.EXAMPLE
    .\FindMissingIcons.ps1 -NoCarryForward
    Runs normally, but starts every folder with a blank Status/Notes.
#>

<#
USAGE:

# Standard run (refreshes folder/icon data, then audits)
& (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Powershell\Maintenace\FindMissingIcons.ps1")

# Audit only -- skip re-running GitHub.ps1 / Icons.ps1, use existing logs as-is
& (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Powershell\Maintenace\FindMissingIcons.ps1") -SkipRefresh

# Force a fresh start -- ignore any previous report, don't carry forward Status/Notes
& (Join-Path $env:GIT_ROOT "IconMatrix\scripts\Powershell\Maintenace\FindMissingIcons.ps1") -NoCarryForward
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
# 0. Refresh folder/icon data
# ----------------------------------------------------------------------------
if (-not $SkipRefresh) {
    Write-Host 'Refreshing folder list (GitHub.ps1)...' -ForegroundColor Cyan
    if (Test-Path $GitHubCaptureScript) {
        & $GitHubCaptureScript
    } else {
        Write-Warning "GitHub.ps1 not found at '$GitHubCaptureScript'. Skipping refresh; using existing '$FoldersPath' as-is."
    }

    Write-Host 'Refreshing icon list (Icons.ps1)...' -ForegroundColor Cyan
    if (Test-Path $IconsCaptureScript) {
        & $IconsCaptureScript
    } else {
        Write-Warning "Icons.ps1 not found at '$IconsCaptureScript'. Skipping refresh; using existing '$IconsPath' as-is."
    }
}
else {
    Write-Host 'SkipRefresh set: using GitHubFolders.txt/Icons.txt as they already exist on disk.' -ForegroundColor Yellow
}

# ----------------------------------------------------------------------------
# 0b. Validate inputs
# ----------------------------------------------------------------------------
if (-not (Test-Path $FoldersPath)) {
    throw "Folder list not found at '$FoldersPath'. Run GitHub.ps1 first, or pass -FoldersPath."
}
if (-not (Test-Path $IconsPath)) {
    throw "Icon list not found at '$IconsPath'. Run Icons.ps1 first, or pass -IconsPath."
}
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

# ----------------------------------------------------------------------------
# 1. Load data
# ----------------------------------------------------------------------------
$folderLines = Get-Content -Path $FoldersPath -Encoding UTF8 |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne '' }

$iconFilesRaw = Get-Content -Path $IconsPath -Encoding UTF8 |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne '' }

Write-Host "Loaded $($folderLines.Count) folder entries and $($iconFilesRaw.Count) icon files." -ForegroundColor Cyan

# Parse Name|RelativePath into objects
$folderEntries = $folderLines | ForEach-Object {
    if ($_ -match '^(.*)\|(.*)$') {
        [PSCustomObject]@{
            Name         = $Matches[1]
            RelativePath = $Matches[2]
        }
    } else {
        # Fallback for old format
        [PSCustomObject]@{
            Name         = $_
            RelativePath = $_
        }
    }
}

# ----------------------------------------------------------------------------
# 2. Helper functions (unchanged)
# ----------------------------------------------------------------------------
function Get-IconBaseName {
    param([string]$FileName)
    return [regex]::Replace($FileName, '\.(png|jpe?g|svg)$', '', 'IgnoreCase')
}

function Get-IconCoreName {
    param([string]$BaseName)
    return [regex]::Replace($BaseName, '^(file_type_|folder_type_)', '', 'IgnoreCase')
}

function Get-NormalizedKey {
    param([string]$Name)
    return ([regex]::Replace($Name.ToLowerInvariant(), '[^a-z0-9]', ''))
}

function Get-LevenshteinDistance {
    param([string]$A, [string]$B, [int]$MaxDistance = [int]::MaxValue)

    $lenA = $A.Length
    $lenB = $B.Length
    if ([Math]::Abs($lenA - $lenB) -gt $MaxDistance) { return $MaxDistance + 1 }
    if ($lenA -eq 0) { return $lenB }
    if ($lenB -eq 0) { return $lenA }

    $prev = New-Object int[] ($lenB + 1)
    for ($j = 0; $j -le $lenB; $j++) { $prev[$j] = $j }

    for ($i = 1; $i -le $lenA; $i++) {
        $cur = New-Object int[] ($lenB + 1)
        $cur[0] = $i
        $charA  = $A[$i - 1]
        $rowMin = $cur[0]
        for ($j = 1; $j -le $lenB; $j++) {
            $cost = if ($charA -eq $B[$j - 1]) { 0 } else { 1 }
            $delete    = $prev[$j] + 1
            $insert    = $cur[$j - 1] + 1
            $substitute = $prev[$j - 1] + $cost
            $cur[$j] = [Math]::Min([Math]::Min($delete, $insert), $substitute)
            if ($cur[$j] -lt $rowMin) { $rowMin = $cur[$j] }
        }
        if ($rowMin -gt $MaxDistance) { return $MaxDistance + 1 }
        $prev = $cur
    }
    return $prev[$lenB]
}

function Get-FuzzyThreshold {
    param([int]$Length)
    if ($Length -lt 5)  { return 0 }
    if ($Length -le 7)  { return 1 }
    if ($Length -le 12) { return 2 }
    return 3
}

# Junk detection helpers (unchanged)
$CommonFirstNames = @(
    'james','robert','john','michael','david','william','richard','joseph','thomas','charles',
    'christopher','daniel','matthew','anthony','mark','donald','steven','paul','andrew','joshua',
    'kenneth','kevin','brian','george','timothy','ronald','edward','jason','jeffrey','ryan',
    'jacob','gary','nicholas','eric','jonathan','stephen','larry','justin','scott','brandon',
    'benjamin','samuel','gregory','alexander','frank','patrick','raymond','jack','dennis','jerry',
    'tyler','aaron','jose','adam','nathan','henry','douglas','zachary','peter','kyle',
    'walter','ethan','jeremy','harold','keith','christian','roger','noah','gerald','carl',
    'terry','sean','austin','arthur','lawrence','jesse','dylan','bryan','joe','jordan',
    'billy','bruce','albert','willie','gabriel','logan','alan','juan','wayne','roy',
    'ralph','randy','eugene','vincent','russell','elijah','louis','bobby','philip','johnny',
    'howard','craig','doug','don','andy','dan','bob','chris','steve','mike',
    'tom','greg','rich','jim','bill','mary','patricia','jennifer','linda','elizabeth',
    'barbara','susan','jessica','sarah','karen','lisa','nancy','betty','margaret','sandra',
    'ashley','kimberly','emily','donna','michelle','dorothy','carol','amanda','melissa','deborah',
    'stephanie','rebecca','sharon','laura','cynthia','kathleen','amy','shirley','angela','helen',
    'anna','brenda','pamela','nicole','emma','samantha','katherine','christine','debra','rachel',
    'catherine','carolyn','janet','ruth','maria','heather','diane','virginia','julie','joyce',
    'victoria','olivia','kelly','christina','lauren','joan','evelyn','judith','megan','andrea',
    'cheryl','hannah','jacqueline','martha','gloria','teresa','ann','sara','madison','frances',
    'kathryn','janice','jean','abigail','alice','julia','judy','sophia','grace','denise',
    'amber','doris','marilyn','danielle','beverly','isabella','theresa','diana','natalie','brittany',
    'charlotte','marie','kayla','alexis','lori','tatyana','vladina','apeksha','aasif','alicia',
    'chyna','vanessa','vijay','tatiana','eliot','eliott','garey','gabrriel','aidan','brooks',
    'erik','bertha','denzil','fahed'
) | ForEach-Object { $_.ToLowerInvariant() }
$CommonFirstNameSet = @{}
foreach ($n in $CommonFirstNames) { $CommonFirstNameSet[$n] = $true }

function Test-LooksLikePersonName {
    param([string]$Name)
    if ($Name -notmatch '^([A-Za-z]+)[-.]([A-Za-z]+)$') { return $false }
    $first = ($Name -split '[-.]')[0].ToLowerInvariant()
    return $CommonFirstNameSet.ContainsKey($first)
}

$JunkPatterns = @(
    @{ Regex = '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; Reason = 'GUID' }
    @{ Regex = '^(CHG|INC|CTASK|TASK|PRJ|REQ|RITM|WO|KB)\d{4,}'                ; Reason = 'Ticket/Change number' }
    @{ Regex = '_\d{2}-\d{2}-\d{4}_\d{2}-\d{2}-(AM|PM)$'                       ; Reason = 'Auto-generated dated duplicate' }
    @{ Regex = '^\d{1,2}[-.]\d{1,2}[-.]\d{4}$'                                  ; Reason = 'Bare date folder' }
    @{ Regex = '^\d{4}-\d{2}-\d{2}$'                                            ; Reason = 'Bare ISO date folder' }
    @{ Regex = '^\d+(\.\d+){2,}$'                                              ; Reason = 'Version number only' }
    @{ Regex = '^[A-Za-z]$'                                                    ; Reason = 'Single letter' }
)

function Get-JunkReason {
    param([string]$Name)
    foreach ($p in $JunkPatterns) {
        if ($Name -match $p.Regex) { return $p.Reason }
    }
    if (Test-LooksLikePersonName -Name $Name) { return 'Looks like a person name' }
    return $null
}

# ----------------------------------------------------------------------------
# 4. Build icon lookup tables (unchanged)
# ----------------------------------------------------------------------------
$IconIndex = @{}
$IconKeysByLength = @{}

foreach ($iconFile in $iconFilesRaw) {
    $baseName = Get-IconBaseName -FileName $iconFile
    $coreName = Get-IconCoreName -BaseName $baseName

    foreach ($candidateName in @($baseName, $coreName) | Select-Object -Unique) {
        $key = Get-NormalizedKey -Name $candidateName
        if ($key -eq '') { continue }
        if (-not $IconIndex.ContainsKey($key)) {
            $IconIndex[$key] = New-Object System.Collections.Generic.List[string]
        }
        if (-not $IconIndex[$key].Contains($iconFile)) {
            $IconIndex[$key].Add($iconFile)
        }
    }
}
foreach ($key in $IconIndex.Keys) {
    $len = $key.Length
    if (-not $IconKeysByLength.ContainsKey($len)) {
        $IconKeysByLength[$len] = New-Object System.Collections.Generic.List[string]
    }
    $IconKeysByLength[$len].Add($key)
}

Write-Host "Indexed $($IconIndex.Keys.Count) unique normalized icon keys." -ForegroundColor Cyan

# ----------------------------------------------------------------------------
# 5. Load previous results (composite key: Name|RelativePath)
# ----------------------------------------------------------------------------
$PreviousByKey = @{}

if ($NoCarryForward) {
    Write-Host 'NoCarryForward set: starting with blank Status/Notes for every folder.' -ForegroundColor Yellow
}
else {
    if (-not $PreviousResultsPath) {
        $autoFound = Get-ChildItem -Path $OutputPath -Filter 'IconAlignmentReport_*.csv' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'IconAlignmentReport_Latest.csv' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($autoFound) { $PreviousResultsPath = $autoFound.FullName }
    }

    if ($PreviousResultsPath -and (Test-Path $PreviousResultsPath)) {
        Write-Host "Carrying forward Status/Notes from: $PreviousResultsPath" -ForegroundColor Cyan
        try {
            $prevRows = Import-Csv -Path $PreviousResultsPath
            foreach ($row in $prevRows) {
                $key = if ($row.RelativePath) {
                    "$($row.FolderName)|$($row.RelativePath)"
                } else {
                    $row.FolderName
                }
                if ($key) {
                    $PreviousByKey[$key] = $row
                }
            }
        } catch {
            Write-Warning "Could not parse previous results file '$PreviousResultsPath'. Starting fresh. Error: $_"
        }
    }
}

# ----------------------------------------------------------------------------
# 6. Classify every folder entry
# ----------------------------------------------------------------------------
$results     = New-Object System.Collections.Generic.List[object]
$totalCount  = $folderEntries.Count
$processed   = 0
$progressTimer = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "Classifying $totalCount folder entries against the icon index..." -ForegroundColor Cyan

foreach ($entry in $folderEntries) {
    $folder = $entry.Name
    $relativePath = $entry.RelativePath

    $processed++

    # Reduced frequency + safer progress handling for VS Code
    if ($processed % 200 -eq 0 -or $progressTimer.Elapsed.TotalSeconds -ge 3) {
        $pct = [Math]::Round(($processed / $totalCount) * 100, 1)
        
        # Use Write-Host only (more reliable in VS Code)
        Write-Host "  ...$processed / $totalCount folder entries classified ($pct%)" -ForegroundColor DarkGray
        
        # Try Write-Progress but make it less aggressive
        try {
            Write-Progress -Activity 'Classifying folders' `
                          -Status "$processed of $totalCount ($pct%)" `
                          -PercentComplete $pct
        } catch { }
        
        $progressTimer.Restart()
    }

    $normKey = Get-NormalizedKey -Name $folder

    $section       = $null
    $matchedIcon   = $null
    $suggestion    = $null
    $reason        = $null

    # --- Exact normalized match -------------------------------------------------
    if ($normKey -ne '' -and $IconIndex.ContainsKey($normKey)) {
        $section     = 'Matched'
        $matchedIcon = ($IconIndex[$normKey] | Select-Object -First 1)
    }
    else {
        # --- Junk check ---------------------------------------------------------
        $junkReason = Get-JunkReason -Name $folder
        if ($junkReason) {
            $section = 'Junk'
            $reason  = $junkReason
        }
        else {
            # --- Fuzzy / close-match check --------------------------------------
            $threshold = Get-FuzzyThreshold -Length $normKey.Length
            $bestDist  = [int]::MaxValue
            $bestKey   = $null

            if ($threshold -gt 0) {
                $minLen = $normKey.Length - $threshold
                $maxLen = $normKey.Length + $threshold
                for ($candLen = $minLen; $candLen -le $maxLen; $candLen++) {
                    if (-not $IconKeysByLength.ContainsKey($candLen)) { continue }
                    foreach ($candKey in $IconKeysByLength[$candLen]) {
                        $dist = Get-LevenshteinDistance -A $normKey -B $candKey -MaxDistance $threshold
                        if ($dist -lt $bestDist) {
                            $bestDist = $dist
                            $bestKey  = $candKey
                        }
                        if ($bestDist -eq 0) { break }
                    }
                    if ($bestDist -eq 0) { break }
                }
            }

            if ($bestKey -and $bestDist -gt 0 -and $bestDist -le $threshold) {
                $section    = 'CloseMatch'
                $closeIcon  = ($IconIndex[$bestKey] | Select-Object -First 1)
                $suggestion = $closeIcon
                $reason     = "Within $bestDist character edit(s) of icon '$closeIcon'. Rename the folder to match, or rename/add an icon to match the folder."
            }
            else {
                $section = 'MissingIcon'
                $reason  = 'No matching or close icon found. Needs a new icon, or this folder name should be standardized to match an existing one.'
            }
        }
    }

    # --- Carry forward previous Status/Notes -----------------------------------
    $status = ''
    $notes  = ''
    $compositeKey = "$folder|$relativePath"
    if ($PreviousByKey.ContainsKey($compositeKey)) {
        $prev = $PreviousByKey[$compositeKey]
        if ($prev.PSObject.Properties.Match('Status').Count -gt 0) { $status = $prev.Status }
        if ($prev.PSObject.Properties.Match('Notes').Count  -gt 0) { $notes  = $prev.Notes }
    }

    $results.Add([PSCustomObject]@{
        FolderName    = $folder
        RelativePath  = $relativePath
        MatchedIcon   = $matchedIcon
        SuggestedIcon = $suggestion
        Status        = $status
        Notes         = $notes
        Section       = $section
        Reason        = $reason
        
    })
}

# Ensure progress is cleared
Write-Progress -Activity 'Classifying folders' -Completed
Write-Host "Classification complete: $totalCount folder entries processed." -ForegroundColor Green

# ----------------------------------------------------------------------------
# 7. Order sections so the file reads as a worklist
# ----------------------------------------------------------------------------
$sectionOrder = @{ 'MissingIcon' = 0; 'CloseMatch' = 1; 'Junk' = 2; 'Matched' = 3 }
$ordered = $results | Sort-Object `
    @{ Expression = { $sectionOrder[$_.Section] } }, `
    @{ Expression = { $_.FolderName } }

# ----------------------------------------------------------------------------
# 8. Write output - ONLY Latest.csv (no timestamped files)
# ----------------------------------------------------------------------------
$latestPath = Join-Path $OutputPath 'IconAlignmentReport_Latest.csv'

Write-Host "Writing/updating IconAlignmentReport_Latest.csv ..." -ForegroundColor Cyan
$ordered | Export-Csv -Path $latestPath -NoTypeInformation -Encoding UTF8

Write-Host "Report updated successfully at: $latestPath" -ForegroundColor Green

# ----------------------------------------------------------------------------
# 9. Console summary
# ----------------------------------------------------------------------------
$counts = $results | Group-Object Section | Sort-Object Name | ForEach-Object {
    [PSCustomObject]@{ Section = $_.Name; Count = $_.Count }
}

Write-Host ''
Write-Host '=== Icon Alignment Summary ===' -ForegroundColor Green
$counts | Format-Table -AutoSize | Out-String | Write-Host

$missingNotDone = ($results | Where-Object { $_.Section -eq 'MissingIcon' -and $_.Status -ne 'Done' -and $_.Status -ne 'Ignore' }).Count
$closeNotDone   = ($results | Where-Object { $_.Section -eq 'CloseMatch'  -and $_.Status -ne 'Done' -and $_.Status -ne 'Ignore' }).Count
$junkNotDone    = ($results | Where-Object { $_.Section -eq 'Junk'        -and $_.Status -ne 'Done' -and $_.Status -ne 'Ignore' }).Count

Write-Host "Outstanding MissingIcon items : $missingNotDone" -ForegroundColor Yellow
Write-Host "Outstanding CloseMatch items  : $closeNotDone"   -ForegroundColor Yellow
Write-Host "Outstanding Junk items        : $junkNotDone"    -ForegroundColor Yellow
Write-Host ''
Write-Host "Full report written to:" -ForegroundColor Cyan
Write-Host "  $latestPath  (your working file - updates on every run)" 
Write-Host ''
Write-Host "Workflow reminder:" -ForegroundColor Cyan
Write-Host "  1. Open IconAlignmentReport_Latest.csv and work top-down."
Write-Host "  2. Use the RelativePath column to quickly locate folders."
Write-Host "  3. Mark Status = 'Done' or 'Ignore' as you fix things."
Write-Host "  4. Re-run this script anytime - your progress is carried forward."

if ($missingNotDone -eq 0 -and $closeNotDone -eq 0) {
    Write-Host ''
    Write-Host 'All folders are aligned with an icon. Nice work!' -ForegroundColor Green
}