# Tech Context

## Stack

| Layer | Tool | Notes |
|---|---|---|
| Config language | YAML | UTF-8 with BOM; Datum schema |
| Config engine | [Datum](https://github.com/gaelcolas/Datum) 0.41.0 | Hierarchical merge, ProtectedData, InvokeCommand handlers |
| Composite resources | [CommonTasks](https://github.com/dsccommunity/CommonTasks) | Migrated from `DscConfig.Demo` |
| Build framework | [Sampler](https://github.com/gaelcolas/Sampler) + `Sampler.DscPipeline` 0.3.0 + `Sampler.GitHubTasks` | Tasks defined in `build.yaml` |
| Task runner | InvokeBuild | Driven by `./build.ps1` |
| Dep resolution | PSDepend via `RequiredModules.psd1` | Bootstrap by `Resolve-Dependency.ps1` |
| Module helpers | DscBuildHelpers 0.3.0, ModuleBuilder | |
| DSC engine | PSDesiredStateConfiguration | PS 5.1 (Desktop) and PS 7+ (Core via SkipEditionCheck) |
| Tests | Pester 5+ | QA in `tests/QA`; HQRM via `DscResource.Test` |
| Versioning | GitVersion (`GitVersion.yml`) | SemVer |
| Lab | AutomatedLab | `Lab/` for Hyper-V/Azure |
| CI/CD | Azure Pipelines (4 YAML files), AppVeyor | See `azure-pipelines*.yml` |

## Build Workflow (`build.yaml`)

- `.` (default) = `build` + `pack` + `test`.
- `build`: Clean → PowerShell5Compatibility → Build_Module_ModuleBuilder → LoadDatumConfigData → TestConfigData → CompileDatumRsop → TestReferenceRsop → Set_PSModulePath → **NoWinPSCompatibility** → TestDscResources → CompileRootConfiguration → CompileRootMetaMof.
- `pack`: ConvertMofFilesToUnicode → NewMofChecksums → CompressModulesWithChecksum → Compress_Artifact_Collections → TestBuildAcceptance.
- `packguestconfiguration`: pack + `build_guestconfiguration_packages_from_MOF` + `publish_guestconfiguration_packages`.
- `rsop`: load + compile + test resources only (fast iteration).
- `test`: Pester + coverage gate.
- `hqrmtest`: `Invoke_HQRM_Tests_Stop_On_Fail`.
- `publish`: gallery + GitHub release + changelog PR.

Custom task `NoWinPSCompatibility` lives in `.build/SuppressWinPSCompatWarning.ps1`.

## Output Layout (`output/`)

`Module/`, `MOF/`, `MetaMOF/`, `RSOP/`, `RsopWithSource/`, `RequiredModules/`, `CompressedModules/`, `CompressedArtifacts/`, `Logs/`, `testResults/`.

## Source Layout (`source/`)

`Datum.yml` (hierarchy), `AllNodes/{Env}/<node>.yml`, `Environments/`, `Locations/`, `Roles/`, `Baselines/` (Security + DscLcm), `Global/`, `Domains/`, `TestRsopReferences/` (golden RSOP for regression), `ExternalData.csv`.

## Local Dev Requirements

- Windows + PowerShell 5.1 (mandatory for DSC compile) and PS 7+ (recommended driver).
- Git, VS Code with PowerShell extension.
- For Lab: Hyper-V or an Azure subscription, plus Windows Server / SQL / Azure DevOps Server ISOs.
- Bootstrap: `./build.ps1 -ResolveDependency` (or `-AutoRestore` on subsequent runs).

## Key Module Versions (RequiredModules.psd1)

Datum 0.41.0 · DscBuildHelpers 0.3.0 · Sampler.DscPipeline 0.3.0 · CommonTasks (current). All other modules track latest at build time unless pinned.

## Pipelines

- `azure-pipelines.yml` — main on-prem build.
- `azure-pipelines-azautomation.yml` — publish to Azure Automation DSC (uses federated creds).
- `azure-pipelines On-Prem.yml` — on-prem deploy stage.
- `azure-pipelines Guest Configuration.yml` — Azure Guest Configuration packages.
