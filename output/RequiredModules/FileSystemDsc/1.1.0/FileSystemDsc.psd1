@{
    RootModule           = 'FileSystemDsc.psm1'
    # Version number of this module.
    ModuleVersion        = '1.1.0'

    # ID used to uniquely identify this module
    GUID                 = '86a20a80-3bcd-477e-9b90-ec8d52fbe415'

    CompatiblePSEditions = @('Core', 'Desktop')

    # Author of this module
    Author               = 'DSC Community'

    # Company or vendor of this module
    CompanyName          = 'DSC Community'

    # Copyright statement for this module
    Copyright            = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description          = 'This module contains DSC resources for managing file systems.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion    = '5.1'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion           = '4.0'

    DscResourcesToExport = @('FileSystemObject','FileSystemAccessRule')

    RequiredAssemblies   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{
        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = 'filesystemobject0001'

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/FileSystemDsc/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/FileSystemDsc'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [1.1.0-filesystemobject0001] - 2023-06-11

### Added

- FileSystemDsc
  - Added issue and pull request templates to help contributors.
  - Added wiki generation and publish to GitHub repository wiki.
  - Added recommended VS Code extensions.
    - Added settings for VS Code extension _Pester Test Adapter_.

### Changed

- FileSystemDsc
  - Renamed `master` branch to `main` ([issue #11](https://github.com/dsccommunity/FileSystemDsc/issues/11)).
  - Only run the CI pipeline on branch `master` when there are changes to
    files inside the `source` folder.
  - The regular expression for `minor-version-bump-message` in the file
    `GitVersion.yml` was changed to only raise minor version when the
    commit message contain the word `add`, `adds`, `minor`, `feature`,
    or `features`.
  - Added missing MIT LICENSE file.
  - Converted tests to Pester 5.
  - Minor changes to pipeline files.
  - Update build configuration to use Pester advanced build configuration.
  - Update pipeline to user Sampler GitHub tasks.
  - Update pipeline deploy step to correctly download build artifact.
  - Update so that HQRM test correctly creates a NUnit file that can be
    uploaded to Azure Pipelines.
  - Updated pipeline to use the new faster Pester Code coverage.
  - Using the latest Pester preview version in the pipeline to be able to
    test new Pester functionality.
  - Updated build pipeline files.

### Fixed

- FileSystemDsc
  - The component `gitversion` that is used in the pipeline was wrongly configured
    when the repository moved to the new default branch `main`. It no longer throws
    an error when using newer versions of GitVersion.
  - Fix pipeline to use available build workers.
- FileSystemAccessRule
  - Unit test was updated to support latest Pester.
  - Test was updated to handle that `build.ps1` has not been run.

'

        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
