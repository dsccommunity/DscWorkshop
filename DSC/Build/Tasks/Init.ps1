Task Init {

    if ($PSVersionTable.PSEdition -ne 'Desktop') {
        Write-Error "The build script required Windows PowerShell 5.1 to work" 
    }

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

    $global:Filter = $null

    $lines
    Set-Location -Path $ProjectPath
    "Build System Details:"
    Get-Item -Path env:BH*
    "`n"
    
}
