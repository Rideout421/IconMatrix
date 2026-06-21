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
         the previous run is carried forward automatically (matched by folder name) so you don't
         lose your progress. The MissingIcon/CloseMatch/Junk lists should get smaller each time
         as you clean things up.

    Matching logic:
      - "Matched"     : folder name and an icon name are identical once both are normalized
                        (case, spaces, dashes, underscores, punctuation all stripped). This is
                        why "IP-Route" maps to a folder named "IPRoute" -- dashes are fine and
                        DO map, as you found out. Nothing here treats a dash as a mismatch.
      - "CloseMatch"  : not an exact normalized match, but a small edit-distance away from an
                        existing icon (e.g. plural/singular: "certs" vs "cert", or a near-typo).
                        These are YOUR call: rename the folder to match the icon exactly, or go
                        get/rename an icon to match the folder. The script never auto-changes
                        anything.
      - "Junk"        : folder names that should NEVER get an icon -- GUIDs, change/incident
                        ticket numbers (CHG#######, INC#######, etc.), pure date stamps, the
                        auto-generated "<Name>_MM-DD-YYYY_HH-MM-(AM|PM)" duplicate-folder copies,
                        version-number-only folders, and folders that are just a person's first
                        and last name (checked against a common first-name list -- NOT a guess
                        based on capitalization shape, since things like "Cisco-Switches" or
                        "Access-Points" have the exact same shape as "Aasif-Bagdadi" but are
                        real categories). These are flagged for you to delete/archive/rename,
                        not to icon.
      - "MissingIcon" : everything left over. Looks like a legitimate category folder, no icon
                        exists for it yet, and it didn't fuzzy-match anything close enough to
                        suggest a rename. This is your "go get an icon" shopping list.

    The script is intentionally conservative about auto-classifying "Junk". When it isn't sure,
    it leaves the folder in MissingIcon/CloseMatch for YOU to decide, rather than guessing wrong.

.PARAMETER GitHubCaptureScript
    Path to GitHub.ps1, which scans the workspace and refreshes GitHubFolders.txt.
    Default: $env:GIT_ROOT\IconMatrix\scripts\Powershell\FolderCapture\GitHub.ps1

.PARAMETER IconsCaptureScript
    Path to Icons.ps1, which scans the icon library and refreshes Icons.txt.
    Default: $env:GIT_ROOT\IconMatrix\scripts\Powershell\FileCapture\Icons.ps1

.PARAMETER SkipRefresh
    Switch. If set, GitHub.ps1 and Icons.ps1 are NOT run, and this script reads whatever
    GitHubFolders.txt/Icons.txt already exist as-is. Useful only when you deliberately want to
    audit a stale/frozen snapshot; normally you want the default (fresh data every run).

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
    Status and your Notes in the new run, instead of resetting to blank every time.

.PARAMETER NoCarryForward
    Switch. If set, Status/Notes are NOT carried forward from any previous report -- every
    folder starts with a blank Status and Notes, even if a previous report exists. Use this for
    a genuine fresh start (e.g. you want to re-review everything from scratch).

.EXAMPLE
    .\FindMissingIcons.ps1
    Refreshes folder/icon data, then runs the audit.

.EXAMPLE
    .\FindMissingIcons.ps1 -SkipRefresh
    Audits whatever GitHubFolders.txt/Icons.txt already exist, without re-capturing.

.EXAMPLE
    .\FindMissingIcons.ps1 -NoCarryForward
    Runs normally, but starts every folder with a blank Status/Notes instead of carrying
    forward a previous report.

.EXAMPLE
    .\FindMissingIcons.ps1 -FoldersPath "D:\custom\GitHubFolders.txt" -IconsPath "D:\custom\Icons.txt" -SkipRefresh
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
# 0. Refresh folder/icon data so we never audit against stale data.
#    GitHub.ps1 and Icons.ps1 already write straight to logs\GitHubFolders.txt and
#    logs\Icons.txt, so running them here guarantees both files reflect the current
#    state of the workspace before we read them below.
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
$folders = Get-Content -Path $FoldersPath -Encoding UTF8 |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne '' }

$iconFilesRaw = Get-Content -Path $IconsPath -Encoding UTF8 |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne '' }

Write-Host "Loaded $($folders.Count) folders and $($iconFilesRaw.Count) icon files." -ForegroundColor Cyan

# ----------------------------------------------------------------------------
# 2. Helper functions
# ----------------------------------------------------------------------------

# Strip known image extensions from an icon filename.
function Get-IconBaseName {
    param([string]$FileName)
    return [regex]::Replace($FileName, '\.(png|jpe?g|svg)$', '', 'IgnoreCase')
}

