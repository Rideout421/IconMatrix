function Resolve-IconName {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [string]$Kind = "file"
    )

    $original = $Key.ToLower().Trim()

    # Handle your common naming patterns
    $clean = $original `
        -replace '^(file|folder|foldertype|file_type|type|icon|light|dark|open|closed|expanded)-', '' `
        -replace '-icon$', '' `
        -replace '-opened$', '' `
        -replace '-closed$', ''

    # Special handling for common variants
    $clean = $clean -replace 'reactjs', 'react' `
                    -replace 'reactrouter', 'react' `
                    -replace 'reacttemplate', 'react'

    $candidates = @($clean)
    if ($clean -ne $original) {
        $candidates += $original
    }

    return $candidates
}