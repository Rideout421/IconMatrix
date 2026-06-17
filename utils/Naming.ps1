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

    # normalize separators -> single hyphen (preserve word boundaries)
    # Previously this deleted separators entirely (file_type_docker ->
    # filetypedocker), which broke downstream prefix-stripping in
    # Resolve-IconName (it expects hyphen-delimited prefixes like "file-")
    # and also made unrelated names collide once digits were stripped below.
    $clean = $n -replace '[-_\s]+', '-'
    $clean = $clean.Trim('-')

    # NOTE: trailing digits are intentionally NOT stripped. Files like
    # docker.svg / docker2.svg / dockertest.svg / dockertest2.svg were
    # confirmed to be genuinely different icons, not numbered duplicates of
    # the same artwork. Collapsing them here caused real, distinct icons to
    # silently collide and vanish later in Invoke-IconNormalization.ps1's
    # "keep first, drop the rest" handling. Every distinct name must produce
    # a distinct canonical name.

    if ([string]::IsNullOrWhiteSpace($clean)) {
        return "unknown"
    }

    return $clean
}