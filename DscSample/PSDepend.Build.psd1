#PSDepend dependencies
# Either install modules for generic use or save them in ./modules for Test-Kitchen

@{
    # Set up a mini virtual environment...
    PSDependOptions              = @{
        AddToPath  = $True
        Target     = 'BuildOutput\Modules'
        Parameters = @{
            #Force = $True
            #ExtractProject = $true
        }
    }

    InvokeBuild                  = 'latest'
    BuildHelpers                 = 'latest'
    Pester                       = 'latest'
    PSScriptAnalyzer             = 'latest'
    PSDeploy                     = 'latest'
    DscBuildHelpers              = 'latest'
    Datum                        = 'latest'
    ProtectedData                = 'latest'
    'powershell-yaml'            = 'latest'
}
