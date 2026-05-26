# Active Context

## Current Focus

Documentation and Copilot-customization alignment on the `docs` branch. Adopting the [CopilotAtelier](https://github.com/raandree/CopilotAtelier) workflow conventions in this repo:

- Memory Bank moved from `memory-bank/` → `.memory-bank/` to match the workspace pre/post-flight hooks.
- Memory Bank files audited and rewritten against current repo state.
- `.github/copilot-instructions.md` added so any Copilot session in this repo gets the right context without relying on the user's global instructions.
- CHANGELOG and conventional-commit discipline documented in `copilot-instructions.md`.

## Recent Shipped Work

- **HQRM tests** added; Pester configuration updated.
- **CommonTasks migration** — replaced `DscConfig.Demo` composite module across `build.yaml`, `RequiredModules.psd1`, and all Datum data. `FilesAndFolders` replaces `FileSystemObjects`; `DependsOn` references updated.
- **`NoWinPSCompatibility` build task** — eliminates 94 `WinPSCompatSession` warnings on PowerShell 7 by globally setting `Import-Module -SkipEditionCheck` before DSC resource discovery.
- **`ConvertMofFilesToUnicode` task** — fixes MOF encoding to UTF-16 LE BOM (#200).
- **DevOps Principles and Patterns** doc (`03 DevOps Principles and Patterns.md`) mapping the project to DORA, GitOps, Twelve-Factor, IaC, and the Release Pipeline Model.
- **GPO Migration Toolkit** under `GPOs/` — 8 extraction scripts, 2 QA scripts, ~98% coverage.

## Open Decisions / Watchlist

- AppVeyor build badge in `README.md` still points to `automatedlab/DscWorkshop` — verify whether it should track `dsccommunity/DscWorkshop`.
- Lab software package versions in `Lab/20 SoftwarePackages.psd1` may be stale; deferred until a real lab run validates them.
- `NoWinPSCompatibility` is a custom task in `.build/`; consider upstreaming to Sampler if it proves stable.

## Next Steps

1. Confirm `.memory-bank/` rename does not break any CI/script that referenced `memory-bank/`.
2. Once the doc/Copilot work merges, cut a release entry under CHANGELOG `[Unreleased]` → next version per `GitVersion.yml`.
3. Validate AutomatedLab deployment end-to-end on current AL release before claiming Lab/* is green.
