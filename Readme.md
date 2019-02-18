# DSC Workshop Overview

Build | Status | Last Commit
--- | --- | ---
Develop | [![Build status dev](https://ci.appveyor.com/api/projects/status/9yynk81k3k05nasp/branch/develop?svg=true)](https://ci.appveyor.com/project/automatedlab/DscWorkshop) | [![GitHub last commit](https://img.shields.io/github/last-commit/AutomatedLab/DscWorkshop/dev.svg)](https://github.com/AutomatedLab/DscWorkshop/tree/dev/)
Master | [![Build status](https://ci.appveyor.com/api/projects/status/9yynk81k3k05nasp/branch/master?svg=true)](https://ci.appveyor.com/project/automatedlab/DscWorkshop) | [![GitHub last commit](https://img.shields.io/github/last-commit/AutomatedLab/DscWorkshop/master.svg)](https://github.com/AutomatedLab/DscWorkshop/tree/master/)

[![GitHub issues](https://img.shields.io/github/issues/AutomatedLab/DscWorkshop.svg)](https://github.com/AutomatedLab/DscWorkshop/issues)

Remember to **charge your laptop** before the workshop!

**If the build fails, please download the latest version of AutomatedLab and pull the repository again**

## Goal:
  - Introduce the [Release Pipeline Model](https://aka.ms/TRPM) with one possible implementation using DSC
  - Use the code to setup a lab environment at work/home and learn how to roll your own DSC Pipeline
  - Share our experiences of rolling out DSC in production environments within highly regulated industries 


## Overview:

1. Introduction
2. [AutomatedLab](https://youtu.be/lrPlRvFR5fA) and Existing Infrastructure
3. The Release [Pipeline](https://gaelcolas.files.wordpress.com/2018/04/samplemodule_pipeline.mp4), and how to apply to your [infrastructure](https://gaelcolas.files.wordpress.com/2018/04/demo_dsc_sol.mp4)
4. Building a trusted release process 
5. Bringing Existing Infrastructure under DSC Control, with [Datum](https://gaelcolas.files.wordpress.com/2018/04/datum_quick.mp4)


## Before you start

The best way to follow along is to get your Git and Github setup.

### 1. Fork the [AutomatedLab/DscWorkshop](https://github.com/AutomatedLab/DscWorkshop) project 

Once logged into Github, fork the following repository: https://github.com/AutomatedLab/DscWorkshop by clicking on the `FORK` button on the right of the page.

This will create a fork under your name: 
i.e. `https://github.com/<your github handle>/DscWorkshop`

Where you will be able to push your changes.

### 2. Git clone your fork locally

Now that you have it under your name, you can clone **your** fork onto your laptop.

In your Github page you can use the green button 'Clone or Download' on your forked Github page `https://github.com/<your github handle>/DscWorkshop.git`

Or use the following command in your command line:
```
git clone https://github.com/<your github handle>/DscWorkshop.git
```

### 3. Set up your laptop

You need Git in your path, a permissive `ExecutionPolicy` set so you can run scripts, and internet access so you can pull from the gallery.

Run the following as administrator:
```PowerShell
Set-ExecutionPolicy -ExecutionPolicy Bypass
Install-Module Chocolatey
Install-ChocolateySoftware
Install-ChocolateyPackage git
Install-ChocolateyPackage VisualStudioCode
# Setting up Machine level Path environment variable (for persistence)
[Environment]::SetEnvironmentVariable('Path',($Env:Path + ';' + 'C:\Program Files\Git\bin'),'Machine')
# Setting up Process level variable
[Environment]::SetEnvironmentVariable('Path',($Env:Path + ';' + 'C:\Program Files\Git\bin'),'Process')
```

Should you want to work with the AutomatedLab part, pull their dependencies listed [here](./01%20AutomatedLab.md#prerequisites).

For Building DSC Artefacts and composing your configurations, you should be all set.

------

## How to follow along with this lab

You can do any of the following:

- Follow the lab, setting up your lab VMs with AutomatedLab. Deploying required services (AD, SQL, TFS...) allows you to experiment with the typical infrastructure

- Only play with the DSC Pipeline locally on your machine, creating roles, nodes, and compiling artefacts.

- Browse the code and ask questions


There will be a few slides to introduce concepts, share our tips and tricks, and loads of Q&A, so you can work with others to progress faster!

Make it your own.


## Next Steps

1. [AutomatedLab's DscWorkshop Lab](./01%20AutomatedLab.md)
2. [Building DSC Artefacts](./02%20Building_DSC_Artefacts.md)
