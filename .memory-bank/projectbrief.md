# DscWorkshop — Project Brief

## Purpose

DscWorkshop is the **reference implementation** of an enterprise-scale PowerShell DSC pipeline using the [Release Pipeline Model](../Exercises/TheReleasePipelineModel.pdf) (Greene & Murawski). It is both:

1. A **production blueprint** — copy/fork to bootstrap a real DSC pipeline.
2. An **educational resource** — progressive exercises (Task1–Task3) teach DSC, Datum, and the build pipeline.

## Core Capabilities

- **Hierarchical configuration data** via [Datum](https://github.com/gaelcolas/Datum) — 7-layer resolution (Node → Environment → Location → Role → Baseline).
- **Single build script** (`./build.ps1`) — generates MOF, MetaMOF, compressed modules, RSOP, and acceptance tests in one command.
- **Sampler-based build framework** with InvokeBuild tasks defined in `build.yaml`.
- **PSDepend-driven dependency resolution** — `RequiredModules.psd1` is the single source of truth.
- **CommonTasks composite resources** (migrated from `DscConfig.Demo`) for cleaner role/baseline YAML.
- **GPO → DSC migration toolkit** under `GPOs/` — 8 extraction + 2 QA scripts, ~98% setting coverage.
- **AutomatedLab** scripts under `Lab/` for end-to-end Hyper-V or Azure lab deployment.
- **Multi-platform CI/CD** — Azure DevOps (on-prem and hosted), Azure Automation DSC, Azure Guest Configuration, AppVeyor.

## Repository Facts

- **Upstream**: `dsccommunity/DscWorkshop` (default branch `main`).
- **Current working branch**: `docs`.
- **License**: MIT.
- **Primary languages**: PowerShell (DSC, build), YAML (configuration data).
- **Memory Bank**: `.memory-bank/` (this folder) — version-controlled, agent-discoverable per the workspace pre/post-flight hooks.

## Success Criteria

- `./build.ps1` produces a complete artifact set on PowerShell 5.1 and 7.x with zero errors.
- All Pester acceptance tests (`tests/`) pass.
- RSOP for every node matches its reference under `source/TestRsopReferences/`.
- New roles/baselines can be added by editing YAML only — no code changes to the build.
