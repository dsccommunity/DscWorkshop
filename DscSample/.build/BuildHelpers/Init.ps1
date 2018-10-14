Task Init {

    if (-not $env:BHProjectName) {
        try {
            Set-BuildEnvironment -Path $ProjectPath
            
        }
        catch {
            Write-Host "Error calling 'Set-BuildEnvironment'. The task will probably fail if in build."
        }
    }

    $lines
    Set-Location -Path $ProjectPath
    "Build System Details:"
    Get-Item -Path env:BH*
    "`n"
    
}
