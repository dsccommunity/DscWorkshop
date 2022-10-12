@{
    PSDependOptions              = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository      = 'PSGallery'
            AllowPreRelease = $true
        }
    }

    'powershell-yaml'            = '0.4.3'
    InvokeBuild                  = '5.9.12'
    PSScriptAnalyzer             = '1.21.0'
    Pester                       = '5.3.3'
    Plaster                      = '1.1.3'
    ModuleBuilder                = '2.0.0'
    ChangelogManagement          = '2.1.4'
    Sampler                      = '0.115.0'
    'Sampler.GitHubTasks'        = '0.3.5-preview0002'
    PowerShellForGitHub          = '0.16.1'
    'Sampler.DscPipeline'        = '0.2.0-preview0003'
    MarkdownLinkCheck            = '0.2.0'
    'DscResource.AnalyzerRules'  = '0.2.0'
    DscBuildHelpers              = '0.2.1'
    Datum                        = '0.40.1-preview0001'
    ProtectedData                = '4.1.3'
    'Datum.ProtectedData'        = '0.0.1'
    'Datum.InvokeCommand'        = '0.3.0-preview0006'
    ReverseDSC                   = '2.0.0.13'
    Configuration                = '1.5.1'
    Metadata                     = '1.5.7'
    xDscResourceDesigner         = '1.13.0.0'
    'DscResource.Test'           = '0.16.1'
    'DscResource.DocGenerator'   = '0.11.1'

    # Composites
    'DscConfig.Demo'             = '0.8.1-preview0002'

    #DSC Resources
    xPSDesiredStateConfiguration = '9.1.0'
    ComputerManagementDsc        = '8.5.0'
    NetworkingDsc                = '9.0.0'
    JeaDsc                       = '0.7.2'
    xWebAdministration           = '3.3.0'
    FileSystemDsc                = '1.1.1'
    SecurityPolicyDsc            = '2.10.0.0'
    xDscDiagnostics              = '2.8.0'

}
