# System Patterns - DSC Workshop

## Architecture Overview

DSC Workshop implements a **layered configuration architecture** that separates concerns and provides maximum flexibility for managing Windows infrastructure at scale.

### Core Architectural Principles

1. **Separation of Concerns**: Configuration data, DSC resources, and build logic are clearly separated
2. **Hierarchical Inheritance**: Configurations inherit and merge from multiple organizational layers
3. **Composition over Inheritance**: Complex configurations built by composing simpler, reusable components
4. **Immutable Artifacts**: Generated MOF files are immutable deployment artifacts
5. **Data-Driven Configuration**: All configuration decisions driven by YAML data files

## Configuration Data Hierarchy

```
Resolution Precedence (Most Specific → Least Specific):
1. AllNodes\{Environment}\{NodeName}     # Node-specific overrides
2. Environment\{Environment}             # Environment-wide settings
3. Locations\{Location}                  # Geographic/datacenter specific
4. Roles\{Role}                         # Role-based configurations
5. Baselines\Security                   # Security baseline (always applied)
6. Baselines\{Baseline}                 # Infrastructure baseline
7. Baselines\DscLcm                    # LCM configuration baseline
```

### Data Resolution Strategy

- **MostSpecific**: Higher precedence values override lower precedence
- **Deep Merge**: Hash tables are merged recursively
- **Array Strategies**: 
  - `Unique`: Remove duplicates from merged arrays
  - `UniqueKeyValTuples`: Merge arrays of objects by unique key combinations

## Key Design Patterns

### 1. Composite Resource Pattern

**Problem**: DSC resources are too granular for complex configurations

**Solution**: Create composite resources that group related DSC resources

```yaml
# Example: WebServer role composition
Configurations:
  - WindowsFeatures      # IIS installation
  - WindowsServices     # Service configuration
  - FileSystemObjects   # Directory structure
  - WebApplicationPools # Application pools
  - WebApplications     # Web applications
```

### 2. Layered Configuration Pattern

**Problem**: Environment differences create configuration explosion

**Solution**: Layer configurations with inheritance and override capabilities

```yaml
# Role defines base configuration
Roles\WebServer.yml:
  WindowsFeatures:
    - IIS-WebServer
    - IIS-HttpRedirect

# Environment overrides for production
Environment\Prod.yml:
  WindowsFeatures:
    - IIS-WebServer
    - IIS-HttpRedirect
    - IIS-HttpLogging  # Additional feature for prod
```

### 3. Configuration as Code Pattern

**Problem**: Configuration drift and lack of version control

**Solution**: All configurations stored as code with full CI/CD pipeline

- **Source Control**: All configuration files version controlled
- **Automated Testing**: Configuration validation and compliance testing
- **Immutable Deployment**: Generated artifacts deployed without modification
- **Rollback Capability**: Git history enables configuration rollback

### 4. Build Artifact Pattern

**Problem**: Deployment complexity and dependency management

**Solution**: Single build process generates all deployment artifacts

```
Build Process:
1. Load configuration data using Datum
2. Resolve PowerShell module dependencies
3. Compile MOF files for each node
4. Generate LCM meta-configuration files
5. Package modules with checksums
6. Create compressed artifact collections
```

## Component Relationships

### Data Flow Architecture

```
YAML Config Files → Datum → DSC Compilation → MOF Files → Target Nodes
                     ↓
              Build Validation ← Pester Tests ← Reference Files
```

### Module Dependencies

1. **Datum**: Configuration data management and hierarchical resolution
2. **Sampler**: PowerShell module build framework providing build infrastructure
3. **InvokeBuild**: Task-based build automation engine
4. **PSDepend**: Automatic dependency resolution for PowerShell modules
5. **Pester**: Testing framework for configuration validation

### Critical Implementation Paths

#### Configuration Compilation Path
1. **Data Loading**: `LoadDatumConfigData` task loads and validates YAML files
2. **RSOP Generation**: `CompileDatumRsop` creates Resultant Set of Policy for each node
3. **MOF Compilation**: `CompileRootConfiguration` generates DSC configuration files
4. **Meta MOF Generation**: `CompileRootMetaMof` creates LCM configurations

#### Testing and Validation Path
1. **Config Data Tests**: Validate YAML syntax and schema compliance
2. **DSC Resource Tests**: Verify all required DSC resources are available
3. **Reference RSOP Tests**: Compare generated configurations against reference files
4. **Acceptance Tests**: End-to-end validation of generated artifacts

#### Artifact Creation Path
1. **Module Compression**: Package PowerShell modules with checksums
2. **MOF Checksums**: Generate checksums for configuration files
3. **Artifact Collections**: Create compressed deployment packages
4. **Build Validation**: Final acceptance testing of all artifacts

## Security Architecture

### Secret Management Pattern
- **Encrypted Secrets**: Sensitive data encrypted using Datum.ProtectedData
- **Certificate-based Encryption**: PKI certificates secure credential data
- **Separation of Secrets**: Sensitive data isolated from general configuration

### Validation Security
- **Configuration Validation**: All configurations tested before deployment
- **Resource Verification**: DSC resources validated for security compliance
- **Baseline Enforcement**: Security baselines applied to all configurations

## Scalability Patterns

### Horizontal Scaling
- **Role-based Organization**: Configurations organized by server roles
- **Environment Separation**: Clear boundaries between environments
- **Modular Composition**: Reusable configuration components

### Build Optimization
- **Filtered Compilation**: Build only changed configurations
- **Parallel Processing**: Concurrent MOF compilation where possible
- **Incremental Testing**: Test only affected configurations

This architectural foundation enables DSC Workshop to scale from simple proof-of-concepts to complex enterprise deployments while maintaining consistency, security, and reliability.