# Strip the vscode-icons-style prefixes so "file_type_docker" and "folder_type_docker"
# both reduce down to "docker" for comparison purposes.
function Get-IconCoreName {
    param([string]$BaseName)
    return [regex]::Replace($BaseName, '^(file_type_|folder_type_)', '', 'IgnoreCase')
}

# Normalize: lowercase, strip every character that isn't a letter or digit.
# This is deliberately dash/underscore/space/punctuation-agnostic, since dashes
# in icon names (e.g. "IP-Route") DO map to folders without dashes ("IPRoute"),
# and vice versa -- the only thing that matters is the letters/numbers lining up.
function Get-NormalizedKey {
    param([string]$Name)
    return ([regex]::Replace($Name.ToLowerInvariant(), '[^a-z0-9]', ''))
}

# Simple iterative Levenshtein distance (edit distance) between two strings.
function Get-LevenshteinDistance {
    param([string]$A, [string]$B)

    $lenA = $A.Length
    $lenB = $B.Length
    if ($lenA -eq 0) { return $lenB }
    if ($lenB -eq 0) { return $lenA }

    $prev = New-Object int[] ($lenB + 1)
    for ($j = 0; $j -le $lenB; $j++) { $prev[$j] = $j }

    for ($i = 1; $i -le $lenA; $i++) {
        $cur = New-Object int[] ($lenB + 1)
        $cur[0] = $i
        $charA = $A[$i - 1]
        for ($j = 1; $j -le $lenB; $j++) {
            $cost = if ($charA -eq $B[$j - 1]) { 0 } else { 1 }
            $delete    = $prev[$j] + 1
            $insert    = $cur[$j - 1] + 1
            $substitute = $prev[$j - 1] + $cost
            $cur[$j] = [Math]::Min([Math]::Min($delete, $insert), $substitute)
        }
        $prev = $cur
    }
    return $prev[$lenB]
}

# Length-aware fuzzy-match threshold. Short strings collide too easily (e.g. "AIX" vs "AI"
# is only 1 edit apart but means nothing), so short names simply don't get fuzzy-matched at
# all -- they either hit an exact normalized match or they don't. Longer names get a small,
# scaled allowance.
function Get-FuzzyThreshold {
    param([int]$Length)
    if ($Length -lt 5)  { return 0 }   # no fuzzy matching below this length
    if ($Length -le 7)  { return 1 }
    if ($Length -le 12) { return 2 }
    return 3
}

# ----------------------------------------------------------------------------
# 3. Junk detection (high-confidence patterns ONLY -- ambiguous cases fall
#    through to MissingIcon/CloseMatch for manual review rather than being
#    guessed at).
# ----------------------------------------------------------------------------

# Common first names used ONLY to catch "FirstName-LastName" / "FirstName.LastName"
# style folders. This is intentionally a dictionary check, not a capitalization-shape
# regex -- shape alone can't tell "Aasif-Bagdadi" apart from "Cisco-Switches" or
# "Access-Points", which look identical structurally but are real category folders.
# Extend this list freely if you find real people slipping through as MissingIcon.
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
    # Deliberately STRICT: only matches a clean two-token "First-Last" or "First.Last" shape.
    # Three-token names (e.g. "Doug-Van-Sach") are intentionally NOT auto-flagged here -- testing
    # against this exact dataset showed 3-token matching pulls in false positives like
    # "Melissa-Failure-FIX" (not a person) for every few real 3-token names it catches. Those
    # genuine 3-token person folders simply fall through to MissingIcon/CloseMatch instead, where
    # you'll see them and can mark them Ignore/Junk by hand -- safer than silently misclassifying
    # a real folder as junk.
    if ($Name -notmatch '^([A-Za-z]+)[-.]([A-Za-z]+)$') { return $false }
    $first = ($Name -split '[-.]')[0].ToLowerInvariant()
    return $CommonFirstNameSet.ContainsKey($first)
}

# High-confidence junk patterns. Each entry: regex + reason label.
# These are deliberately narrow. A folder only lands here if it is CLEARLY one of:
#   - a GUID
#   - a change/incident/task/ticket number
#   - the auto-generated "_MM-DD-YYYY_HH-MM-AM/PM" duplicate-folder suffix
#   - a bare date
#   - a bare version number
#   - a single letter
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
# 4. Build icon lookup tables
# ----------------------------------------------------------------------------

