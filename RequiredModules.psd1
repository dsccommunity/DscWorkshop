@{
    PSDependOptions              = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository      = 'PSGallery'
            AllowPreRelease = $true
        }
    }

    'powershell-yaml'            = 'latest'
    InvokeBuild                  = 'latest'
    PSScriptAnalyzer             = 'latest'
    Pester                       = 'latest'
    Plaster                      = 'latest'
    ModuleBuilder                = 'latest'
    ChangelogManagement          = 'latest'
    Sampler                      = 'latest'
    'Sampler.GitHubTasks'        = 'latest'
    PowerShellForGitHub          = 'latest'
    'Sampler.DscPipeline'        = '0.2.0-preview0002'
    MarkdownLinkCheck            = 'latest'
    'DscResource.AnalyzerRules'  = 'latest'
    DscBuildHelpers              = '0.2.0'
    Datum                        = '0.40.1-preview0001'
    ProtectedData                = 'latest'
    'Datum.ProtectedData'        = 'latest'
    'Datum.InvokeCommand'        = '0.3.0-preview0005'
    ReverseDSC                   = 'latest'
    Configuration                = 'latest'
    Metadata                     = 'latest'
    xDscResourceDesigner         = 'latest'
    'DscResource.Test'           = 'latest'

    # Composites
    'DscConfig.Demo'             = '0.7.1-preview0002'

    #DSC Resources
    xPSDesiredStateConfiguration = '9.1.0'
    ComputerManagementDsc        = '8.5.0'
    NetworkingDsc                = '8.2.0'
    JeaDsc                       = '0.7.2'
    xWebAdministration           = '3.2.0'
    FileSystemDsc                = '1.1.1'
    SecurityPolicyDsc            = '2.10.0.0'
    xDscDiagnostics              = '2.8.0'

}
