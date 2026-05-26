# Progress

## What Works

- **Build pipeline**: `./build.ps1` produces MOF, MetaMOF, RSOP, compressed modules, and runs Pester tests on PS 5.1 and PS 7.
- **Datum resolution**: 7-layer hierarchy (Node → Env → Location → Role → Baselines) compiles cleanly across Dev/Test/Prod nodes.
- **CommonTasks composite resources**: post-migration build is green; `FilesAndFolders` etc. resolve correctly.
- **HQRM tests** wired into the `hqrmtest` workflow.
- **PowerShell 7 compatibility**: `NoWinPSCompatibility` task removes 94 `WinPSCompatSession` warnings.
- **MOF encoding**: `ConvertMofFilesToUnicode` task fixes UTF-16 LE BOM (#200).
- **GPO Migration Toolkit** (`GPOs/`): production-ready, ~98% coverage of common GPO setting types.
- **AutomatedLab scripts** (`Lab/`): cover Hyper-V and Azure end-to-end deployment, including ADO Server, DSC Pull Server, CA, SQL, build agents.
- **CI/CD pipelines**: Azure DevOps (multiple variants), Azure Automation DSC, Azure Guest Configuration, AppVeyor.
- **Documentation**: `01 AutomatedLab.md`, `02 Building_DSC_Artefacts.md`, `03 DevOps Principles and Patterns.md`, Exercises Task1–Task3.

## In Progress

- `docs` branch — Memory Bank + Copilot customization alignment with CopilotAtelier conventions.

## Known Gaps / Tech Debt

- AppVeyor badge in `README.md` still references `automatedlab/DscWorkshop` — should likely be `dsccommunity/DscWorkshop`.
- `Lab/20 SoftwarePackages.psd1` versions probably stale.
- Module versions in `RequiredModules.psd1` are mostly unpinned (`latest`), which is convenient but non-reproducible.
- Reference RSOP (`source/TestRsopReferences/`) needs regen any time CommonTasks changes default parameters.

## Decision Log

- **2025-11**: Migrated `DscConfig.Demo` → `CommonTasks` for ecosystem alignment.
- **2025-11**: Pester 5+ adopted; build moved to Sampler / Sampler.DscPipeline.
- **2025-11**: Added PowerShell 7 support as primary driver (PS 5.1 still required for compile).
- **2026-05 (this session)**: Memory Bank moved to `.memory-bank/`, Copilot instructions added at `.github/copilot-instructions.md`, CHANGELOG/commit discipline documented.

## History

- `0.2.0` (2025-11-14): Sampler migration, Pester 5+, PS 7 support, Guest Configuration, GPO Migration feature, federated credentials.
- `[Unreleased]`: HQRM tests, CommonTasks migration, module updates, MOF unicode fix, WinPSCompatSession fix, DevOps Principles doc, Memory Bank/Copilot alignment.
