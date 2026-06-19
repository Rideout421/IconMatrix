function Invoke-SemanticInference {
    param(
        [Parameter(Mandatory)]
        [string]$MappingsPath,

        [Parameter(Mandatory)]
        [string]$AutoMappingsPath,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    Write-Host "`n=== Semantic Inference (FULL MERGE MODE) ===" -ForegroundColor Cyan

    if (-not (Test-Path $MappingsPath)) {
        throw "MappingsPath not found: $MappingsPath"
    }

    if (-not (Test-Path $AutoMappingsPath)) {
        throw "AutoMappingsPath not found: $AutoMappingsPath"
    }

    # ========================= LOAD =========================
    $baseMap = Get-Content $MappingsPath -Raw | ConvertFrom-Json
    $autoMap = Get-Content $AutoMappingsPath -Raw | ConvertFrom-Json

    # ========================= FORCE HASHTABLES =========================
    $semantic = @{
        extensions  = @{}
        fileNames   = @{}
        folderNames = @{}
    }

    # ========================= SAFE ADD =========================
    function Add-ToMap {
        param($map, $key, $value)

        if (-not $key -or -not $value) { return }

        if (-not $map[$key]) {
            $map[$key] = @()
        }

        if ($map[$key] -notcontains $value) {
            $map[$key] += $value
        }
    }

    # ========================= BASE MERGE =========================
    foreach ($k in $baseMap.extensions.PSObject.Properties.Name) {
        foreach ($v in $baseMap.extensions.$k) {
            Add-ToMap $semantic.extensions $k $v
        }
    }

    foreach ($k in $baseMap.fileNames.PSObject.Properties.Name) {
        foreach ($v in $baseMap.fileNames.$k) {
            Add-ToMap $semantic.fileNames $k $v
        }
    }

    foreach ($k in $baseMap.folderNames.PSObject.Properties.Name) {
        foreach ($v in $baseMap.folderNames.$k) {
            Add-ToMap $semantic.folderNames $k $v
        }
    }

    # ========================= AUTO MERGE =========================
    foreach ($p in $autoMap.fileNames.PSObject.Properties) {
        foreach ($v in $p.Value) {
            Add-ToMap $semantic.fileNames $p.Name $v
        }
    }

    foreach ($p in $autoMap.folderNames.PSObject.Properties) {
        foreach ($v in $p.Value) {
            Add-ToMap $semantic.folderNames $p.Name $v
        }
    }

    foreach ($p in $autoMap.extensions.PSObject.Properties) {
        foreach ($v in $p.Value) {
            Add-ToMap $semantic.extensions $p.Name $v
        }
    }

    # ========================= DEDUPE CLEANUP =========================
    foreach ($section in @("extensions","fileNames","folderNames")) {

        foreach ($k in @($semantic[$section].Keys)) {
            $semantic[$section][$k] =
                @($semantic[$section][$k] | Select-Object -Unique)
        }
    }

    # ========================= VALIDATION =========================
    if ($semantic.extensions.Count -eq 0 -and
        $semantic.fileNames.Count -eq 0 -and
        $semantic.folderNames.Count -eq 0) {
        throw "Semantic inference produced empty result"
    }

    # ========================= OUTPUT =========================
    $json = $semantic | ConvertTo-Json -Depth 30
    Set-Content -Path $OutputPath -Value $json -Encoding UTF8

    Write-Host "[OK] Semantic inference complete -> $OutputPath" -ForegroundColor Green
    Write-Host "[INFO] extensions  : $($semantic.extensions.Count)" -ForegroundColor Cyan
    Write-Host "[INFO] fileNames   : $($semantic.fileNames.Count)" -ForegroundColor Cyan
    Write-Host "[INFO] folderNames : $($semantic.folderNames.Count)" -ForegroundColor Cyan
}