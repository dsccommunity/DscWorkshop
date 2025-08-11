@{
    PSDependOptions              = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository      = 'PSGallery'
            AllowPreRelease = $true
        }
    }

    'powershell-yaml'            = '0.4.11'
    InvokeBuild                  = '5.12.1'
    PSScriptAnalyzer             = '1.23.0'
    Pester                       = '5.6.1'
    Plaster                      = '1.1.4'
    ModuleBuilder                = '3.1.0'
    ChangelogManagement          = '3.1.0'
    Sampler                      = '0.118.1'
    'Sampler.GitHubTasks'        = '0.3.5-preview0002'
    'Sampler.AzureDevOpsTasks'   = '0.1.2'
    PowerShellForGitHub          = '0.17.0'
    'Sampler.DscPipeline'        = '0.3.0-preview0006'
    MarkdownLinkCheck            = '0.2.0'
    'DscResource.AnalyzerRules'  = '0.2.0'
    DscBuildHelpers              = '0.3.0-preview0003'
    Datum                        = '0.40.1'
    ProtectedData                = '5.0.0'
    'Datum.ProtectedData'        = '0.0.1'
    'Datum.InvokeCommand'        = '0.3.0'
    ReverseDSC                   = '2.0.0.24'
    Configuration                = '1.6.0'
    Metadata                     = '1.5.7'
    xDscResourceDesigner         = '1.13.0.0'
    'DscResource.Test'           = '0.16.3'
    'DscResource.DocGenerator'   = '0.12.5'
    PSDesiredStateConfiguration  = '2.0.7'
    GuestConfiguration           = '4.6.0'

    'Az.Accounts'                = '4.0.0'
    'Az.Storage'                 = '8.0.0'
    'Az.ManagedServiceIdentity'  = '1.2.1'
    'Az.Resources'               = '7.7.0'
    'Az.PolicyInsights'          = '1.6.5'
    'Az.Compute'                 = '9.0.0'

    # Composites
    #'DscConfig.Demo'             = '0.8.3'

    #DSC Resources
    xPSDesiredStateConfiguration = '9.2.1'
    ComputerManagementDsc        = '9.2.0'
    NetworkingDsc                = '9.0.0'
    JeaDsc                       = '4.0.0-preview0005'
    WebAdministrationDsc         = '4.2.1'
    #FileSystemDsc                = '1.1.1'
    SecurityPolicyDsc            = '2.10.0.0'
    xDscDiagnostics              = '2.8.0'

}
