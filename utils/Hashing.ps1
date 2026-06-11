function Get-FileHashSHA256 {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}