@{
    # Script module or binary module file associated with this manifest.
    RootModule           = 'SecurityBase.schema.psm1'

    # Version number of this module.
    ModuleVersion        = '0.0.1'

    # ID used to uniquely identify this module
    GUID                 = '6b2f1809-107e-474b-84fa-d0a658ef4285'

    # Author of this module
    Author               = 'NA'

    # Company or vendor of this module
    CompanyName          = 'NA'

    # Copyright statement for this module
    Copyright            = 'NA'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules      = @('PSDesiredStateConfiguration')

    # DSC resources to export from this module
    DscResourcesToExport = @('SecurityBase')
}