# DSC Workshop Overview

Remember to **charge your Laptop** before the Workshop!

**If the build fails, please donwload the latest version of AutomatedLab and pull the repository again**

## Goal:
  - Introduction to the [Release Pipeline Model](https://aka.ms/TRPM) and one possible implementation using DSC
  - Takeaway the code to setup a lab environment at work/home, to learn how to roll your own DSC Pipeline
  - Share our experiences of rolling out DSC at scale in production environments, in highly regulated industries 


## Overview:

1. Introduction
2. [AutomatedLab](https://youtu.be/lrPlRvFR5fA) and Existing Infrastructure
3. The Release [Pipeline](https://gaelcolas.files.wordpress.com/2018/04/samplemodule_pipeline.mp4), and how to apply to your [infrastructure](https://gaelcolas.files.wordpress.com/2018/04/demo_dsc_sol.mp4)
4. Building a trusted release process 
5. Bringing Existing Infrastructure under DSC Control, with [Datum](https://gaelcolas.files.wordpress.com/2018/04/datum_quick.mp4)



## Before you start

The best way (but not mandatory), to follow along, is to get your git and github setup.

### 1. Fork the [AutomatedLab/DscWorkshop](https://github.com/AutomatedLab/DscWorkshop) project 

Once logged in to github, create a fork of the following repository: https://github.com/AutomatedLab/DscWorkshop by clicking on the `FORK` button on the right of the page.

This will create a fork under your name: 
i.e. `https://github.com/<your github handle>/DscWorkshop`

Where you will be able to push your changes.

### 2. Git clone your fork locally

Now that you have it under your name, you can clone **your** fork on your laptop.

In your github page you will have the green button 'Clone or Download' providing the page `https://github.com/<your github handle>/DscWorkshop.git`
```
git clone https://github.com/<your github handle>/DscWorkshop.git
```

### 3. Set up your laptop

You need Git in your Path (You probably guessed already from above), also have a permissive `ExecutionPolicy` set so you can run scripts, and an Internet Access so you can pull from the Gallery.

As an Administrator run the following:
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

Should you want to work with the [AutomatedLab part, pull their dependencies listed here](./1.AutomatedLab.md#prerequisites).

For Building DSC Artefacts and composing your configurations, you should be all set.

------

## How to code along with this Lab

You can one, some, or all of the following:

- Follow with the full Lab, setting up your lab VMs with AutomatedLab. Deploying required services (AD, SQL, TFS...), and allow you to experiment with a typical infrastructure

- Only Play with the DSC Pipeline locally on your machine, creating roles, Nodes, and compiling artefacts.

- Browse the code and ask questions


There will be a few slides to introduce the concepts and share our tips and tricks, loads of Q&A, and you can team up to progress faster!

Make it your own.


## Next Steps

1. [AutomatedLab's DscWorkshop Lab](./1.AutomatedLab.md)
2. [Building DSC Artefacts](./2.Building_DSC_Artefacts.md)
