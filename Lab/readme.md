# DSC Workshop Lab Environment

This directory contains scripts to deploy and configure a complete lab environment for the DSC Workshop. The lab environment can be deployed to either Azure or Hyper-V.

## Overview

The lab scripts create a fully functional environment with:

- Domain controller (DSCDC01)
- SQL Server (DSCCASQL01)
- DSC Pull Server with SQL backing (DSCPull01)
- Azure DevOps Server (DSCDO01)
- Hyper-V host for nested virtualization (DSCHost01)
- Multiple target nodes for DSC configuration (DSCFile01-03, DSCWeb01-03)

## Lab Deployment Workflow

The numbered scripts follow a specific sequence for deploying and configuring the lab:

1. **Deploy the base lab** (00, 10)
2. **Customize the environment** (20)
3. **Configure Azure DevOps pipelines** (31, 32)
4. **Add additional features** (33, 40, 50)

## Script Descriptions

### Main Deployment Scripts

| Script | Description |
|--------|-------------|
| [00 Lab Deployment.ps1](00%20Lab%20Deployment.ps1) | Main entry point that determines deployment type (Azure/Hyper-V) and calls all other scripts in sequence |
| [10 Azure Full Lab with DSC and AzureDevOps.ps1](10%20Azure%20Full%20Lab%20with%20DSC%20and%20AzureDevOps.ps1) | Deploys lab to Azure with all required VMs and configurations |
| [10 HyperV Full Lab with DSC and AzureDevOps.ps1](10%20HyperV%20Full%20Lab%20with%20DSC%20and%20AzureDevOps.ps1) | Deploys lab to local Hyper-V with all required VMs and configurations |

### Environment Customization Scripts

| Script | Description |
|--------|-------------|
| [20 Lab Customizations.ps1](20%20Lab%20Customizations.ps1) | Performs post-deployment customizations, including installing required modules and software |
| [20 SoftwarePackages.psd1](20%20SoftwarePackages.psd1) | Configuration data for software packages to be installed in the lab |

### Pipeline Configuration Scripts

| Script | Description |
|--------|-------------|
| [31 New Release Pipeline DscConfig.Demo.ps1](31%20New%20Release%20Pipeline%20DscConfig.Demo.ps1) | Creates Azure DevOps release pipeline for the DscConfig.Demo project |
| [32 New Release Pipeline DscWorkshop.ps1](32%20New%20Release%20Pipeline%20DscWorkshop.ps1) | Creates Azure DevOps release pipeline for the main DscWorkshop project |

### Additional Feature Scripts

| Script | Description |
|--------|-------------|
| [33 Install DscAutoOnboarding.ps1](33%20Install%20DscAutoOnboarding.ps1) | Installs and configures the DSC auto-onboarding feature |
| [40 SQL Server Reporting DB.ps1](40%20SQL%20Server%20Reporting%20DB.ps1) | Sets up SQL Server Reporting Services with DSC reports |
| [50 HyperV Host.ps1](50%20HyperV%20Host.ps1) | Configures the Hyper-V host for nested virtualization |

## How to Use the Lab

### Prerequisites

