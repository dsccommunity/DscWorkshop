# DevOps Principles and Patterns in DscWorkshop

This document maps the DscWorkshop project to established, technology-agnostic DevOps best practices and "* as Code" principles. It demonstrates how the project implements patterns from industry-standard frameworks such as [DORA](https://dora.dev), [The Twelve-Factor App](https://12factor.net), [GitOps](https://opengitops.dev), and [Infrastructure as Code](https://infrastructure-as-code.com) (Kief Morris, O'Reilly).

## Industry Frameworks and Pattern Libraries

The table below lists the foundational, tech-agnostic frameworks that define modern DevOps and infrastructure management best practices.

| Framework | Focus | Reference |
|---|---|---|
| **DORA** (DevOps Research & Assessment) | Four Key Metrics, capabilities catalog | <https://dora.dev> |
| **The Twelve-Factor App** | Cloud-native application design principles | <https://12factor.net> |
| **GitOps Principles** (CNCF) | Git as single source of truth for declarative infrastructure | <https://opengitops.dev> |
| **Infrastructure as Code** (Kief Morris) | Patterns for managing infrastructure with automation | <https://infrastructure-as-code.com> |
| **The Release Pipeline Model** (Greene & Murawski) | Configuration as code and release pipelines for operations | [TheReleasePipelineModel.pdf](./Exercises/TheReleasePipelineModel.pdf) |
| **Site Reliability Engineering** (Google) | SRE practices for operational excellence | <https://sre.google/books/> |
| **Continuous Delivery** (Humble & Farley) | Deployment pipelines and release engineering | <https://continuousdelivery.com> |

## Core Principles and How DscWorkshop Implements Them

### 1. Version Control Everything

> *"Store all production artifacts in a version control system."* — Accelerate (Forsgren, Humble, Kim)

| What to Version-Control | DscWorkshop Implementation |
|---|---|
| Infrastructure definitions | All node definitions, roles, baselines, and environment data stored as YAML in [`source/`](./source) |
| Configuration data | Datum YAML hierarchy under [`source/AllNodes/`](./source/AllNodes), [`source/Roles/`](./source/Roles), [`source/Baselines/`](./source/Baselines), [`source/Locations/`](./source/Locations), [`source/Environment/`](./source/Environment) |
| Pipeline definitions | Multiple `azure-pipelines*.yml` files in the repository root |
| Build configuration | [`build.yaml`](./build.yaml), [`build.ps1`](./build.ps1), and [`RequiredModules.psd1`](./RequiredModules.psd1) — all version-controlled |
| Test definitions | [`tests/`](./tests) directory with ConfigData and Acceptance tests |

Git is the **single source of truth**. Every aspect of the infrastructure — node definitions, roles, baselines, environments, pipelines, build configuration, and tests — lives in the repository. This directly follows the [GitOps](https://opengitops.dev) principle.

### 2. Declarative Over Imperative

> *"Describe the desired state of the system, not the steps to get there."*

DscWorkshop uses YAML files to **declaratively describe desired state**:

```yaml
NodeName: DSCFile01
Role: FileServer
Location: Frankfurt
Baseline: Server
Configurations:
  - FilesAndFolders
  - RegistryValues
```

The system computes the **Resultant Set of Policy (RSOP)** by merging hierarchical layers — you describe *what* the state should be, not *how* to achieve it. PowerShell DSC then enforces **idempotent convergence** to that state.

### 3. Hierarchical Configuration Data

> *"Don't Repeat Yourself."* — The Pragmatic Programmer (Hunt & Thomas)

This is where DscWorkshop goes beyond most Infrastructure as Code implementations. The [Datum](https://github.com/gaelcolas/Datum) module implements a **hierarchical lookup system** (inspired by Puppet's Hiera):

```
source/
├── Global/          → Organization-wide defaults
├── Baselines/       → Security and compliance baselines
├── Environment/     → Dev / Test / Prod overrides
├── Locations/       → Geographic / datacenter-specific settings
├── Roles/           → Server role definitions (FileServer, WebServer, etc.)
└── AllNodes/        → Individual node-specific data
    ├── Dev/
    ├── Test/
    └── Prod/
```

Resolution precedence flows from most-specific (node) to least-specific (global), with configurable merge strategies (MostSpecific, deep merge, UniqueKeyValTuples). See [`source/Datum.yml`](./source/Datum.yml) for the full configuration.

This pattern mirrors Kief Morris's **Stack Pattern** from *Infrastructure as Code* and directly addresses the [DSC Configuration Data Problem](https://gaelcolas.com/2018/01/29/the-dsc-configuration-data-problem/).

### 4. Single Build Script — Automate Repeatably

> *"If it hurts, do it more frequently, and bring the pain forward."* — Continuous Delivery (Humble & Farley)

The entire build process is triggered by a single command:

```powershell
.\build.ps1 -ResolveDependency
```

This orchestrates:

1. **Dependency resolution** — all PowerShell modules downloaded automatically
2. **Configuration data loading** — Datum validates and loads YAML hierarchy
3. **RSOP computation** — Resultant Set of Policy computed for every node
4. **MOF compilation** — DSC configuration files generated
5. **Meta-MOF generation** — LCM configurations created
6. **Module packaging** — PowerShell modules packaged with checksums
7. **Automated testing** — multi-level quality gates
8. **Artifact packaging** — deployment-ready artifacts created

No manual steps, no pre-installation. The build is **identical** whether run locally on a developer workstation or inside a CI/CD pipeline.

### 5. Immutable Artifacts

> *"Replace, don't patch."* — Infrastructure as Code (Kief Morris)

Generated MOF files are **immutable deployment artifacts**:

- Compiled from declarative source data
- Checksummed for integrity verification
- Never modified post-build — only replaced by a new build
- Packaged with their module dependencies

This follows the "cattle, not pets" principle — artifacts are disposable and fully reproducible from source.

### 6. Automated Testing and Quality Gates

> *"Build quality in."* — The DevOps Handbook (Kim, Humble, Debois, Willis, Forsgren)

| Test Level | Implementation |
|---|---|
| **Configuration data validation** | [`tests/ConfigData/`](./tests/ConfigData) — validates YAML syntax, schema compliance, no duplicate IPs, required fields |
| **RSOP reference tests** | Compares generated RSOP against [`source/TestRsopReferences/`](./source/TestRsopReferences) to detect unintended changes |
| **Acceptance tests** | [`tests/Acceptance/`](./tests/Acceptance) — validates generated MOF files |
| **HQRM tests** | High Quality Resource Module tests for code quality |
| **CI trigger** | Every commit triggers a full build + test cycle |

Testing is **embedded** in the build pipeline ("shift left"), not bolted on afterward.

### 7. CI/CD Pipeline Integration

> *"Deployment should be routine and low-risk."* — Continuous Delivery (Humble & Farley)

DscWorkshop supports multiple CI/CD platforms out of the box:

| Pipeline File | Target |
|---|---|
| [`azure-pipelines.yml`](./azure-pipelines.yml) | Standard Azure DevOps |
| [`azure-pipelines On-Prem.yml`](<./azure-pipelines On-Prem.yml>) | On-premises Azure DevOps Server |
| [`azure-pipelines-azautomation.yml`](./azure-pipelines-azautomation.yml) | Azure Automation DSC |
| [`azure-pipelines Guest Configuration.yml`](<./azure-pipelines Guest Configuration.yml>) | Azure Policy Guest Configuration |

The release pipeline implements **staging rings** — artifacts progress through Dev → Test → Production with automated gates at each stage. This directly follows [The Release Pipeline Model](./Exercises/TheReleasePipelineModel.pdf).

### 8. Dependency Resolution

> *"Explicitly declare and isolate dependencies."* — The Twelve-Factor App, Factor II

All dependencies are declared in [`RequiredModules.psd1`](./RequiredModules.psd1) and resolved automatically. No pre-installation of modules is required — the build agent starts clean and pulls everything it needs. This enables **reproducible builds** on any machine.

### 9. Environment as Code

> *"Treat your environments as cattle, not pets."*

Complete lab environments are defined as code using [AutomatedLab](https://automatedlab.org/):

- Active Directory Domain Controller
- SQL Server
- Azure DevOps Server (with NuGet feeds, build agents, and pipelines)
- DSC Pull Server
- Certificate Authority
- Routing infrastructure

The entire environment deploys from scripts in the [`Lab/`](./Lab) directory. See [01 AutomatedLab.md](<./01 AutomatedLab.md>) for details.

### 10. Security as Code

> *"Security is everyone's job."* — The DevOps Handbook

| Security Aspect | Implementation |
|---|---|
| **Encrypted secrets** | [Datum.ProtectedData](https://github.com/gaelcolas/Datum.ProtectedData) with certificate-based encryption |
| **Credential isolation** | Sensitive data separated from general configuration data |
| **Security baselines** | [`source/Baselines/`](./source/Baselines) with security configurations |
| **Policy migration** | [GPO to DSC Migration Toolkit](./GPOs/) — 8 extraction scripts, 98% coverage |
| **Validation-first** | All configurations validated before deployment |

### 11. Documentation as Code

> *"Docs should live alongside code and evolve with it."*

The project includes documentation as version-controlled Markdown:

- Progressive exercises ([Task 1](./Exercises/Task1) → [Task 2](./Exercises/Task2) → [Task 3](./Exercises/Task3))
- Architecture documentation and technical summaries
- [YAML reference documentation](https://github.com/raandree/DscConfig.Demo/tree/main/doc/README.adoc)
- [Lab deployment guides](./Lab)
- [GPO migration documentation](./GPOs/README.md)

## The "* as Code" Patterns

DscWorkshop implements the complete "* as Code" spectrum:

| Pattern | Description | DscWorkshop Component |
|---|---|---|
| **Infrastructure as Code** | Servers and resources defined in version-controlled files | YAML node definitions + DSC resources |
| **Configuration as Code** | Application and system configuration in declarative files | Datum YAML hierarchy |
| **Policy as Code** | Security and compliance rules as executable code | Security baselines, GPO migration toolkit |
| **Pipeline as Code** | CI/CD pipelines defined in repository files | `azure-pipelines*.yml` |
| **Documentation as Code** | Docs in Markdown, versioned alongside code | `Exercises/`, `README.md`, this file |
| **Security as Code** | Secrets management and access policies automated | Datum.ProtectedData, certificate-based encryption |
| **Environment as Code** | Full environment definitions as reproducible specs | AutomatedLab scripts in `Lab/` |
| **Monitoring as Code** | Reporting and observability defined declaratively | DscTagging for DSC reporting |

## Mapping to DORA Capabilities

The [DORA capabilities catalog](https://dora.dev/capabilities/) identifies 27+ capabilities that drive software delivery performance. DscWorkshop addresses the following:

| DORA Capability | DscWorkshop Coverage |
|---|---|
| Version control | All infrastructure, config, pipelines, and tests in Git |
| Continuous integration | Every commit triggers build + test |
| Deployment automation | Automated release pipeline with staging rings |
| Trunk-based development | Supports branching model with CI triggers |
| Test automation | Multi-level automated testing (ConfigData, RSOP, Acceptance, HQRM) |
| Loosely coupled architecture | Modular roles, configurations, and data layers |
| Monitoring and observability | DSC Tagging for reporting |
| Documentation quality | Comprehensive exercises and reference documentation |
| Work in small batches | YAML-based changes are naturally small and focused |
| Team experimentation | Lab environment enables safe experimentation |

## Key DevOps Principles — Quick Reference

These ten principles are technology-agnostic. DscWorkshop implements all of them:

1. **Version control everything** — infrastructure, config, pipelines, policies, docs
2. **Automate repeatably** — no manual steps in build, test, or deploy
3. **Shift left** — testing, security, and compliance earlier in the pipeline
4. **Immutable artifacts** — replace, don't patch
5. **Declarative over imperative** — describe desired state, not steps
6. **Idempotency** — running the same operation multiple times yields the same result
7. **Small batch sizes** — frequent, small changes reduce risk
8. **Fast feedback loops** — automated tests, monitoring, alerting
9. **Cattle, not pets** — servers and artifacts are disposable and reproducible
10. **Blameless postmortems** — learn from failures without assigning blame

## Further Reading

| Resource | Description | Link |
|---|---|---|
| The Release Pipeline Model | Foundational whitepaper for this project | [TheReleasePipelineModel.pdf](./Exercises/TheReleasePipelineModel.pdf) |
| DORA Capabilities | Research-backed DevOps capabilities catalog | <https://dora.dev/capabilities/> |
| Infrastructure as Code (Book) | Patterns for managing infrastructure with automation | <https://infrastructure-as-code.com> |
| The DevOps Handbook | Comprehensive DevOps practices guide | <https://itrevolution.com/product/the-devops-handbook-second-edition/> |
| Accelerate | Research-backed DevOps metrics and capabilities | <https://itrevolution.com/product/accelerate/> |
| Site Reliability Engineering | Google's SRE practices (free online) | <https://sre.google/books/> |
| GitOps Principles | Vendor-neutral GitOps definition (CNCF) | <https://opengitops.dev> |
| The Twelve-Factor App | Cloud-native design principles | <https://12factor.net> |
| Datum Documentation | Hierarchical configuration data for DSC | <https://github.com/gaelcolas/Datum> |
| DSC Configuration Data Problem | Why traditional DSC config data fails at scale | <https://gaelcolas.com/2018/01/29/the-dsc-configuration-data-problem/> |
| Composing DSC Roles | DRY patterns for DSC configurations | <https://gaelcolas.com/2018/02/07/composing-dsc-roles/> |
