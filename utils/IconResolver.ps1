function Resolve-IconName {
    param(
        [string]$Key,
        [string]$Kind = "file",
        [string]$IconRoot
    )

    $candidates = @(
        "$Key.svg",
        "${Kind}_type_$Key.svg"
    )

    foreach ($name in $candidates) {
        $path = Join-Path $IconRoot $name
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}