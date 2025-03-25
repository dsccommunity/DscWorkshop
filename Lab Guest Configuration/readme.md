# Azure Guest Configuration Lab for DSC Workshop

## Overview

This guide helps you set up and use the DSC Workshop template with **Azure Guest Configuration** (formerly known as Azure Machine Configuration), which is the modern replacement for Azure Automation State Configuration.

The lab scripts in this folder demonstrate how to:

- Set up a test environment for Azure Guest Configuration
- Deploy configurations
- Monitor compliance
- Automate the entire process through Azure DevOps

> **Note:** It's recommended to complete the [main DSC Workshop exercises](/Exercises/) first to understand the core concepts before working with Guest Configuration.

## What is Azure Guest Configuration?

Azure Guest Configuration is a service that allows you to audit or configure settings inside machines, both for VMs and physical computers. It works by:

1. Using the Guest Configuration extension on Azure VMs
2. Leveraging DSC resources to validate or apply configurations
3. Reporting compliance through Azure Policy

Unlike traditional DSC which uses push or pull methods, Guest Configuration integrates with Azure Policy to provide compliance reporting at scale.

## Lab Scripts

This folder contains the following scripts to help you get started:

| Script | Purpose |
|--------|---------|
| [10 Azure Guest Configuration Lab.ps1](10%20Azure%20Guest%20Configuration%20Lab.ps1) | Creates the test environment for Guest Configuration |
| [20 Azure Guest Configuration Lab Customizations.ps1](20%20Azure%20Guest%20Configuration%20Lab%20Customizations.ps1) | Customizes the lab environment |
| [99 Get-MachineComplianceState.ps1](99%20Get-MachineComplianceState.ps1) | Helper script to check configuration compliance status |

## Setup Instructions

### Prerequisites

- An Azure subscription with permissions to create resources and assign policies
- PowerShell 5.1 or higher with Az modules installed
- Git client installed
- Azure DevOps organization

### Required Step 1: Create Azure DevOps Project and Import Repository

First, you need to create a project in Azure DevOps and import the DscWorkshop template:

1. Create a new project in Azure DevOps
2. Import the template repository:
   - In Azure DevOps, select **Repos** > **Import**
   - Enter `https://github.com/dsccommunity/DscWorkshop.git` as the source
   - Complete the import process

This step is mandatory as you'll need to make changes to the repository for your specific environment.

### Required Step 2: Clone Your Azure DevOps Repository

After importing the repository to your Azure DevOps project, clone it to your local environment:

```powershell
# Clone the repository to the correct location
# IMPORTANT: The repository must be cloned to c:\DscWorkshop for the build scripts to work properly
# Replace the URL with your Azure DevOps repository URL
git clone https://dev.azure.com/YourOrg/YourProject/_git/DscWorkshop c:\DscWorkshop
cd c:\DscWorkshop
```

This step is mandatory as all subsequent steps require the source code to be available locally at the specific path `c:\DscWorkshop`.

### Required Step 3: Resolve Dependencies

After cloning the repository, you must resolve all dependencies before proceeding:

```powershell
# This is CRITICAL before running any other tasks
.\build.ps1 -ResolveDependency -Tasks noop
```

> **Important**: The `-ResolveDependency` switch is essential as it bootstraps the environment by installing all required modules and dependencies. Without running this first, the scripts will fail due to missing dependencies. This switch ensures that modules like PSDepend, PowerShellGet, and all module dependencies defined in RequiredModules.psd1 are properly installed.

### Required Step 4: Configure Azure DevOps Pipeline

1. Create the default pipeline first (required for web UI pipeline creation):

   - In your project, navigate to **Pipelines** > **Create Pipeline**
   - Select **Azure Repos Git** as the source
   - Select your repository
   - Choose **Existing Azure Pipelines YAML file**
   - Select `/azure-pipelines.yml` and create the pipeline

2. Create the Guest Configuration specific pipeline:

   - Follow the same steps but select `/azure-pipelines Guest Configuration.yml`
   - This pipeline is specifically designed to work with Guest Configuration

