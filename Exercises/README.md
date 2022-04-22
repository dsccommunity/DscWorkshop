# Exercises

These small exercises should get you started with this repository and the project. Use these little tasks as a guideline, and be sure to replace settings with your own ones to improve your learning experience.

## Prerequisites

Before starting any exercise, please make sure you have met the following requirements:

- Create a free account on Azure DevOps if you don't have one yet: <https://dev.azure.com/>
- Create a free Azure test account if you don't have one yet with enough credits left: <https://azure.microsoft.com/en-us/free/>. You may want to create a new email address if you already have one and used all your credits already (required to test Azure Automation DSC in a release pipeline)
- Create one or two virtual machines in the test subscription and don’t forget to turn them off. The machine must have the status "deallocated", otherwise they are eating up your credits.
- Have a notebook computer (ideally Windows 10) with you that has the following software installed:
  - [Download Git](https://git-scm.com/downloads)
  - [Download Visual Studio Code](https://code.visualstudio.com/Download)
    - Install the PowerShell extensions
    - Install the RedHat yaml extension
    - Install the Az module (Install-Module -Name Az)
    - Test logging into your free Azure test subscription (Login-AzAccount)

Please execute the [prerequisite check](CheckPrereq.ps1) in Windows PowerShell to check if everything is configured correctly on you computer.

> ***Please note that this test requires Pester > 4 to run.***

## Task 1

Task 1 will get you into the DSC basics. You create a simple configuration, compile MOF file and apply the MOF file to your local machine

Stat at [Task 1, Exercise 1](Task1/Exercise1.md)

## Task 2

Task 2 is all about getting around the build environment step by step. From running a manual build to easily modifying the entire environment without modifying the actual DSC code you can experience everything.  

Start at [Task 2, Exercise 1](Task2/Exercise1.md)

## Task 3

Task 2 will get you going with your release pipeline on Azure DevOps and Azure DevOps Server. While this task is specific to Microsoft products like TFS/VSTS or Azure DevOps, the same principle applies to any CI system that lets you define build and release tasks like AppVeyor, TravisCI, Jenkins, ...  

Start at [Task 3, Exercise 1](Task3/Exercise1.md)
