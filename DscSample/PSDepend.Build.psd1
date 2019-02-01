@{
    PSDependOptions   = @{
        AddToPath      = $true
        Target         = 'BuildOutput\Modules'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    InvokeBuild       = 'latest'
    BuildHelpers      = 'latest'
    Pester            = 'latest'
    PSScriptAnalyzer  = 'latest'
    DscBuildHelpers   = 'latest'
    Datum             = '0.0.35'
    ProtectedData     = 'latest'
    'powershell-yaml' = 'latest'
}