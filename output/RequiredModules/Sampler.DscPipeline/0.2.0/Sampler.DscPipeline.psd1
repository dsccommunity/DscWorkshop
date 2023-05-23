@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'Sampler.DscPipeline.psm1'

    # Version number of this module.
    ModuleVersion     = '0.2.0'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID              = 'a1afa85a-8f1a-4735-956c-d917a4582ec7'

    # Author of this module
    Author            = 'Gael Colas'

    # Company or vendor of this module
    CompanyName       = 'SynEdgy Limited'

    # Copyright statement for this module
    Copyright         = '(c) SynEdgy Limited. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Samper tasks for a DSC Pipeline using a Datum Yaml hierarchy.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        'Plaster'
        'Sampler'
        'DscBuildHelpers'
    )

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @('Get-DatumNodesRecursive','Get-DscErrorMessage','Get-DscMofEnvironment','Get-DscMofVersion','Get-FilteredConfigurationData','Split-Array')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = '*'

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = '*'

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Prerelease string of this module
            Prerelease = 'preview0015'

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('DSC', 'Sampler', 'InvokeBuild', 'Tasks')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/SynEdgy/Sampler.DscPipeline/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/SynEdgy/Sampler.DscPipeline'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = '## [0.2.0-preview0015] - 2023-04-04

### Added

- Adding pipeline tasks and commands from DSC Workshop.
- Small changes to support easier deployment for individual environments.
- Added scripts for compiling MOF and Meta MOF files without the need for the `rootConfig.ps1` script. It is now a self-contained task that takes parameters from the `Build.yml`.
- Having modules available more than once results in: ImportCimAndScriptKeywordsFromModule : "A second CIM class definition
  for ''MSFT_PSRepository'' was found while processing the schema file". Fixed that by using function ''Get-DscResourceFromModuleInFolder''.
  This usually happens with ''PackageManagement'' and ''PowerShellGet''
- The handling of the DSC MOF compilation has changed. The file ''RootConfiguration.ps1'' is still used when present in the source of
  the DSC project that uses ''Sampler.DscPipeline''. Same applies to the Meta MOF compilation script ''RootMetaMof.ps1''. If these
  files don''t exist, ''Sampler.DscPipeline'' uses the scripts in ''ModuleRoot\Scripts''. To control which DSC composite and resource modules should be imported within the DSC configuration, add the section ''Sampler.DscPipeline'' to the ''build.yml'' as described
  on top of the file ''CompileRootConfiguration.ps1''.
- Added error handling discovering ''CompileRootConfiguration.ps1'' and ''RootMetaMof.ps1''
- Test cases updated to Pester 5.
- Fixing issue with ZipFile class not being present.
- Fixing calculation of checksum if attribute NodeName is different to attribute Name (of YAML file).
- Increase build speed of root configuration by only importing required Composites/Resources.
- Added ''''UseEnvironment'''' parameter to cater for RSOP for identical node names in different environments.
- Adding Home.md to wikiSource and correct casing.
- Removed PSModulePath manipulation from task `CompileRootConfiguration.build.ps1`. This is now handled by the Sampler task `Set_PSModulePath`.
- Redesign of the function Split-Array. Most of the time it was not working as expected, especially when requesting larger ChunkCounts (see AutomatedLab/AutomatedLab.Common/#118)
- Redesign of the function Split-Array. Most of the time it was not working as expected, especially when requesting larger ChunkCounts (see AutomatedLab/AutomatedLab.Common/#118).
- Improved error handling when compiling MOF files and when calling ''Get-DscResource''.
- Redesign of the function ''Split-Array''. Most of the time it was not working as expected, especially when requesting larger ChunkCounts (see AutomatedLab/AutomatedLab.Common/#118).
- Improved error handling when compiling MOF files.

### Fixed

- Fixed regex for commit message `--Added new node`
- Fixed task `Compress_Artifact_Collections` fails when node is filtered
'

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}
