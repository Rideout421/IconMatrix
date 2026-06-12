function Invoke-RegistryBuild {
    param(
        [Parameter(Mandatory)]
        [string]$InputPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [switch]$DryRun
    )

    Write-Host "`n=== Registry Build (IconMatrix) ===" -ForegroundColor Cyan

    # ========================= INPUT RESOLVE =========================
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        throw "InputPath is empty"
    }

    if (-not [System.IO.Path]::IsPathRooted($InputPath)) {
        $InputPath = Join-Path $PSScriptRoot $InputPath
    }

    $resolvedInput = (Resolve-Path $InputPath -ErrorAction Stop | Select-Object -ExpandProperty Path)

    if (-not (Test-Path $resolvedInput)) {
        throw "Input folder not found: $resolvedInput"
    }

    # ========================= OUTPUT VALIDATION =========================
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        throw "OutputPath is empty"
    }

    if (Test-Path $OutputPath -PathType Container) {
        throw "OutputPath must be a FILE, not a DIRECTORY: $OutputPath"
    }

    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # ========================= SCAN FILES =========================
    $files = Get-ChildItem -Path $resolvedInput -Recurse -File -Filter "*.png"

    if (-not $files -or $files.Count -eq 0) {
        throw "No PNG files found in: $resolvedInput"
    }

    # ========================= BUILD ICON MAP =========================
    $icons = @{}
    $basePath = (Get-Item $resolvedInput).FullName

    foreach ($file in $files) {
        $base = $file.BaseName.ToLower()

        $relativePart = $file.FullName.Substring($basePath.Length).TrimStart('\','/')
        $relativePart = $relativePart -replace '\\','/'

        if (-not $icons.ContainsKey($base)) {
            $icons[$base] = @{
                file         = $file.Name
                relativePath = $relativePart
                fullPath     = $file.FullName
            }
        }
    }

    # ========================= REGISTRY BUILD =========================
    $iconDefinitions = @{}
    $fileExtensions  = @{}
    $fileNames       = @{}

    foreach ($key in ($icons.Keys | Sort-Object)) {

        $iconId = "$key-icon"

        $iconDefinitions[$iconId] = @{
            iconPath = "./processed-icons/$($icons[$key].relativePath)"
        }

        if (-not $fileExtensions.ContainsKey($key)) { $fileExtensions[$key] = $iconId }
        if (-not $fileNames.ContainsKey($key))       { $fileNames[$key] = $iconId }

        $parts = $key -split '[-_\.]'
        foreach ($part in $parts) {
            $p = $part.ToLower()
            if ([string]::IsNullOrWhiteSpace($p)) { continue }

            if (-not $fileExtensions.ContainsKey($p)) { $fileExtensions[$p] = $iconId }
            if (-not $fileNames.ContainsKey($p))       { $fileNames[$p] = $iconId }
        }
    }

    # ========================= DEFAULTS =========================
    $defaults = @{
        ps1   = "powershell-icon"
        json  = "json-icon"
        md    = "markdown-icon"
        txt   = "text-icon"
        yml   = "yaml-icon"
        yaml  = "yaml-icon"
        xml   = "xml-icon"
        js    = "javascript-icon"
        ts    = "typescript-icon"
        docx  = "word-icon"
    }

    foreach ($k in $defaults.Keys) {
        if (-not $fileExtensions.ContainsKey($k)) {
            $fileExtensions[$k] = $defaults[$k]
        }
    }

    # ========================= DRY RUN =========================
    if ($DryRun) {
        Write-Host "[DRYRUN] Registry build complete (no write)"
        return
    }

    # ========================= WRITE OUTPUT =========================
    $out = [ordered]@{
        iconDefinitions = $iconDefinitions
        fileExtensions  = $fileExtensions
        fileNames       = $fileNames
    }

    $json = $out | ConvertTo-Json -Depth 50

    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "JSON serialization failed"
    }

    Set-Content -Path $OutputPath -Value $json -Encoding UTF8

    Write-Host "[OK] Registry written -> $OutputPath"
}