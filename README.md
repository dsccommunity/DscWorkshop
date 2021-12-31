# DSC Workshop Overview

Build | Status | Last Commit
--- | --- | ---
Develop | [![Build status dev](https://ci.appveyor.com/api/projects/status/9yynk81k3k05nasp/branch/develop?svg=true)](https://ci.appveyor.com/project/automatedlab/DscWorkshop) | [![GitHub last commit](https://img.shields.io/github/last-commit/AutomatedLab/DscWorkshop/dev.svg)](https://github.com/AutomatedLab/DscWorkshop/tree/dev/)
Master | [![Build status](https://ci.appveyor.com/api/projects/status/9yynk81k3k05nasp/branch/master?svg=true)](https://ci.appveyor.com/project/automatedlab/DscWorkshop) | [![GitHub last commit](https://img.shields.io/github/last-commit/AutomatedLab/DscWorkshop/master.svg)](https://github.com/AutomatedLab/DscWorkshop/tree/master/)

[![GitHub issues](https://img.shields.io/github/issues/AutomatedLab/DscWorkshop.svg)](https://github.com/AutomatedLab/DscWorkshop/issues)

## Abstract

This project serves as a blueprint for projects utilizing [DSC](https://docs.microsoft.com/en-us/powershell/scripting/dsc/overview/overview?view=powershell-7) in a medium or complex scope. It comes with a single build script to create all DSC artifacts for push or pull scenarios with the most flexible and scalable solution to manage [configuration data](https://docs.microsoft.com/en-us/powershell/scripting/dsc/configurations/configData?view=powershell-7).

This project does not use DSC as an isolated technology. DSC is just one part in a pipeline that leverages a few Microsoft products and open-source.

The is a fast-track learning path in [Exercises](./Exercises)

### Credits
This project is inspired by [Gael Colas'](https://twitter.com/gaelcolas) [DscInfraSample](https://github.com/gaelcolas/DscInfraSample) and Gael's opinions have an impact on its evolution.

The overall concept follows [The Release Pipeline Model](https://aka.ms/trpm), a whitepaper written by [Michael Greene](https://twitter.com/migreene) and [Steven Murawski](https://twitter.com/StevenMurawski) that is a must-read and describing itself like this:

> There are benefits to be gained when patterns and practices from developer techniques are applied to operations. Notably, a fully automated solution where infrastructure is managed as code and all changes are automatically validated before reaching production. This is a process shift that is recognized among industry innovators. For organizations already leveraging these processes, it should be clear how to leverage Microsoft platforms. For organizations that are new to the topic, it should be clear how to bring this process to your environment and what it means to your organizational culture. This document explains the components of a Release Pipeline for configuration as code, the value to operations, and solutions that are used when designing a new Release Pipeline architecture.

## Technical Summary

In the past few years many projects using DSC have not produced the desired output or have even failed. One of the main reasons is the tooling required to automate the process of building the DSC artifacts (MOF, Meta MOF, Compresses Modules) and automated testing is not implemented.

One of the goals of this project is to manage the complexity that comes with DSC. The needs to be proper tooling that solves these issues:

- **Configuration Management** must be flexible and scalable. The DSC documentation is technically correct but does not lead people the right way. If one follows [Using configuration data in DSC](https://docs.microsoft.com/en-us/powershell/scripting/dsc/configurations/configData?view=powershell-7) and [Separating configuration and environment data](https://docs.microsoft.com/en-us/powershell/scripting/dsc/configurations/separatingenvdata?view=powershell-7), the outcome will be unmanageable if the configuration data gets more complex like dealing with roles, differences between locations and / or environments.. The solution to this problem is [Datum](https://github.com/gaelcolas/Datum), which is described in detail in the [Exercises](./Exercises).
- Building the solution and creating the artifacts requires a **Single Build Script**. This get very difficult if the build process has any manual steps or preparations that need to be done. After you have done your changes and want to create new artifacts, running the [Build.ps1 script](./DSC/Build.ps1). This build script runs locally or inside a release pipeline (tested on Azure DevOps, Azure DevOps Sever, AppVeyor, GitLab).
- The lack of **Dependency Resolution** makes it impossible to move a solution from local build to a CI/CD pipeline. Many DSC solutions require downloading a bunch of dependencies prior being able to run the build. This project uses [PSDepend](https://github.com/RamblingCookieMonster/PSDepend/) to download all required resources from either the PowerShell gallery or your internal repository feed.
- **Automated Testing** is essential to verify the integrity of the configuration data. This project uses [Pester](https://pester.dev/) for this. Additionally, the artifacts must be tested in the development as well as the test environment prior deploying them to them to the production environment. This process should be fully automated as well.

## Getting started

Getting into the details does not cost much time and does not require a complex lab infrastructure. You should start with the [Exercises - Task 2](./Exercises/Task2) on your personal computer. If you need to recap some DSC basics, go to [Exercises - Task 1](./Exercises/Task1). Later in the exercises a free [Azure DevOps](https://azure.microsoft.com/en-us/services/devops/) account is needed and to finish the last exercises also an [Azure Automation account](https://docs.microsoft.com/en-us/azure/automation/automation-create-standalone-account) for storing the MOF files.

If you need DSC in an isolated or non-cloud ready environment, all the required components can be installed as a local lab. For that [AutomatedLab](https://automatedlab.org) (AL) is required that handles the deployment of VMs on Azure or Hyper-V. AL also installs all the required software and does the necessary configurations. Deploying the lab takes 3 to 5 hours, is fully automated and includes:

- Active Directory Domain
- SQL Server 2017
- Azure DevOps Server for hosting the code, running the builds and providing NuGet feed to Software (Chocolatey) and PowerShell modules
- 4 to 8 Azure DevOps Build Agents
- DSC Pull Server (SQL Server access already configured)
- Certificate Authority for SSL support and credential encryption
- Routing Services so all VMs can access the internet

The lab script are in [Lab](./Lab).

## Technical Details

- Configuration management that allows multiple layers of data (psd1 files and hash tables can’t be the solution)
- Tooling to fully automated the build and release process
- Dependency resolution
- Maintenance windows (which the LCM does not support)
- Reporting (at least if you are using the on-prem pull server)
- Git branching model
- Automated testing

## YAML Reference Documentation

The [YAML reference documentation](https://github.com/dsccommunity/CommonTasks/blob/dev/doc/README.adoc) is located in the ./doc subfolder of the [CommonTasks](https://github.com/dsccommunity/CommonTasks) repository.
