# Lab Infrastructure Documentation

## Overview

The `Lab/` folder contains automated laboratory deployment scripts and resources for the DSC Workshop project. These scripts use **AutomatedLab** to create complete, production-like environments for learning, testing, and demonstrating DSC concepts in both Azure and Hyper-V environments.

## Lab Architecture

### Core Infrastructure Components

The lab creates a comprehensive Windows infrastructure environment with the following components:

#### Network Architecture
- **Domain**: `contoso.com` with Domain Controller
- **Network Range**: `192.168.111.0/24`
- **Gateway**: `192.168.111.50` (for Hyper-V environments)
- **DNS**: Domain Controller at `192.168.111.10`

#### Server Roles and Infrastructure

**Domain Controller (DSCDC01)**
- **IP**: `192.168.111.10`
- **Memory**: 1GB
- **Role**: Root Domain Controller
- **Purpose**: Active Directory services, DNS, lab user management

**Certificate Authority and SQL Server (DSCCASQL01)**
- **IP**: Not specified (DHCP or static based on environment)
- **Memory**: 3GB
- **Roles**: Certificate Authority (Root CA), SQL Server 2019
- **Purpose**: PKI infrastructure, DSC Pull Server database backend

**DSC Pull Server (DSCPull01)**
- **IP**: `192.168.111.60`
- **Memory**: 4GB
- **Roles**: DSC Pull Server, Web Server, Build Worker
- **Purpose**: Central DSC configuration distribution, web services
- **Database**: SQL Server backend on DSCCASQL01

**Azure DevOps Server (DSCDO01)**
- **IP**: `192.168.111.70`
- **Memory**: 6GB
- **Role**: Azure DevOps Server
- **Storage**: Additional 120GB data disk
- **Purpose**: CI/CD pipelines, source control, build automation

**Hyper-V Host (DSCHost01)**
- **IP**: `192.168.111.80`
- **Memory**: 16GB (Azure) / 8GB (Hyper-V)
- **Roles**: Hyper-V Host, Build Worker (4 workers)
- **Storage**: Additional 120GB data disk
- **Purpose**: Nested virtualization, additional build capacity

#### Target Nodes by Environment

**Development Environment (192.168.111.100-101)**
- **DSCFile01**: File Server role (192.168.111.100)
- **DSCWeb01**: Web Server role (192.168.111.101)

**Test Environment (192.168.111.110-111)**
- **DSCFile02**: File Server role (192.168.111.110)
- **DSCWeb02**: Web Server role (192.168.111.111)

**Production Environment (192.168.111.120-121)**
- **DSCFile03**: File Server role (192.168.111.120)
- **DSCWeb03**: Web Server role (192.168.111.121)

## Script Documentation

### Core Deployment Scripts

#### `00 Lab Deployment.ps1`
**Purpose**: Master orchestration script that executes all lab setup scripts in proper sequence

**Parameters**:
- `HostType`: [Mandatory] Either 'Azure' or 'HyperV'

**Functionality**:
- Imports AutomatedLab modules
- Filters and executes appropriate scripts based on host type
- Provides centralized deployment entry point

**Usage**:
```powershell
.\00 Lab Deployment.ps1 -HostType Azure
.\00 Lab Deployment.ps1 -HostType HyperV
```

#### `10 Azure Full Lab with DSC and AzureDevOps.ps1`
**Purpose**: Creates complete DSC Workshop lab in Azure cloud environment

**Key Features**:
- Random lab name generation for Azure uniqueness
- Azure-specific VM sizes (`Standard_D8alds_v6`)
- Premium SSD storage for performance
- No validation mode for faster deployment
- Automatic snapshot creation after installation

**Dependencies**:
- Azure subscription with sufficient quota
- AutomatedLab Azure integration configured
- Required ISO files in lab sources

#### `10 HyperV Full Lab with DSC and AzureDevOps.ps1`
**Purpose**: Creates complete DSC Workshop lab on local Hyper-V infrastructure

