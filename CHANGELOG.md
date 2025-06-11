# Changelog for DscPipeline

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added stages to cloud pipeline and added steps to publish modules to Azure Automation DSC.
- Added support for Azure Guest Configuration.
- Added support for federated credentials in Azure Pipelines.
- Added documentation for the Filter Parameter in build.ps1.

### Changed

- Migration to 'Sampler' and 'Sampler.DscPipeline'.
- Migration to Pester 5+.
- Changed from 'CommonTasks' to 'DscConfig.Demo' for faster build time.
- Added support for PowerShell 7.
- Added support for Azure Guest Configuration.
- Updated 'NetworkIpConfiguration\Interfaces' configuration data.
- Used `windows-latest` in `azure-pipelines-azautomation` Fixes [#187](https://github.com/dsccommunity/DscWorkshop/issues/187).

### Fixed

- Config data test 'No duplicate IP addresses should be used' threw when there.
  is no IP address configured.
- Module versions incremented.
- Fix typo in ConfigData tests.
- Fixed some optional config data tests are never running.
- Fixed skipped optional config data tests are not marked accordingly.
- Fixed exercises - Task 2 (#141).
- Pipeline YAMLs updated to configure unshallow fetch (Fixes issues with GitVersion).
- Added task `Set_PSModulePath` which required adding also `Build_Module_ModuleBuilder`
  and a `DscWorkshop.psm1` dummy file.
- Added `TestReferenceRsop` task.
- Added `DscTagging` config data.
- Removed a `-ListAvailable` Parameter from the `Get-PackageProvider` at Resolve-Dependency.ps1 which could lead to false positives, creates a warning in offline Build Servers and slows down the process.
