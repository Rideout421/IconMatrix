function Resolve-IconName {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        
        [string]$Kind = "file"
        # ... other params
    )

    Write-Host "DEBUG Resolve-IconName: Key=[$Key] Kind=[$Kind]" -ForegroundColor Magenta

    if ([string]::IsNullOrWhiteSpace($Key)) {
        Write-Host "ERROR: Empty Key passed to Resolve-IconName" -ForegroundColor Red
        return @($Key)  # or throw, whatever is appropriate
    }

    # ... rest of your function
}