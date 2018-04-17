@{
    # Script module or binary module file associated with this manifest.
    RootModule           = 'WindowsFeatures.schema.psm1'

    # Version number of this module.
    ModuleVersion        = '0.0.1'

    # ID used to uniquely identify this module
    GUID                 = '06f7eb99-05a9-4476-8530-e4d28030fe70'

    # Author of this module
    Author               = 'NA'

    # Company or vendor of this module
    CompanyName          = 'NA'

    # Copyright statement for this module
    Copyright            = 'NA'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules      = @('PSDesiredStateConfiguration')

    # DSC resources to export from this module
    DscResourcesToExport = @('WindowsFeatures')
}