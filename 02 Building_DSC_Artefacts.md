# Infrastructure Pipeline

This part of the workshop tries to solve (or highlight) different problems usually found in production environments.

1. The [Release Pipeline Model](https://www.youtube.com/watch?v=6mFk3Oxdiwc)

2. The [DSC Configuration Data Problem](https://gaelcolas.com/2018/01/29/the-dsc-configuration-data-problem/)

2. [Composing Roles and Configurations](https://gaelcolas.com/2018/02/07/composing-dsc-roles/), DRY (Don't repeat Yourself)

3. [Splatting DSC Resources](https://gaelcolas.com/2017/11/05/pseudo-splatting-dsc-resources/)


## Composing Roles and Configurations

### First Step

Make sure that **git is in your path**, your **execution policy set** to allow running powershell scripts, and you have an **Internet connection**.
```PowerShell
# Setting up Machine level Path environment variable (for persistence)
C:\> [Environment]::SetEnvironmentVariable('Path',($Env:Path + ';' + 'C:\Program Files\Git\bin'),'Machine')
# Setting up Process level variable
C:\> [Environment]::SetEnvironmentVariable('Path',($Env:Path + ';' + 'C:\Program Files\Git\bin'),'Process')
C:\> Set-ExecutionPolicy -ExecutionPolicy Bypass
```

The first step to kick off a build of the DSC Artefacts is to run this command:

```PowerShell
C:\> Build.ps1 -ResolveDependency
```

This will pull all the dependencies from the PowerShell Gallery and save them in your project (but not in the `git` repository).

This will take some time, but when working on your workstation you don't need to pull everytime (only when you change one of the PSDepend definition files).

You can compare this build to the latest from AppVeyor: https://ci.appveyor.com/project/AutomatedLab/dscworkshop/

### Pulling Dependencies from PSGallery

Have a look at what is pulled from those files:
- [Modules used during the Build process](./DSC//PSDepend.build.psd1)
- [Modules containing the DSC Configurations (DSC Composite Resource)](./DSC/PSDepend.DscConfigurations.psd1)
- [Modules containing the DSC Resources](./DSC/PSDepend.DscResources.psd1)

> Note that for this workshop, we have added to git some files directly under the `DscConfigurations` folder, but that's not a best practice.
> In this `control repository`, you only want to manage trusted artefacts (built in their own pipelines) instead of directly using module sources as we're doing for this demo.

If you are using the full AutomatedLab demo, you can change those PSD1s to use the private repository:
- Register DSCPull01.contoso.com on port 8624 as a the `Internal` PSRepository on the Build Server
- Edit the PSDepend files to add the **Parameter** block and set the `Repository = 'internal'` ([within PSDepend options](https://github.com/gaelcolas/SampleModule/blob/master/PSDepend.build.psd1))

### Building the Artefacts

The DSC Artefacts are built within the [BuildOutput](./DSC/BuildOutput) folder inside of your repository. This folder will be created once the build has been executed.

You will mainly be interested in the following folders:
- DscModules: The Modules containing the resources, zipped for a DSC Pull server
- MetaMOF
- MOF

### Going further

Now that you've built the provided infrastructure, you can try to understand how it works. :)

Have a look at the links provided above for reference, ask questions, and try the following (in no particular order).

- Create a New node based on an existing Role (& compile)
- Create a new Role and assign a node to that role (& compile)
- Make some changes to existing roles in the Data, (& commit + (& compile)
- Make a diff of the RSOP (Resultant Set of Policy to see the difference between different commits for a given node)
- Add a layer to your hierarchy (i.e. Environment), and create some Override for that layer
- Create a custom Configuration (DSC Composite Resource), and add it to a few roles (use the 'splatting' technique)
- Add credential or encrypted data to the configuration Data
- Find out what a Datum Handler can do for you!

Feel free to look at the [Datum](https://github.com/gaelcolas/Datum) documentation, and to submit issues and Pull requests.