- PowerShell 5.1 or higher
- [AutomatedLab](https://github.com/AutomatedLab/AutomatedLab) module installed
- For Azure deployment: Azure subscription and appropriate permissions
- For Hyper-V deployment: Windows 10/11 or Windows Server with Hyper-V role installed

### Deploying the Lab

#### Option 1: Full Deployment (Recommended)

```powershell
# Clone the repository
git clone https://github.com/dsccommunity/DscWorkshop.git
cd DscWorkshop/Lab

# Deploy to Azure
.\00 Lab Deployment.ps1 -HostType Azure

# OR deploy to Hyper-V
.\00 Lab Deployment.ps1 -HostType HyperV
```

This will execute all scripts in the correct order, creating a complete lab environment.

#### Option 2: Selective Deployment

If you need to run specific parts of the deployment:

```powershell
# First import the lab if it exists but is not imported
Import-Lab -Name DscWorkshop -NoValidation

# Then run individual scripts as needed
.\20 Lab Customizations.ps1
.\31 New Release Pipeline DscConfig.Demo.ps1
```

### Lab Structure

After deployment, you'll have the following key machines:

- **DSCDC01**: Domain Controller
- **DSCCASQL01**: SQL Server and Certificate Authority
- **DSCPull01**: DSC Pull Server
- **DSCDO01**: Azure DevOps Server
- **DSCHost01**: Hyper-V Host for nested virtualization
- **DSCFile01-03, DSCWeb01-03**: Target nodes for configuration

```
                                    +------------+
                                    |            |
                                    |   DSCDC01  |
                                    |            |
                                    +------------+
                                           |
                +-----------------------------------------------+
                |              |              |                 |
        +------------+  +------------+  +------------+   +------------+
        |            |  |            |  |            |   |            |
        | DSCCASQL01 |  |  DSCPull01 |  |   DSCDO01  |   |  DSCHost01 |
        |            |  |            |  |            |   |            |
        +------------+  +------------+  +------------+   +------------+
                                                              |
                          +-----------------------------+
                          |             |               |
                   +------------+ +------------+ +------------+
                   |  DSCFile01 | |  DSCWeb01  | |    ...     |
                   |  DSCFile02 | |  DSCWeb02  | |            |
                   |  DSCFile03 | |  DSCWeb03  | |            |
                   +------------+ +------------+ +------------+
```

### Connecting to the Lab

After deployment, you can connect to any VM using:

```powershell
# Get lab VM details
Get-LabVM

# Connect via RDP
Connect-LabVM -ComputerName DSCDO01
```

### Lab Snapshots

During deployment, several VM snapshots are created to allow easy recovery:

1. **AfterInstall**: Created after initial VM deployment
2. **AfterCustomizations**: Created after software installation and customization
3. **AfterPipelines**: Created after Azure DevOps pipeline setup
4. **AfterSqlReporting**: Created after SQL reporting setup

To restore to a specific point:

```powershell
# List available snapshots
Get-LabVMSnapshot -ComputerName DSCDO01

# Restore a specific VM to a snapshot
Restore-LabVMSnapshot -ComputerName DSCDO01 -SnapshotName AfterCustomizations

# Restore all VMs to a snapshot
Restore-LabVMSnapshot -All -SnapshotName AfterInstall
```

## Additional Components

### DSC Auto-Onboarding

The lab includes scripts for automated DSC node onboarding:

- [DscAutoOnboarding/Install-DscAutoOnboarding.ps1](DscAutoOnboarding/Install-DscAutoOnboarding.ps1): Sets up the auto-onboarding environment
- [DscAutoOnboarding/Start-DscAutoOnboarding.ps1](DscAutoOnboarding/Start-DscAutoOnboarding.ps1): Script to run on target nodes for auto-onboarding

### DSC Reporting

The lab includes SQL Server Reporting Services (SSRS) reports for DSC:

- [Reports/NodeAdditionalInfo.rdl](Reports/NodeAdditionalInfo.rdl)
- [Reports/NodeConfigurationData.rdl](Reports/NodeConfigurationData.rdl)
- [Reports/NodeMetaData.rdl](Reports/NodeMetaData.rdl)
- [Reports/NodeStatusOverview.rdl](Reports/NodeStatusOverview.rdl)

To access reports, you can use the shortcut created on the DSCDO01 desktop or navigate to: `http://DSCCASQL01/Reports`

### Example: Manual DSC Pull Configuration

If you want to manually configure a node to pull from the DSC Pull Server:

```powershell
# On a target node, import required modules
Install-Module -Name xPSDesiredStateConfiguration

# Create a meta config
[DSCLocalConfigurationManager()]
configuration PullClientConfigID
{
    Node localhost
    {
        Settings
        {
            RefreshMode = 'Pull'
            ConfigurationMode = 'ApplyAndMonitor'
            RefreshFrequencyMins = 30
            RebootNodeIfNeeded = $true
        }
        
        ConfigurationRepositoryWeb PullServer
        {
            ServerURL = 'https://DSCPull01.contoso.com:8080/PSDSCPullServer.svc'
            RegistrationKey = '42b8f0eb-07da-4a45-a3f7-d35cf4feb268'
            AllowUnsecureConnection = $false
        }
    }
}

# Apply configuration
PullClientConfigID
Set-DscLocalConfigurationManager -Path ./PullClientConfigID -Verbose
```

## Troubleshooting

### Common Issues

1. **Network Connectivity Issues**:
   - Ensure all VMs are running and can communicate with each other
   - Check the network configuration in Azure or Hyper-V

2. **Certificate Errors**:
   - The lab uses a self-signed certificate authority
   - Errors may occur if certificates are not properly distributed

3. **Azure DevOps Access**:
   - Azure DevOps Server is accessible at: `https://DSCDO01:8080/AutomatedLab`
   - Default credentials: `contoso\install` with password `Somepass1`

4. **DSC Pull Server Issues**:
   - Verify the pull server is running: `https://DSCPull01:8080/PSDSCPullServer.svc/`

### Restoring or Rebuilding

If you encounter significant issues, you can:

1. Restore to a snapshot (see Lab Snapshots section)
2. Remove the lab and redeploy:

```powershell
Remove-Lab -Name DscWorkshop -Confirm:$false
.\00 Lab Deployment.ps1 -HostType HyperV
```

## Additional Resources

- [DSC Workshop Exercises](/Exercises/)
- [AutomatedLab Documentation](https://automatedlab.org/en/latest/)
- [PowerShell DSC Documentation](https://learn.microsoft.com/en-us/powershell/dsc/overview)
- [Azure DevOps Documentation](https://learn.microsoft.com/en-us/azure/devops/?view=azure-devops)
