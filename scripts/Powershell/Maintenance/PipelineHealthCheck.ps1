Write-Host "`n=== ICONMATRIX PIPELINE HEALTH CHECK ===`n" -ForegroundColor Cyan

$paths = @{
    Source    = ".\source-icons"
    Processed = ".\processed-icons"
    Manifest  = ".\config\icon-manifest.json"
    Registry  = ".\registry\icons.json"
    Theme     = ".\theme\icons-theme.json"
}

function Get-EntryCount {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    # Directory handling
    if (Test-Path $Path -PathType Container) {
        return (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
    }

    # JSON file handling (real fix)
    try {
        $json = Get-Content $Path -Raw | ConvertFrom-Json

        if ($json -is [System.Collections.IDictionary]) {
            return ($json.PSObject.Properties | Measure-Object).Count
        }

        if ($json.PSObject.Properties) {
            return ($json.PSObject.Properties | Measure-Object).Count
        }

        return 1
    }
    catch {
        return -1
    }
}

foreach ($p in $paths.GetEnumerator()) {

    $count = Get-EntryCount $p.Value

    if ($null -eq $count) {
        Write-Host "MISSING -> $($p.Key)" -ForegroundColor Red
    }
    elseif ($count -eq -1) {
        Write-Host "ERROR   -> $($p.Key): invalid JSON" -ForegroundColor Red
    }
    else {
        Write-Host "OK      -> $($p.Key): $count entries" -ForegroundColor Green
    }
}

Write-Host "`nDONE`n"