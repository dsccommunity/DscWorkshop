# PSConf EU 2018 - Lab Deployment Guide

The following guide explains how to setup the full lab environment containing a DSC Pull Server, SQL server as well as Team Foundation Server. 
You have two options to follow along:
- Use Hyper-V locally or Azure  
Best experience if you want to follow along with the entire lab
- ```git clone https://github.com/AutomatedLab/DscWorkshop```  
If you cannot use Azure and don't have the power to run the entire lab

## DSC with TFS

The full lab contains everything featured in Labs 01 and 02, which are not part of this workshop but can be used to test on your own. Additionally, it contains a TFS 2018 instance that powers our release pipeline as well as ProGet as the provider of a nuget feed.

### Prerequisites

- Generic
  - AutomatedLab PowerShell module (```Install-Module AutomatedLab -AllowClobber -Force```)  
  See also our [Training Video](<https://youtu.be/lrPlRvFR5fA>)
  - Permissions to open an elevated shell
  - git.exe in your ```$env:PATH``` (<https://git-scm.com>)
- On-premises
  - Hyper-V feature and Hyper-V PowerShell enabled
  - [Windows Server 2016 Evalutaion ISO (en_us)](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2016)
  - [Team Foundation Server 2018 Update 2 RC1 ISO (en_us)](https://www.visualstudio.com/downloads/)
  - [SQL Server 2017 Evalutation ISO (en_us)](https://www.microsoft.com/en-us/evalcenter/evaluate-sql-server-2017-rtm) - the exe is required to download the ISO.
  - 10GiB RAM for the lab VMs
  - At least 20GiB SSD storage for the lab VMs
- Azure
  - Azure PowerShell (```Install-Module AzureRM -Force```)
  - Azure subscription that can spin up 6 VMs with 2 cores each
  - Someone who pays

### Deployment

Follow these simple steps to create your own lab infrastructure for the workshop

1. Open Windows PowerShell, the ISE or VSCode as administrator
1. Create a new directory to contain the code and move there
1. Call ```git clone https://github.com/AutomatedLab/DscWorkshop``` inside the folder from step 2
1. ```Install-Module AutomatedLab -AllowClobber -Force```
  1. Azure only: ```Install-Module Az -Force```
1. ```New-LabSourcesFolder``` to download and create the proper folder structure
1. Copy your ISOs to the folder ISOs inside ```Get-LabSourcesLocation```
  1. Azure only: ```Connect-AzAccount```
  1. Azure only: ```New-LabAzureLabSourcesStorage -Location 'West Europe'```
  1. Azure only: Upload your TFS iso with ```Sync-LabAzureLabSources -DoNotSkipOsIsos -Filter *team_foundation*2018*```
1. Execute ```& '.\Lab\HyperV\03.10 Full Lab with DSC and TFS'``` on Hyper-V or ```& '.\Lab\Azure\03 Full Lab with DSC and TFS Azure.ps1'``` if you prefer to use Azure
1. After 1-2h the lab is fully deployed and you can follow the workshop

### Machines

Name   |   Role | RAM
--- | --- | ---
DSCDC01|RootDC|0.5GB
DSCCASQL01|CaRoot,SQLServer2017|3GB
DSCPull01|DSCPullServer,TfsBuildWorker,WebServer|2GB
DSCSO01|AzureDevops 2020|4GB
DSCHost01|Hyper-V Host, AzureDevOps Build Worker|8GB
DSCFile01|FileServer|1GB
DSCWeb01|WebServer|1GB
DSCFile02|FileServer|1GB
DSCWeb02|WebServer|1GB
DSCFile03|FileServer|1GB
DSCWeb03|WebServer|1GB
