# System Patterns

## Architectural Principles

1. **Separation of concerns** — configuration *data* (YAML in `source/`) is fully decoupled from configuration *logic* (composite resources in `CommonTasks`) and from *build orchestration* (`build.yaml` + Sampler tasks).
2. **Hierarchical inheritance** — Datum merges YAML across 7 organizational layers in a deterministic precedence order.
3. **Composition over inheritance** — node configuration = sum of role + baseline + environment + location overrides; no class hierarchies.
4. **Immutable artifacts** — generated MOF + checksums + compressed module zips are the unit of deployment; never edited post-build.
5. **Single build script** — every CI provider, dev workstation, and lab worker runs `./build.ps1` with the same task list.
6. **Data-driven** — adding a node, role, or environment is a YAML edit; no PowerShell changes required.

## Datum Resolution Precedence (most → least specific)

1. `source/AllNodes/{Env}/{NodeName}.yml`
2. `source/Environments/{Env}.yml`
3. `source/Locations/{Location}.yml`
4. `source/Roles/{Role}.yml`
5. `source/Baselines/Security.yml`
6. `source/Baselines/{Baseline}.yml`
7. `source/Baselines/DscLcm.yml`

Merge strategies (per `Datum.yml`): `MostSpecific` for scalars, deep-merge for hashes, `Unique` / `UniqueKeyValTuples` for arrays.

## Build Pipeline (data flow)

```text
YAML (source/)
   │
   ▼
LoadDatumConfigData ──► TestConfigData
   │
   ▼
CompileDatumRsop ──► RSOP per node ──► TestReferenceRsop (vs source/TestRsopReferences/)
   │
   ▼
TestDscResources (after Set_PSModulePath + NoWinPSCompatibility)
   │
   ▼
CompileRootConfiguration ──► MOF per node
CompileRootMetaMof       ──► MetaMOF (LCM) per node
   │
   ▼
ConvertMofFilesToUnicode ──► NewMofChecksums ──► CompressModulesWithChecksum
   │
   ▼
Compress_Artifact_Collections ──► TestBuildAcceptance ──► output/CompressedArtifacts/
```

## Reusable Patterns

### Composite Resource Pattern
Group related DSC resources (e.g. all firewall profiles) behind one composite to keep YAML readable. Composites live in `CommonTasks` (or, for GPO toolkit, in `DscConfig.Demo`'s `UserRightsAssignments` / `AuditPolicies` / `FirewallProfiles`).

### Reference RSOP Regression Pattern
`source/TestRsopReferences/*.yml` are golden files. `TestReferenceRsop` compares fresh RSOP output against them; any unintended drift in CommonTasks/Datum surfaces as a test failure before MOF compilation.

### Custom Build Task Pattern
PS1 scripts under `.build/` get auto-loaded by Sampler if they follow `*.build.<Name>.ib.tasks.ps1` naming. Used for `NoWinPSCompatibility`, `ConvertMofFilesToUnicode`, etc.

### GPO Migration Pipeline Pattern (`GPOs/`)
`Get-GPOReport -Xml` → orchestrator (`Export-GpoAllSettings.ps1`) → 7 specialized extractors → 7 YAML files per GPO → QA (`Analyze-YamlDuplicates.ps1`, `Compare-YamlFiles.ps1`) → drop into `source/Baselines|Roles|Locations|Environments/`.

### Lab Bootstrap Pattern (`Lab/`)
`00 Lab Deployment.ps1 -HostType <Azure|HyperV>` filters and runs the numbered scripts in order: deploy infrastructure (10) → customize + install software (20) → wire ADO pipelines (31/32) → optional auto-onboarding (33) and reporting DB (40).

## Security Model

- **ProtectedData**: secrets in YAML are encrypted with PKI certs via `Datum.ProtectedData`; lab certs are auto-generated, prod certs come from real CA.
- **Baselines/Security.yml**: always applied; defines audit policy, user rights, security options.
- **Lab is NOT prod-hardened**: default creds (`Install` / `Somepass1`), self-signed certs, Windows Update disabled for stability.

## Anti-Patterns to Avoid

- Editing generated MOF or RSOP files in `output/` — always reproduce from YAML.
- Adding logic to YAML via Datum handlers when a composite resource would be clearer.
- Adding ad-hoc PSDepend calls outside `RequiredModules.psd1`.
- Bypassing `./build.ps1` to invoke individual tasks in CI — use the workflow names defined in `build.yaml`.

## Memory Bank Pattern (this folder)

`.memory-bank/` is the version-controlled, repo-scoped knowledge base. It is read by every Copilot session per the workspace pre-flight hook. Always-loaded files: `projectbrief.md`, `activeContext.md`, `techContext.md`, `progress.md`, `systemPatterns.md`. On-demand topics: `productContext.md`, `labInfrastructure.md`.
