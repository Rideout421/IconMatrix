# =============================================================================
# IconResolver.ps1 - Cleans icon filenames for registry + theme mapping
# =============================================================================

function Resolve-IconName {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        
        [string]$Kind = "file"
    )

    # Optional: Reduce spam in normal runs
    # Write-Host "DEBUG Resolve-IconName: Key=[$Key] Kind=[$Kind]" -ForegroundColor Magenta

    if ([string]::IsNullOrWhiteSpace($Key)) {
        return @($Key)
    }

    $original = $Key.ToLower().Trim()

    # Remove common prefixes
    $clean = $original -replace '^(file|folder|icon|light|dark|open|closed|expanded)-', ''

    # Special handling for common patterns
    switch -Regex ($clean) {
        '^rootfolder' { return @("rootfolder") }
        '^ps1folder'  { return @("ps1folder") }
        default { }
    }

    # Return multiple possible keys if needed (most important first)
    $candidates = @($clean)

    # If it still starts with "file" or "folder" after cleaning, keep original as fallback
    if ($original -like "file*" -and $clean -notlike "file*") {
        $candidates += $original
    }
    if ($original -like "folder*" -and $clean -notlike "folder*") {
        $candidates += $original
    }

    return $candidates
}

# Optional helper to test it
function Test-Resolve-IconName {
    param([string]$Key)
    Resolve-IconName -Key $Key | ForEach-Object {
        Write-Host "$Key  =>  $_" -ForegroundColor Cyan
    }
}