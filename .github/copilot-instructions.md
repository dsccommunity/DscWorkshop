# Copilot Instructions — DscWorkshop

These instructions are loaded automatically by GitHub Copilot in any session opened against this repository. They are the **repo-scoped** counterpart to the user-level customization in [CopilotAtelier](https://github.com/raandree/CopilotAtelier).

## Project at a Glance

DscWorkshop is the reference implementation of an enterprise PowerShell DSC pipeline using **Datum** for configuration data, **Sampler / InvokeBuild** for the build, **CommonTasks** for composite resources, and **Pester 5+** for tests. It doubles as a teaching project (`Exercises/Task1`–`Task3`) and ships an **AutomatedLab** stack for end-to-end lab deployment plus a **GPO → DSC migration toolkit** (`GPOs/`).

For deeper context, read the Memory Bank in `.memory-bank/`:

- [.memory-bank/projectbrief.md](../.memory-bank/projectbrief.md) — purpose and scope
- [.memory-bank/techContext.md](../.memory-bank/techContext.md) — stack, build workflow, output layout
- [.memory-bank/systemPatterns.md](../.memory-bank/systemPatterns.md) — Datum precedence, build data flow, reusable patterns
- [.memory-bank/activeContext.md](../.memory-bank/activeContext.md) — current focus and open decisions
- [.memory-bank/progress.md](../.memory-bank/progress.md) — what works, gaps, decision log

## Build & Test

- Single entry point: `./build.ps1`. Default workflow runs `build` + `pack` + `test`.
- Bootstrap dependencies on a fresh clone: `./build.ps1 -ResolveDependency`. Subsequent runs: `-AutoRestore`.
- Workflows defined in `build.yaml`: `build`, `pack`, `packguestconfiguration`, `rsop` (fast iteration), `test`, `hqrmtest`, `publish`.
- Run only tests: `./build.ps1 -AutoRestore -Tasks test`.
- Custom tasks live in `.build/` and are picked up by Sampler via the `*.ib.tasks.ps1` convention.
- DSC compile requires Windows PowerShell 5.1; PS 7+ is the recommended driver and is supported via the `NoWinPSCompatibility` task.

## Editing Conventions

- **Configuration data** lives in `source/` as YAML. Add nodes/roles/baselines by editing YAML — never by changing build code.
- Honor the Datum precedence (Node → Env → Location → Role → Baselines). See `systemPatterns.md`.
- When CommonTasks composite parameter defaults change, regenerate `source/TestRsopReferences/*.yml` so `TestReferenceRsop` stays accurate.
- Generated artifacts in `output/` are disposable — never edit them, always rebuild.
- New modules go in `RequiredModules.psd1`. No ad-hoc `Install-Module` in scripts.
- PowerShell style: follow `c:\Users\randr\.copilot\instructions\powershell.instructions.md` and Pester guidance in `c:\Users\randr\.copilot\instructions\pester.instructions.md` when present; otherwise PSScriptAnalyzer defaults.

## Memory Bank Discipline

The workspace pre/post-flight hooks in `c:\Users\randr\.copilot\instructions\preflight.instructions.md` and `postflight.instructions.md` require:

- **Pre-flight**: probe `.memory-bank/` and read the always-loaded files before the first tool call; emit a one-line acknowledgment with a UTC timestamp.
- **Post-flight**: update `activeContext.md` and `progress.md` for any shipped change, append to `promptHistory.md`, update `CHANGELOG.md`, and commit locally.

`.memory-bank/` is version-controlled. Overwrite-in-place — do not let it grow without bound. Caps: `activeContext.md` < 200 lines, `progress.md` < 200 lines, `systemPatterns.md` ≈ 300 lines, `techContext.md` ≈ 200 lines, `projectbrief.md` ≈ 1 page.

## CHANGELOG Discipline

This project uses [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [SemVer](https://semver.org/) (see `CHANGELOG.md` header). For every user-visible change:

- Add an entry under `## [Unreleased]` in the appropriate section: `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, or `Security`.
- Reference issues/PRs as `([#NNN](https://github.com/dsccommunity/DscWorkshop/issues/NNN))`.
- Skip `CHANGELOG.md` only for: pure refactors with no behavior change, `.memory-bank/`-only edits, doc-only typo fixes, CI-internal tweaks.
- The `publish` workflow's `Create_ChangeLog_GitHub_PR` task moves `[Unreleased]` to a versioned section at release time — do not pre-rename.

## Commit & Branch Discipline

- **Conventional Commits**: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`, `build:`, `ci:`, `perf:`. Use scope where helpful, e.g. `fix(build): …`, `feat(gpo): …`.
- **AI-driven work**: branch with the `ai/<slug>` prefix and add a `Co-authored-by: AI Assistant <ai@example.com>` trailer. Never commit AI work directly to `main`.
- **Never push** unless the user explicitly asks — local commits only.
- Keep commits atomic and green. Don't commit code that breaks `./build.ps1`.
- PR template: `.github/PULL_REQUEST_TEMPLATE.md`.

## What NOT to Do

- Don't replace CommonTasks composites with hand-rolled DSC resources without an ADR-style entry in `progress.md` decision log.
- Don't add new build dependencies outside `RequiredModules.psd1`.
- Don't pin module versions just because — only pin when there's a known incompatibility, and document it in `progress.md`.
- Don't add `WriteHost`/colored output to build tasks; use `Write-Build` (InvokeBuild) so output is consistent with Sampler.
- Don't bypass safety checks (`--no-verify`, `git push --force`, etc.).

## Useful Pointers

- Lab deployment: `Lab/00 Lab Deployment.ps1 -HostType <Azure|HyperV>` — see `.memory-bank/labInfrastructure.md` and `Lab/readme.md`.
- GPO migration: `GPOs/README.md`.
- DevOps mapping (DORA, GitOps, IaC, Release Pipeline Model): `03 DevOps Principles and Patterns.md`.
- Exercises (learning path): `Exercises/Task1` → `Task2` → `Task3`.