# Map: normalized key -> list of original icon filenames that produced it.
# We index BOTH the full base name and the "core" name (prefix stripped), so an icon like
# "folder_type_docker.svg" is reachable whether a folder is literally named "docker" or
# someone (unlikely, but safe) named a folder "FolderTypeDocker".
$IconIndex = @{}

# Keep a flat list of (NormalizedKey, OriginalFile) for fuzzy distance scanning.
$IconNormEntries = New-Object System.Collections.Generic.List[object]

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
    $IconNormEntries.Add([PSCustomObject]@{ Key = $key; Length = $key.Length })
}

Write-Host "Indexed $($IconIndex.Keys.Count) unique normalized icon keys." -ForegroundColor Cyan

# ----------------------------------------------------------------------------
# 5. Load previous results (so progress isn't lost between runs)
# ----------------------------------------------------------------------------
$PreviousByFolder = @{}

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
                if ($row.FolderName) {
                    $PreviousByFolder[$row.FolderName] = $row
                }
            }
        } catch {
            Write-Warning "Could not parse previous results file '$PreviousResultsPath'. Starting fresh. Error: $_"
        }
    }
}

# ----------------------------------------------------------------------------
# 6. Classify every folder
# ----------------------------------------------------------------------------
$results = New-Object System.Collections.Generic.List[object]

foreach ($folder in $folders) {

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
        # --- Junk check (only if not already matched) --------------------------
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
                foreach ($entry in $IconNormEntries) {
                    if ([Math]::Abs($entry.Length - $normKey.Length) -gt $threshold) { continue }
                    $dist = Get-LevenshteinDistance -A $normKey -B $entry.Key
                    if ($dist -lt $bestDist) {
                        $bestDist = $dist
                        $bestKey  = $entry.Key
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

    # --- Carry forward previous Status/Notes if present ------------------------
    $status = ''
    $notes  = ''
    if ($PreviousByFolder.ContainsKey($folder)) {
        $prev = $PreviousByFolder[$folder]
        if ($prev.PSObject.Properties.Match('Status').Count -gt 0) { $status = $prev.Status }
        if ($prev.PSObject.Properties.Match('Notes').Count  -gt 0) { $notes  = $prev.Notes }
    }

    $results.Add([PSCustomObject]@{
        Section       = $section
        FolderName    = $folder
        MatchedIcon   = $matchedIcon
        SuggestedIcon = $suggestion
        Reason        = $reason
        Status        = $status   # fill in by hand: Done / Ignore / blank = not started
        Notes         = $notes    # free text for yourself
    })
}

# ----------------------------------------------------------------------------
# 7. Order sections so the file reads as a worklist:
#    MissingIcon first (go get icons), then CloseMatch (rename decisions),
#    then Junk (cleanup candidates), then Matched last (already correct, for reference).
# ----------------------------------------------------------------------------
$sectionOrder = @{ 'MissingIcon' = 0; 'CloseMatch' = 1; 'Junk' = 2; 'Matched' = 3 }
$ordered = $results | Sort-Object `
    @{ Expression = { $sectionOrder[$_.Section] } }, `
    @{ Expression = { $_.FolderName } }

# ----------------------------------------------------------------------------
# 8. Write output
# ----------------------------------------------------------------------------
$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm'
$csvPath   = Join-Path $OutputPath "IconAlignmentReport_$timestamp.csv"
$ordered | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

# Always also drop/refresh a stable, non-timestamped copy so you (or other scripts) can
# point at one consistent filename, while the timestamped copy preserves history.
$latestPath = Join-Path $OutputPath 'IconAlignmentReport_Latest.csv'
$ordered | Export-Csv -Path $latestPath -NoTypeInformation -Encoding UTF8

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
Write-Host "  $csvPath"
Write-Host "  $latestPath  (stable filename for re-runs / other tooling)"
Write-Host ''
Write-Host "Workflow reminder:" -ForegroundColor Cyan
Write-Host "  1. Open the CSV, work top-down: MissingIcon -> CloseMatch -> Junk."
Write-Host "  2. As you fix each row (get/rename an icon, rename/remove a folder),"
Write-Host "     set its Status column to 'Done' (or 'Ignore' to permanently skip it)."
Write-Host "  3. Re-run this script any time. It auto-discovers the latest report in"
Write-Host "     '$OutputPath' and carries your Status/Notes forward by folder name."
Write-Host "  4. You're fully aligned when MissingIcon and CloseMatch are both empty."

if ($missingNotDone -eq 0 -and $closeNotDone -eq 0) {
    Write-Host ''
    Write-Host 'All folders are aligned with an icon. Nice work.' -ForegroundColor Green
}