### Required Step 5: Set Up Service Connection

1. Go to your Azure DevOps project settings
2. Navigate to **Service connections** under **Pipelines**
3. Create a new service connection of type **Azure Resource Manager**
4. Connect to your subscription with the following settings:
   - Connection type: **Service principal (automatic)**
   - Authentication method: **Service principal authentication**
   - Scope level: **Subscription**
   - Do not select a resource group
   - Name the connection **GC1**
   - Check **Grant access permission to all pipelines**

### Required Step 6: Configure Azure Permissions

The service connection creates an app registration in Azure with a name like:
`<DevOpsOrgName>-<DevOpsProjectName>-<GUID>`

1. In the Azure portal, go to your subscription
2. Navigate to **Access control (IAM)**
3. Add a role assignment with the following settings:
   - Role: **Resource Policy Contributor**
   - Assign access to: **User, group, or service principal**
   - Select: *Find the service principal created above*

## Creating and Running the Lab

### Step 1: Connect to Azure and Select Subscription

Before running the lab creation scripts, you need to connect to Azure and select the appropriate subscription:

```powershell
# Connect to your Azure account
Connect-AzAccount

# If you have multiple subscriptions, list them
Get-AzSubscription

# Select the subscription you want to use
Select-AzSubscription -SubscriptionName "Your Subscription Name" 
# OR use subscription ID
# Select-AzSubscription -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Step 2: Run the Lab Creation Scripts

Once connected to Azure and dependencies are resolved, you can create the lab environment:

```powershell
# Navigate to the Lab Guest Configuration folder
cd "Lab Guest Configuration"

# Run the environment setup script
& '.\10 Azure Guest Configuration Lab.ps1'
& '.\20 Azure Guest Configuration Lab Customizations.ps1'
```

### Step 3: Creating and Deploying Configurations

Guest Configuration packages are built from DSC configurations. Here's a simple example:

```powershell
# Example: Create a simple Guest Configuration package
$policy = New-GuestConfigurationPolicy -ContentUri "https://storageaccount.blob.core.windows.net/policies/WindowsFeatureConfig.zip" `
    -DisplayName "Windows features policy" `
    -Description "Ensures required Windows features are installed" `
    -Path ".\output" `
    -Platform "Windows"

# Deploy the policy definition
$definition = New-AzPolicyDefinition -Name 'WindowsFeaturesPolicy' `
    -Policy $policy.PolicyDefinition
```

### Step 4: Checking Compliance Status

You can check the compliance status of your machines using:

```powershell
# Run the helper script to check compliance
.\99 Get-MachineComplianceState.ps1
```

## Pipeline Structure

The `azure-pipelines Guest Configuration.yml` pipeline includes:

1. **Build Stage**: Compiles DSC configurations into Guest Configuration packages
2. **Test Stage**: Validates the packages
3. **Release Stage**:
   - Publishes the packages to storage
   - Creates Azure Policy definitions
   - Creates Policy assignments to target resources
   - Sets up remediation tasks for non-compliant resources

This comprehensive pipeline provides an end-to-end automation solution - from building DSC configurations to deploying and enforcing them via Azure Policy, requiring minimal manual intervention to get started.

## Additional Resources

- [Azure Guest Configuration Documentation](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/overview)
- [Guest Configuration Community Resources](https://github.com/Azure/GuestConfiguration)
- [Creating Custom Guest Configuration Packages](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/how-to-create-custom-policies)

## Troubleshooting

### Common Issues

1. **Policy Assignment Failures**:
   - Check that the service principal has the correct permissions
   - Verify that the VM has the Guest Configuration extension installed

2. **Configuration Not Applied**:
   - Examine the Guest Configuration agent logs at `C:\ProgramData\GuestConfig\`
   - Check if the configuration package was successfully downloaded

3. **Pipeline Failures**:
   - Ensure your service connection has the proper permissions
   - Check that all required modules are included in your configuration
