@{
    PSDependOptions              = @{
        AddToPath  = $True
        Target     = 'BuildOutput\Modules'
        Parameters = @{}
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