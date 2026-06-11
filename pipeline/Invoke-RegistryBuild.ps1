function Invoke-RegistryBuild {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [switch]$DryRun
    )

    Write-Host "`n-> Building registry..." -ForegroundColor Cyan

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Invoke-RegistryBuild: Path is empty"
    }

    if (-not (Test-Path $Path)) {
        throw "Source path missing -> $Path"
    }

    $registry = @{}

    Get-ChildItem $Path -File -Recurse |
        Where-Object { $_.Extension -eq ".png" } |
        ForEach-Object {

            $name = $_.BaseName

            $registry[$name] = @{
                file = $_.Name
                path = $_.FullName
            }
        }

    if ($DryRun) {
        Write-Host "-> DRYRUN (registry not written)" -ForegroundColor Yellow
        Write-Host "-> Would generate $($registry.Count) entries" -ForegroundColor Yellow
        return
    }

    $dir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $registry |
        ConvertTo-Json -Depth 10 |
        Out-File $OutputPath -Encoding UTF8

    Write-Host "-> Registry generated ($($registry.Count) entries)" -ForegroundColor Green
}