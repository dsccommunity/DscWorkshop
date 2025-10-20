# DSC Workshop - Project Brief

## Project Overview
DSC Workshop is a comprehensive blueprint project demonstrating how to implement **Desired State Configuration (DSC)** at medium to complex enterprise scale using modern DevOps practices. This is a foundational project for infrastructure as code, following the Release Pipeline Model principles.

## Core Purpose
- **Infrastructure as Code**: Manage Windows infrastructure declaratively using DSC
- **Configuration Management**: Provide scalable, maintainable configuration data management using Datum
- **Release Pipeline**: Implement fully automated build/test/deploy pipelines for infrastructure
- **Educational Resource**: Teach DSC best practices through hands-on exercises

## Key Problems Solved
1. **Configuration Data Complexity**: Traditional DSC approaches become unmanageable at scale - this project uses Datum for hierarchical configuration data
2. **Automated Build Process**: Single build script generates all DSC artifacts (MOF, Meta MOF, Compressed Modules)
3. **Dependency Management**: Automated resolution of PowerShell modules and dependencies using PSDepend
4. **Testing & Validation**: Comprehensive testing strategy including configuration data validation and infrastructure acceptance testing
5. **CI/CD Integration**: Full pipeline support for Azure DevOps, Azure DevOps Server, AppVeyor, GitLab

## Technologies & Architecture
- **PowerShell DSC**: Core configuration management technology
- **Datum**: Configuration data management framework
- **Sampler**: PowerShell module build framework
- **Pester**: Testing framework
- **InvokeBuild**: Build automation
- **AutomatedLab**: Lab deployment automation
- **Azure DevOps**: CI/CD pipelines

## Project Structure
```
DscWorkshop/
├── source/               # Configuration data and DSC composites
│   ├── AllNodes/        # Node-specific configurations by environment
│   ├── Baselines/       # Base configurations (LCM, Security)
│   ├── Roles/           # Role-based configurations (WebServer, FileServer, etc.)
│   ├── Environments/    # Environment-specific settings
│   ├── Locations/       # Location-specific settings
│   └── Datum.yml        # Configuration hierarchy definition
├── Exercises/           # Hands-on learning exercises (Task 1-3)
├── Lab/                 # AutomatedLab deployment scripts
├── tests/               # Validation and acceptance tests
├── output/              # Generated artifacts (MOF files, modules, etc.)
└── build.ps1            # Single build script for all operations
```

## Success Criteria
- Automated generation of DSC MOF files for all nodes
- Successful validation of configuration data against schemas
- Passing acceptance tests for all generated configurations
- Functional CI/CD pipeline integration
- Comprehensive documentation for learning and maintenance

## Target Audience
- Infrastructure engineers learning DSC
- DevOps teams implementing infrastructure as code
- Organizations seeking scalable configuration management
- Students of the Release Pipeline Model

## Learning Path
1. **Task 1**: DSC fundamentals (configurations, MOF compilation, local application)
2. **Task 2**: Build environment and configuration data management with Datum
3. **Task 3**: CI/CD pipeline integration with Azure DevOps

## External Dependencies
- PowerShell 5.1+
- DSC-related PowerShell modules (auto-resolved via PSDepend)
- Azure subscription (for cloud scenarios)
- Hyper-V or Azure (for lab scenarios)

## Repository Context
- **Repository**: raandree/DscWorkshop
- **Current Branch**: fix/labSetup
- **Default Branch**: main
- **Primary Author**: DSC Community
- **License**: MIT

This project serves as both a reference implementation and educational resource for modern DSC practices in enterprise environments.
