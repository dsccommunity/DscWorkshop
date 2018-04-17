#PSDepend dependencies
# Either install modules for generic use or save them in ./modules for Test-Kitchen

@{
    # Set up a mini virtual environment...
    PSDependOptions = @{
        AddToPath = $True
        Target = 'BuildOutput\modules'
        Parameters = @{
            #Force = $True
            #ExtractProject = $true
        }
    }

    invokeBuild = 'latest'
    buildhelpers = 'latest'
    pester = 'latest'
    
    PackageManagement = 'latest'
    PowerShellGet = 'latest'
    PSScriptAnalyzer = 'latest'
    psdeploy = 'latest'
    xDscResourceDesigner = 'latest'
    xPSDesiredStateConfiguration = 'latest'
    'gaelcolas/DscBuildHelpers' = 'master'
    
    ProtectedData = 'latest'
    'powershell-yaml' = 'latest'
    Datum = 'latest'
}