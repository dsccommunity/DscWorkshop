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
  1. Azure only: ```Install-Module AzureRM -Force```
1. ```New-LabSourcesFolder``` to download and create the proper folder structure
1. Copy your ISOs to the folder ISOs inside ```Get-LabSourcesLocation```
  1. Azure only: ```Login-AzureRmAccount``` and ```Set-AzureRmContext -Subscription "YOUR SUBSCRIPTION NAME"```
  1. ```Save-AzureRmContext -Path "A Path of your choice"```
  1. Azure only: ```New-LabAzureLabSourcesStorage -Location 'West Europe'```
  1. Azure only: Upload your TFS iso with ```Sync-LabAzureLabSources -DoNotSkipOsIsos -Filter *team_foundation*2018*```
  1. Azure Only: Change the subscription path in line 3 of '.\DscWorkshop\03 Full Lab with DSC and TFS Azure.ps1'
1. Execute ```& '.\DscWorkshop\03 Full Lab with DSC and TFS.ps1'``` on Hyper-V or ```& '.\DscWorkshop\03 Full Lab with DSC and TFS Azure.ps1'``` if you prefer to use Azure
1. After 1-2h the lab is fully deployed and you can follow the workshop

### Machines

Name   |   Role | RAM
--- | --- | ---
DSCDC01|Domain Controller | 512MB
DSCSRV01|File Server | 1GB
DSCSRV01|Web Server | 1GB
DSCCASQL01 | Root CA, SQL Server, Lab gateway| 4GB
DSCPULL01 | Pull server (https), ProGet server, TFS build worker | 2GB
DSCTFS01 | Team Foundation Server | 1GB

## Lab 01 - The basics

This lab is our starting point. Imagine a typical infrastructure with a forest and some legacy servers that you need to manage. AutomatedLab creates a basic infrastructure here and deploys a domain controller alongside a new forest.
The machines that will later be managed with DSC are created as plain as possible.

### Lab 01 Machines

Name   |   Role
--- | ---
DSCDC01|Domain Controller
DSCSRV*|Member Server

## Lab 02 - DSC

This lab continues to grow in size. We add a SQL 2017 instance that also acts as the root CA and router for the entire lab. A DSC Pull Server is installed as well, which automatically receives an SSL certifiate through AutomatedLab and will be configured with a SQL backend.

### Lab 02 Machines

Name   |   Role
--- | ---
DSCDC01|Domain Controller
DSCSRV*|Member Server
DSCCASQL01 | Root CA, SQL Server, Lab gateway
DSCPULL01 | Pull server (https)