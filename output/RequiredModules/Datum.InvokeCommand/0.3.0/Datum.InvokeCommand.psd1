@{

    RootModule        = 'Datum.InvokeCommand.psm1'

    ModuleVersion     = '0.3.0'

    GUID              = '31b6472c-069c-40c2-aaa9-ac8c2de55081'

    Author            = 'Raimund Andree'

    CompanyName       = 'NA'

    Copyright         = '(c) 2019 Raimund Andree. All rights reserved.'

    Description       = 'Datum Handler module to encrypt and decrypt secrets in Datum using Dave Wyatt''s ProtectedData module'

    FunctionsToExport = @('Invoke-InvokeCommandAction','Test-InvokeCommandFilter')

    PowerShellVersion = '4.0'

    PrivateData       = @{

        PSData = @{

            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResource', 'Datum')

            LicenseUri   = 'https://github.com/raandree/Datum.InvokeCommand/blob/master/LICENSE'

            ProjectUri   = 'https://github.com/raandree/Datum.InvokeCommand'

            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            Prerelease   = 'preview0003'

            ReleaseNotes = '## [0.3.0-preview0003] - 2022-02-18

### Added

- Support for expandable strings
- Configurable Header and Footer
- Content is now evaluated with RegEx + PowerShell Parser
- Gives access to Node and Datum variable
- Added function ''Get-RelativeNodeFileName''
- Resolves nested references
- Added analyzersettings rules
- Added support for multi-line scriptblocks
- Added more tests and test data for multi-role support and handler support in ''ResolutionPrecedence''
- Improved error handling and implemented ''$env:DatumHandlerThrowsOnError''

'

        }

    }

}
