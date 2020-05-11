@{
    PSDependOptions       = @{
        AddToPath      = $true
        Target         = 'BuildOutput\Modules'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    InvokeBuild           = 'latest'
    BuildHelpers          = 'latest'
    Pester                = 'latest'
    PSScriptAnalyzer      = 'latest'
    DscBuildHelpers       = 'latest'
    Datum                 = 'latest'
    'powershell-yaml'     = 'latest'
    'Datum.ProtectedData' = 'latest'
}
