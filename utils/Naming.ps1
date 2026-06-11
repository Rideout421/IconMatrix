function Get-CanonicalName {
    param([string]$Name)

    $n = $Name.ToLower().Trim()

    $map = @{
        "cisco meraki"       = "meraki"
        "meraki dashboard"   = "meraki"
        "amazon web services"= "aws"
        "aws cloud"          = "aws"
        "sentinel agent"     = "sentinelone"
        "crowd strike"       = "crowdstrike"
        "vmware esxi"        = "vmware"
        "powershell7"        = "powershell"
        "kuberneties"        = "kubernetes"
        "postgresql"         = "postgresql"
    }

    foreach ($key in $map.Keys) {
        if ($n -like "*$key*") {
            return $map[$key]
        }
    }

    # normalize separators
    $clean = $n -replace '[-_\s]+', ''

    # remove ONLY duplicate suffixes
    # brave-1 / brave1 / brave_2 -> brave
    $clean = $clean -replace '[-_]?(\d+)$', ''

    if ([string]::IsNullOrWhiteSpace($clean)) {
        return "unknown"
    }

    return $clean
}