**Key Features**:
- External network adapter configuration
- Lower memory requirements for local deployment
- SQL Server 2019 ISO requirement
- Network routing configuration
- Windows Update service disabled for stability

**Dependencies**:
- Hyper-V feature enabled
- Sufficient local storage and memory
- Required ISO files downloaded locally

### Configuration and Customization Scripts

#### `20 Lab Customizations.ps1`
**Purpose**: Post-deployment customization and software installation

**Key Features**:
- Intelligent lab import with fallback logic
- Staged VM startup sequence (DC → SQL → DevOps → Others)
- PowerShell module installation and configuration
- Software package deployment via chocolatey/direct download
- DSC configuration and pull server setup

**Software Packages Installed**:
- Visual Studio Code with PowerShell extension
- Git for Windows
- PowerShell 7
- .NET SDK and Runtime
- 7-Zip
- Notepad++

#### `20 SoftwarePackages.psd1`
**Purpose**: Defines software packages for automated installation

**Package Structure**:
```powershell
PackageName = @{
    Url         = 'Download URL'
    CommandLine = 'Silent install parameters'
    Roles       = 'Target roles or All'
}
```

**Role-Based Installation**:
- **All**: Basic utilities (Notepad++, 7-Zip)
- **AzDevOps**: Development tools (VS Code, Git, PowerShell 7, .NET SDK)

### Pipeline and Integration Scripts

#### `31 New Release Pipeline DscConfig.Demo.ps1`
**Purpose**: Sets up Azure DevOps project and pipeline for DscConfig.Demo repository

**Features**:
- Automated project creation in Azure DevOps
- Git repository integration
- Build pipeline configuration
- NuGet feed setup for PowerShell modules
- GitVersion extension installation

#### `32 New Release Pipeline DscWorkshop.ps1`
**Purpose**: Sets up Azure DevOps project and pipeline for DscWorkshop repository

**Features**:
- DscWorkshop-specific project configuration
- Integration with DSC Pull Server
- Hyper-V host coordination
- Multi-environment deployment pipeline

#### `33 Install DscAutoOnboarding.ps1`
**Purpose**: Configures automatic DSC node onboarding capabilities

**Functionality**:
- Active Directory integration for DSC onboarding
- Automated endpoint configuration
- DSC configuration assignment automation

### Database and Reporting Scripts

#### `40 SQL Server Reporting DB.ps1`
**Purpose**: Configures SQL Server reporting database for DSC operations

**Features**:
- DSC compliance reporting database setup
- SQL Server Reporting Services configuration
- Report deployment and configuration

### Supporting Components

