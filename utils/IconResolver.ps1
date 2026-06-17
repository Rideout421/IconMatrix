function Resolve-IconName {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [string]$Kind = "file"
    )

    $original = $Key.ToLower().Trim()

    # Tokens that carry no identity of their own and should be stripped from
    # the front/back of the name. IMPORTANT: this used to run each -replace
    # exactly once, so a double-prefixed name like "file-type-docker" only
    # had "file-" removed, leaving "type-docker" -- which then collided with
    # "folder-type-docker" (which had "folder-" removed, also leaving
    # "type-docker"). Both file and folder variants of completely different
    # icons were colliding into one ID. We now strip repeatedly until no
    # more noise tokens match, so "file-type-docker" fully reduces to
    # "docker" and "folder-type-docker" fully reduces to "docker" as well --
    # the file/folder distinction is then re-applied explicitly below
    # instead of being left to accidentally survive or not survive in the
    # leftover prefix.
    $noisePrefix = '^(file|folder|foldertype|filetype|file-type|folder-type|type|icon|light|dark|open|closed|expanded)-'
    $noiseSuffix = '-(icon|opened|open|closed|expanded)$'

    $clean = $original
    do {
        $before = $clean
        $clean = $clean -replace $noisePrefix, ''
        $clean = $clean -replace $noiseSuffix, ''
    } while ($clean -ne $before -and -not [string]::IsNullOrWhiteSpace($clean))

    if ([string]::IsNullOrWhiteSpace($clean)) {
        $clean = $original
    }

    # Special handling for common variants
    $clean = $clean -replace 'reactjs', 'react' `
                    -replace 'reactrouter', 'react' `
                    -replace 'reacttemplate', 'react'

    # Re-apply file/folder distinction explicitly, so a file icon and a
    # folder icon sharing the same underlying name (e.g. "docker") resolve
    # to two different icon IDs instead of merging into one. "Opened"/
    # "closed"/"expanded" states of the SAME folder are intentionally
    # collapsed together above (folder-type-docker and
    # folder-type-docker-opened both become "docker" here, then both
    # become "folder-docker") since they represent the same icon concept,
    # just a different visual state -- not a different icon.
    if ($Kind -eq "folder" -and $clean -notlike "folder-*") {
        $clean = "folder-$clean"
    }

    $candidates = @($clean)
    if ($clean -ne $original) {
        $candidates += $original
    }

    return $candidates
}