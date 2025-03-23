# Using the DSC Workshop with Azure Machine Configuration

The DscWorkshop was designed to manage on-premises machines with DSC using push or pull. The 'pull server as a service' in Azure is [Azure Automation State Configuration](https://learn.microsoft.com/en-us/azure/automation/automation-dsc-overview). There were some discussions about [deprecating](https://learn.microsoft.com/en-us/answers/questions/2182851/azure-automation-state-configuration-deprecation) this service but it is still alive for a while. The replacement for Azure Automation State Configuration is [Azure Machine Configuration](https://learn.microsoft.com/en-us/azure/governance/machine-configuration/overview).

This guide shows how the DscWorkshop template can be used to control machines using Azure Machine Configuration and Azure Policy.

> Note: To get familiar with the template, it is recommended to go though the [Exercises](/Exercises/) first.


Create a project in Azure DevOps.

Import from `https://github.com/dsccommunity/DscWorkshop.git` into the new empty repository.

Create the default pipeline [azure-pipelines.yml](/azure-pipelines.yml) (Without it you cannot create the one we need via the web UI).

Create the pipeline [azure-pipelines Guest Configuration.yml](/azure-pipelines%20Guest%20Configuration.yml).

- Create a service connection
- Go to the Azure DevOps project settings
- Then create a Service connections
  - Create one of type `Azure Resource Manager`.
  - Connect to your subscription
  - Do not select a resource group
  - Name the connection `GC1`
  - Check the box `Grant access permission to all pipelines`
  Creating the service connection creates an app registration in the connected subscription with a name like this: `<DevOpsOrgName>-<DevOpsProjectName>-<GUID>`

- In the Azure portal go to you Azure subscription
- There in IAM, add the service principal `<DevOpsOrgName>-<DevOpsProjectName>-<GUID>` to the administrative role `Resource Policy Contributor`.
- 
