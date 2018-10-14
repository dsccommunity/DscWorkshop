Task Init {
1
Get-Location
    if (-not $env:BHProjectName) {
        try {
            Set-BuildEnvironment -Path $ProjectPath
            
        }
        catch {
            Write-Host "Error calling 'Set-BuildEnvironment'. The task will probably fail if in build."
        }
    }
2
Get-Location
    $lines
    Set-Location -Path $ProjectPath
    "Build System Details:"
    Get-Item -Path env:BH*
    "`n"
    3
    Get-Location
}
