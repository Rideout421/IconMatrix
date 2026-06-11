function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogPath
    )

    $line = "[$Level] $Message"
    Add-Content -Path $LogPath -Value $line
}