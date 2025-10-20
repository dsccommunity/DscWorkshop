# Technical Context - DSC Workshop

## Technology Stack

### Core Technologies

**PowerShell DSC (Desired State Configuration)**
- **Version**: PowerShell 5.1+ (Windows PowerShell) / PowerShell 7+ (PowerShell Core)
- **Purpose**: Declarative configuration management for Windows systems
- **Key Features**: Resource-based configuration, idempotent operations, reporting

**Datum Configuration Management**
- **Version**: Latest from PowerShell Gallery
- **Purpose**: Hierarchical configuration data management
- **Key Features**: YAML-based configuration, inheritance, encryption support
- **GitHub**: https://github.com/gaelcolas/Datum

**Sampler Build Framework**
- **Version**: Latest from PowerShell Gallery  
- **Purpose**: PowerShell module build and release automation
- **Key Features**: Standardized build tasks, CI/CD integration, quality gates
- **GitHub**: https://github.com/gaelcolas/Sampler

### Build and Testing Tools

**InvokeBuild**
- **Purpose**: Task-based build automation engine
- **Usage**: Orchestrates all build tasks (compilation, testing, packaging)
- **Configuration**: build.yaml defines build workflows and tasks

**Pester Testing Framework**
- **Version**: 4.x+ (compatible with both 4.x and 5.x)
- **Purpose**: Unit testing, integration testing, configuration validation
- **Test Types**: Configuration data tests, DSC resource tests, acceptance tests

**PSDepend Dependency Management**
- **Purpose**: Automatic resolution and installation of PowerShell module dependencies
- **Configuration Files**:
  - `RequiredModules.psd1`: Main dependency definitions
  - `PSDepend.build.psd1`: Build-time dependencies
  - `PSDepend.DscConfigurations.psd1`: DSC composite resource dependencies
  - `PSDepend.DscResources.psd1`: DSC resource module dependencies

### Development Environment Requirements

**Local Development Setup**
- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Windows PowerShell 5.1 (minimum)
- **Git**: Required for source control operations
- **Visual Studio Code**: Recommended IDE with PowerShell extension
- **Execution Policy**: Set to allow script execution (`Set-ExecutionPolicy Bypass`)

**Optional Lab Infrastructure**
- **Hyper-V**: For local lab deployment using AutomatedLab
- **Azure Subscription**: For cloud-based lab scenarios
- **AutomatedLab**: Automated lab deployment framework

### CI/CD Platform Support

**Supported Platforms**
- **Azure DevOps**: Full pipeline support with YAML pipelines
- **Azure DevOps Server**: On-premises TFS/Azure DevOps Server
- **AppVeyor**: Cloud-based CI/CD platform
- **GitLab**: GitLab CI pipeline support
- **GitHub Actions**: Modern GitHub-integrated CI/CD

**Pipeline Configuration Files**
- `azure-pipelines.yml`: Standard Azure DevOps pipeline
- `azure-pipelines-azautomation.yml`: Azure Automation DSC integration
- `azure-pipelines On-Prem.yml`: On-premises deployment pipeline
- `azure-pipelines Guest Configuration.yml`: Azure Guest Configuration pipeline

### Module Dependencies

**Core DSC Resources**
- `PSDscResources`: Basic Windows DSC resources
- `ComputerManagementDsc`: Computer and domain management
- `SecurityPolicyDsc`: Security policy configuration
- `NetworkingDsc`: Network configuration resources
- `WebAdministrationDsc`: IIS and web server management

**Build Dependencies**
- `ModuleBuilder`: Module building and metadata management
- `Datum`: Configuration data management
- `Datum.ProtectedData`: Encrypted configuration data support
- `Datum.InvokeCommand`: Dynamic command execution in configurations

**Testing Dependencies**
- `Pester`: Testing framework
- `DscResource.Test`: DSC-specific testing utilities

### Configuration Management

**YAML Configuration Structure**
- **Encoding**: UTF-8 with BOM (to support special characters)
- **Syntax**: Standard YAML with specific DSC patterns
- **Validation**: Schema validation using Pester tests
- **Encryption**: Sensitive data encrypted using certificates

**File Organization**
```
source/
├── Datum.yml              # Hierarchy and resolution configuration
├── AllNodes/             # Node-specific configurations
│   ├── Dev/              # Development environment nodes
│   ├── Test/             # Test environment nodes  
│   └── Prod/             # Production environment nodes
├── Environments/         # Environment-wide settings
├── Locations/           # Location-specific settings
├── Roles/               # Role-based configurations
├── Baselines/           # Base configurations
└── Global/              # Global settings and data
```

### Artifact Generation

**Output Structure**
```
output/
├── MOF/                 # Compiled DSC configuration files
├── MetaMOF/            # LCM configuration files
├── Module/             # Built PowerShell module
├── RequiredModules/    # Downloaded dependency modules
├── CompressedModules/  # Packaged modules with checksums
├── CompressedArtifacts/ # Deployment packages
├── RSOP/               # Resultant Set of Policy files
└── testResults/        # Test execution results
```

### Security Considerations

**Credential Management**
- **Certificate-based Encryption**: Sensitive data encrypted using PKI certificates
- **Separation of Secrets**: Production secrets not stored in development repositories
- **Secure Transport**: All communications use HTTPS/secure protocols

**Access Control**
- **Repository Access**: Git repository access controls
- **Pipeline Permissions**: CI/CD pipeline security boundaries
- **Deployment Permissions**: Restricted deployment account privileges

### Performance Characteristics

**Build Performance**
- **Dependency Resolution**: 2-5 minutes for initial setup
- **Configuration Compilation**: 30 seconds to 5 minutes depending on node count
- **Testing Execution**: 1-3 minutes for full test suite
- **Artifact Packaging**: 30 seconds to 2 minutes

**Scalability Limits**
- **Node Count**: Tested with 100+ nodes in single environment
- **Configuration Complexity**: Supports complex multi-role configurations
- **Module Dependencies**: Handles 50+ PowerShell module dependencies

### Integration Patterns

**Source Control Integration**
- **Branching Strategy**: GitFlow or GitHub Flow patterns
- **Pull Request Validation**: Automated validation on pull requests
- **Branch Policies**: Enforce quality gates before merge

**Deployment Integration**
- **Pull Server Integration**: DSC Pull Server configuration management
- **Azure Automation DSC**: Cloud-based DSC service integration
- **Guest Configuration**: Azure Policy Guest Configuration support

This technical foundation provides a robust, scalable platform for enterprise DSC implementation with comprehensive tooling and automation support.
