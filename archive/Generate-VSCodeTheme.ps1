function Generate-VSCodeTheme {
    param(
        [string]$ProcessedPath,
        [string]$OutputPath,
        [switch]$DryRun
    )

    $theme = @{
        iconDefinitions = @{}
        file = @{}
        folder = @{}
        fileExtensions = @{}
        fileNames = @{}
        languageIds = @{}
    }

    $target = Join-Path $OutputPath "theme/icons-theme.json"
    $dir = Split-Path $target -Parent

    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    Get-ChildItem $ProcessedPath -Filter *.png | ForEach-Object {
        $name = $_.BaseName

        $theme.iconDefinitions[$name] = @{
            iconPath = "./processed-icons/$($_.Name)"
        }
    }

    $json = $theme | ConvertTo-Json -Depth 10

    if ($DryRun) {
        Write-Host "[DRYRUN] WRITE THEME -> $target"
        return
    }

    $json | Out-File -FilePath $target -Encoding UTF8
}