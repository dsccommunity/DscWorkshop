@{

    RootModule        = 'Datum.InvokeCommand.psm1'

    ModuleVersion     = '0.0.1'

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

            Prerelease   = ''

            ReleaseNotes = ''

        }

    }

}
