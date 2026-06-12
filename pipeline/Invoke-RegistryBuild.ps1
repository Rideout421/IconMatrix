param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [switch]$DryRun
)
function Invoke-RegistryBuild {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [switch]$DryRun
    )

    Write-Host "`n=== Registry Build (IconMatrix) ===" -ForegroundColor Cyan

    # HARD DEBUG
    Write-Host "[DEBUG] PARAM Path       = [$Path]" -ForegroundColor Yellow
    Write-Host "[DEBUG] PARAM OutputPath = [$OutputPath]" -ForegroundColor Yellow

    # FORCE processed-icons
    $Path = Join-Path $PSScriptRoot "..\processed-icons"
    $Path = (Resolve-Path $Path -ErrorAction Stop).Path

    Write-Host "[DEBUG] FORCED ICON PATH = [$Path]" -ForegroundColor Green

    if (-not (Test-Path $Path)) {
        throw "processed-icons folder missing -> $Path"
    }

    $files = Get-ChildItem `
        -Path $Path `
        -File `
        -Recurse `
        -Filter "*.png" `
        -ErrorAction Stop

    Write-Host "[DEBUG] PNG COUNT = $($files.Count)" -ForegroundColor Cyan

    if ($files.Count -eq 0) {
        throw "ZERO PNG FILES FOUND IN: $Path"
    }
    
    # =========================
    # RESOLVE PATH (CRITICAL FIX)
    # =========================
    $resolvedPath = Resolve-Path $Path -ErrorAction Stop

    Write-Host "[DEBUG] Input Path     = $Path" -ForegroundColor DarkCyan
    Write-Host "[DEBUG] Resolved Path  = $resolvedPath" -ForegroundColor DarkCyan

    # =========================
    # RAW ICON COLLECTION
    # =========================
    $icons = @{}

    $files = Get-ChildItem -Path $resolvedPath -Recurse -File -ErrorAction Stop |
             Where-Object { $_.Extension -eq ".png" }

    Write-Host "[DEBUG] PNG files found = $($files.Count)" -ForegroundColor DarkCyan

    foreach ($file in $files) {
        $base = $file.BaseName.ToLower()

        $icons[$base] = @{
            file = $file.Name
            path = $file.FullName
        }
    }

    Write-Host "[DEBUG] Icons discovered = $($icons.Count)" -ForegroundColor DarkCyan
    Write-Host "[DEBUG KEYS] $($icons.Keys -join ', ')" -ForegroundColor DarkCyan

    # =========================
    # DERIVED STRUCTURES
    # =========================
    $fileExtensions  = @{}
    $fileNames       = @{}
    $iconDefinitions = @{}

    foreach ($key in $icons.Keys) {

        $iconId = "$key-icon"

        # ICON DEFINITIONS
        $iconDefinitions[$iconId] = @{
            iconPath = "./processed-icons/$($icons[$key].file)"
        }

        # PRIMARY: extension = icon name
        $ext = $key.ToLower()

        if (-not $fileExtensions.ContainsKey($ext)) {
            $fileExtensions[$ext] = $iconId
        }

        if (-not $fileNames.ContainsKey($ext)) {
            $fileNames[$ext] = $iconId
        }

        # TOKEN SPLIT SUPPORT
        $parts = $key -split "[-_\.]"

        foreach ($p in $parts) {
            if (-not [string]::IsNullOrWhiteSpace($p)) {

                $p = $p.ToLower()

                if (-not $fileExtensions.ContainsKey($p)) {
                    $fileExtensions[$p] = $iconId
                }

                if (-not $fileNames.ContainsKey($p)) {
                    $fileNames[$p] = $iconId
                }
            }
        }
    }

    # =========================
    # DEFAULT FALLBACKS
    # =========================
    $defaults = @{
        "ps1"  = "powershell-icon"
        "json" = "json-icon"
        "md"   = "markdown-icon"
        "txt"  = "text-icon"
        "yml"  = "yaml-icon"
        "yaml" = "yaml-icon"
        "xml"  = "xml-icon"
        "js"   = "javascript-icon"
        "ts"   = "typescript-icon"
        "docx" = "word-icon"
    }

    foreach ($k in $defaults.Keys) {
        if (-not $fileExtensions.ContainsKey($k)) {
            $fileExtensions[$k] = $defaults[$k]
        }
    }

    # =========================
    # OUTPUT STRUCTURE
    # =========================
    $registryOutput = @{
        iconDefinitions = $iconDefinitions
        fileExtensions  = $fileExtensions
        fileNames       = $fileNames
    }

    # =========================
    # DRY RUN
    # =========================
    if ($DryRun) {
        Write-Host "[DRYRUN] Icons: $($icons.Count)" -ForegroundColor Yellow
        Write-Host "[DRYRUN] Extensions: $($fileExtensions.Count)" -ForegroundColor Yellow
        Write-Host "[DRYRUN] Names: $($fileNames.Count)" -ForegroundColor Yellow
        return
    }

    # =========================
    # WRITE OUTPUT
    # =========================
    $dir = Split-Path $OutputPath -Parent

    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $json = $registryOutput | ConvertTo-Json -Depth 50

    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "Registry JSON generation failed"
    }

    Set-Content -Path $OutputPath -Value $json -Encoding UTF8

    if (-not (Test-Path $OutputPath)) {
        throw "Registry file was not created: $OutputPath"
    }

    Write-Host "[OK] Registry generated" -ForegroundColor Green
    Write-Host "[DEBUG] Icons: $($icons.Count)" -ForegroundColor DarkCyan
    Write-Host "[DEBUG] Extensions: $($fileExtensions.Count)" -ForegroundColor DarkCyan
    Write-Host "[DEBUG] Names: $($fileNames.Count)" -ForegroundColor DarkCyan

    
}