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
    Pester                = '4.10.1'
    PSScriptAnalyzer      = 'latest'
    DscBuildHelpers       = 'latest'
    Datum                 = '0.39.0'
    'powershell-yaml'     = 'latest'
    ProtectedData         = 'latest'
    'Datum.ProtectedData' = 'latest'
    'Datum.InvokeCommand' = 'latest'
    xDscResourceDesigner  = 'latest'
    ReverseDSC            = 'latest'
}
