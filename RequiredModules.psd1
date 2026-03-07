@{
    PSDependOptions              = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository      = 'PSGallery'
            AllowPreRelease = $true
        }
    }

    'powershell-yaml'            = '0.4.12'
    InvokeBuild                  = '5.14.23'
    PSScriptAnalyzer             = '1.24.0'
    Pester                       = '5.7.1'
    Plaster                      = '1.1.4'
    ModuleBuilder                = '3.1.8'
    ChangelogManagement          = '3.1.0'
    Sampler                      = '0.119.1'
    'Sampler.GitHubTasks'        = '0.3.5-preview0002'
    'Sampler.AzureDevOpsTasks'   = '0.1.2'
    PowerShellForGitHub          = '0.17.0'
    'Sampler.DscPipeline'        = '0.3.0'
    MarkdownLinkCheck            = '0.2.0'
    'DscResource.AnalyzerRules'  = '0.2.0'
    DscBuildHelpers              = '0.3.0'
    Datum                        = '0.41.0'
    ProtectedData                = '5.0.0'
    'Datum.ProtectedData'        = '0.0.1'
    'Datum.InvokeCommand'        = '0.4.1'
    Configuration                = '1.6.0'
    Metadata                     = '1.5.7'
    xDscResourceDesigner         = '1.13.0.0'
    'DscResource.Test'           = '0.19.0'
    'DscResource.DocGenerator'   = '0.13.0'
    PSDesiredStateConfiguration  = '2.0.8'
    PowerShellGet                = '2.2.5'
    GuestConfiguration           = '4.11.0'

    'Az.Accounts'                = '5.3.3'
    'Az.Storage'                 = '9.6.0'
    'Az.ManagedServiceIdentity'  = '2.0.0'
    'Az.Resources'               = '9.0.3'
    'Az.PolicyInsights'          = '1.7.3'
    'Az.Compute'                 = '11.4.0'

    # Composites
    CommonTasks                  = 'latest'

    #DSC Resources
    xPSDesiredStateConfiguration = '9.2.1'
    ComputerManagementDsc        = '10.0.0'
    NetworkingDsc                = '9.1.0'
    JeaDsc                       = '4.0.0-preview0005'
    WebAdministrationDsc         = '4.2.1'
    FileSystemDsc                = '1.1.1'
    SecurityPolicyDsc            = '2.10.0.0'
    xDscDiagnostics              = '2.8.0'

}
