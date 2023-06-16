@{
    RootModule        = 'DscConfig.Demo.psm1'
    ModuleVersion     = '0.8.3'
    GUID              = '63e8bf79-62d3-4249-8fe6-9a766fbe8481'
    Author            = 'DSC Community'
    CompanyName       = 'DSC Community'
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'
    Description       = 'DSC composite resource for https://github.com/dsccommunity/DscWorkshop'
    PowerShellVersion = '5.1'
    FunctionsToExport = '*'
    CmdletsToExport   = '*'
    VariablesToExport = '*'
    AliasesToExport   = '*'

    PrivateData       = @{

        PSData = @{
            Prerelease   = ''
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResource')
            LicenseUri   = 'https://github.com/dsccommunity/DscConfig.Demo/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/dsccommunity/DscConfig.Demo'
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'
            ReleaseNotes = '## [0.8.3] - 2023-03-16

### Changed

- These modules have been updated:
  - ComputerManagementDsc to ''9.0.0''
  - NetworkingDsc to ''9.0.0''
  - WebAdministrationDsc to ''4.1.0''
- Added tasks from ''Sampler.AzureDevOpsTasks'' to fix publishing issues in Azure DevOps Server.

'
        }
    }
}
