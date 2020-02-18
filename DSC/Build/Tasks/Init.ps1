Task Init {

    if (-not $env:BHProjectName) {
        try {
            Write-Host "Calling 'Set-BuildEnvironment' with path '$ProjectPath'"
            Set-BuildEnvironment -Path $ProjectPath
        }
        catch {
            Write-Host "Error calling 'Set-BuildEnvironment'."
            throw $_
        }
    }

    $lines
    Set-Location -Path $ProjectPath
    "Build System Details:"
    Get-Item -Path env:BH*
    "`n"
    
}
