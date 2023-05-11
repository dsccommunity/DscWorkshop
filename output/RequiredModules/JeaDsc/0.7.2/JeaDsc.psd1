@{

    RootModule           = 'JeaDsc.psm1'

    ModuleVersion        = '0.7.2'

    GUID                 = 'c7c41e83-55c3-4e0f-9c4f-88de602e04db'

    Author               = 'DSC Community'

    CompanyName          = 'DSC Community'

    Copyright            = 'Copyright the DSC Community contributors. All rights reserved.'

    Description          = 'This module contains resources to configure Just Enough Administration endpoints.'

    PowerShellVersion    = '5.1'

    NestedModules        = @(
        'DSCClassResources\JeaSessionConfiguration\JeaSessionConfiguration.psd1'
        'DSCClassResources\JeaRoleCapabilities\JeaRoleCapabilities.psd1'
    )

    FunctionsToExport    = @(
        'ConvertTo-Expression'
    )

    VariablesToExport    = @()

    AliasesToExport      = @()

    DscResourcesToExport = @(
        'JeaSessionConfiguration'
        'JeaRoleCapabilities'
    )

    PrivateData          = @{

        PSData = @{

            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResource', 'JEA', 'JustEnoughAdministration')

            LicenseUri   = 'https://github.com/dsccommunity/JeaDsc/blob/master/LICENSE'

            ProjectUri   = 'https://github.com/dsccommunity/JeaDsc'

            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            Prerelease   = ''

            ReleaseNotes = '## [0.7.2] - 2020-09-29

### Changed

- Moving code from constructor to separate method.

'

        }

    }
}