#### `DscAutoOnboarding/` Directory
Contains scripts and configurations for automated DSC node onboarding:
- **Install-DscAutoOnboarding.ps1**: Main installation script
- **New-AdDscAutoOnboardingGroup.ps1**: AD group creation for DSC nodes
- **New-DscAutoOnboardingEndpoint.ps1**: Endpoint configuration
- **Start-DscAutoOnboarding.ps1**: Onboarding process initiation
- **DscConfigs/**: DSC configuration files for onboarding

#### `Reports/` Directory
SQL Server Reporting Services reports for DSC monitoring:
- **NodeAdditionalInfo.rdl**: Additional node information reports
- **NodeConfigurationData.rdl**: Configuration data reports
- **NodeMetaData.rdl**: Node metadata reports
- **NodeStatusOverview.rdl**: Overall node status dashboard

#### `LabData/` Directory
Supporting files and utilities for lab operation:
- **DummyService.exe**: Test service for configuration examples
- **gittools.gitversion-5.0.1.3.vsix**: GitVersion extension for Azure DevOps
- **Helpers.psm1**: Common helper functions
- **LabSite.zip**: Sample web application content

## Prerequisites and Requirements

### General Requirements
- **AutomatedLab PowerShell Module**: Latest version from PowerShell Gallery
- **PowerShell Execution Policy**: Set to allow script execution
- **Administrative Privileges**: Required for VM and network creation
- **Git**: For source control operations

### Azure-Specific Requirements
- **Azure Subscription**: With sufficient compute and storage quota
- **Azure PowerShell Module**: Az module installed and configured
- **Azure Subscription Authentication**: `Connect-AzAccount` completed
- **Resource Quotas**: Minimum 6 VMs with 2+ cores each

### Hyper-V-Specific Requirements
- **Hyper-V Feature**: Enabled on Windows host
- **Available Memory**: Minimum 32GB recommended for full lab
- **Storage Space**: Minimum 500GB available for VMs and ISOs
- **Network Configuration**: External switch for internet connectivity

### Required ISO Files
- **Windows Server 2022**: Evaluation ISO from Microsoft
- **Azure DevOps Server 2022.2**: From Microsoft Download Center
- **SQL Server 2019**: Evaluation ISO (Hyper-V only, Azure uses marketplace image)

## Deployment Process

### Standard Deployment Sequence

1. **Environment Preparation**
   ```powershell
   Install-Module AutomatedLab -AllowClobber -Force
   New-LabSourcesFolder
   # Copy ISOs to appropriate folders
   ```

2. **Lab Deployment**
   ```powershell
   # For Azure
   Connect-AzAccount
   .\00 Lab Deployment.ps1 -HostType Azure
   
   # For Hyper-V
   .\00 Lab Deployment.ps1 -HostType HyperV
   ```

3. **Post-Deployment Customization**
   ```powershell
   .\20 Lab Customizations.ps1
   ```

4. **Pipeline Setup**
   ```powershell
   .\31 New Release Pipeline DscConfig.Demo.ps1
   .\32 New Release Pipeline DscWorkshop.ps1
   ```

5. **Optional Components**
   ```powershell
   .\33 Install DscAutoOnboarding.ps1
   .\40 SQL Server Reporting DB.ps1
   ```

### Estimated Deployment Times
- **Azure Lab**: 2-3 hours (depending on region and quota)
- **Hyper-V Lab**: 3-5 hours (depending on host specifications)
- **Customization**: 30-60 minutes
- **Pipeline Setup**: 15-30 minutes per pipeline

## Troubleshooting and Maintenance

### Common Issues

**Lab Import Failures**
- Multiple DscWorkshop labs exist
- Solution: Remove unused lab definitions or specify exact lab name

**Network Connectivity Issues**
- Check external switch configuration (Hyper-V)
- Verify Azure virtual network settings
- Validate DNS server configuration

**Resource Constraints**
- Insufficient memory allocation
- Storage space limitations
- Azure quota restrictions

### Maintenance Operations

**Snapshot Management**
- Automatic snapshots created after major installations
- Use for rollback after configuration experiments
- Regular cleanup recommended to save storage

**VM State Management**
- Start/stop sequences preserve dependencies
- Domain controller must be started first
- SQL Server before DSC Pull Server

**Updates and Patches**
- Windows Update disabled by default for lab stability
- Manual patching recommended for production-like testing
- AutomatedLab provides update management tools

## Security Considerations

### Lab Security Model
- **Development/Training Environment**: Not production-hardened
- **Clear-text Passwords**: Used for simplicity in lab scenarios
- **Default Credentials**: Install/Somepass1 (change for production use)
- **Certificate Authority**: Self-signed certificates for lab use only

### Network Security
- **Isolated Environment**: Lab network separated from production
- **Firewall Configuration**: Basic Windows Firewall enabled
- **AD Security**: Default domain security policies applied

### Recommendations for Production Adaptation
- Change all default passwords and credentials
- Implement proper certificate management
- Apply security baselines and hardening
- Configure proper network segmentation
- Enable comprehensive logging and monitoring

This lab infrastructure provides a complete, realistic environment for learning and testing DSC concepts while maintaining isolation from production systems.
