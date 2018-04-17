@{
    # Script module or binary module file associated with this manifest.
    RootModule           = 'FilesAndFolders.schema.psm1'

    # Version number of this module.
    ModuleVersion        = '0.0.1'

    # ID used to uniquely identify this module
    GUID                 = '89446cc0-0e57-41c9-809e-de0fe6a13fec'

    # Author of this module
    Author               = 'NA'

    # Company or vendor of this module
    CompanyName          = 'NA'

    # Copyright statement for this module
    Copyright            = 'NA'

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules      = @('PSDesiredStateConfiguration')

    # DSC resources to export from this module
    DscResourcesToExport = @('FilesAndFolders')
}