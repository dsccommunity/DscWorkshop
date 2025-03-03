# Task 2 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script `build.ps1` is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](../CheckPrereq.ps1)!***

---

## 2.5 - Create a custom Configuration (DSC Composite Resource)

***This is a stretch goal, if the other tasks have been too easy.***

Extending configurations based on the customer's needs will eventually require you to develop actual DSC configurations in the form of composite resources. The guiding principle is that your composite resources should be able to take all their parameters from configuration data.

There should rarely be the need for hard-coded values in your composite resources. Keep in mind though that they should abstract some of the complexity of DSC. A composite resource that requires massive amounts of configuration data is probably not the best choice.

We cannot give you a blueprint that covers all your needs. However, the repository [DscConfig.Demo](https://github.com/raandree/DscConfig.Demo) can serve as a starting point again. The `DscConfig.Demo` module is our trusted module in the build and release pipeline and collects commonly used DSC composite resources.

> Note: The DSC composite resource module [CommonTasks](https://github.com/dsccommunity/CommonTasks) has a much bigger choice of configurations (composite resources). To reduce the complexity of the `DscWorkshop` blueprint and these exercises and reduce the build time, we have created the [DscConfig.Demo](https://github.com/raandree/DscConfig.Demo) module which comes only with a small subset of the available configurations. If you want to start using the `DscWorkshop` in production, have a look at the abundance of available configurations in [CommonTasks](https://github.com/dsccommunity/CommonTasks).

At your customer, this is all customer-specific code and should be collected in one or more separate PowerShell modules with their own build and release pipeline. This pipeline is trusted and will always deliver tested and working code to an internal gallery, for example [ProGet](https://inedo.com/proget), [Azure DevOps](https://dev.azure.com) or the free and open-source [NuGet](https://nuget.org).

1. To start we have to clone the repository `DscConfig.Demo` like we have cloned the `DscWorkshop` project right at the beginning.

    > Note: Before cloning, please switch to the same directory you cloned the `DscWorkshop` project into.

    ```powershell
    git clone https://github.com/raandree/DscConfig.Demo.git
    ```

    After cloning, please open the `DscConfig.Demo` repository in VSCode. You may want to open a new VSCode window so you can switch between both projects.

1. This module contains some small DSC composite resources (in this context we call them configurations), that the `DscWorkshop` project uses. Please open the folder `source\DscResources` and have a look at the composite resources defined there.

    You can get a list of all resources also with this command:

    ```powershell
    Get-ChildItem -Directory -Path .\source\DSCResources\
    ```

1. Now let's add your own composite resource / configuration by adding the following files to the structure:

    > Note: You can choose whatever name you like, but here are some recommendations. PowerShell function, cmdlet and parameter names are always in singular. To prevent conflicts, all the DSC composite resources in [DscConfig.Demo](https://github.com/raandree/DscConfig.Demo) are named in plural if they can effect one or multiple objects. The naming convention in PowerShell is naming cmdlets always in singular.

    As we are going to create a composite resource that is configuring disks, you may want to name this resource just `Disks`.

    ```code
    source\
        DscResources\
            Disks\
            Disks.psd1
            Disks.schema.psm1
    ```

    > Note: Some people find it easier to duplicate an existing composite resource and replacing the content in the files. That's up to you.

1. Either copy the module manifest content from another resource or add your own minimal content, describing which DSC resource is exposed:

    ```powershell
    @{
        RootModule           = 'Disks.schema.psm1'
        ModuleVersion        = '0.0.1'
        GUID                 = '27238df7-8c89-4acf-8eef-80750b964380'
        Author               = 'NA'
        CompanyName          = 'NA'
        Copyright            = 'NA'
        DscResourcesToExport = @('Disks')
    }
    ```

1. Your `.psm1` file now should only contain your DSC configuration element, the composite resource. Depending on the DSC resources that you use in this composite, you can make use of Datum's cmdlet `Get-DscSplattedResource` or its alias `x` to pass parameter values to the resource in a single, beautiful line of code.

    ### Splatting

    Let's make a little detour and talk about splatting. Why is splatting so helpful? To learn more about splatting, have a look at Kevin Marquette's excellent article [Powershell: Everything you wanted to know about hashtables](https://powershellexplained.com/2016-11-06-powershell-hashtable-everything-you-wanted-to-know-about/#splatting-hashtables-at-cmdlets). DSC does not support splatting out-of-the-box. The cmdlet `Get-DscSplattedResource` adds this long missing feature.

    If there is no splatting available, we need to assign each parameter-argument pair by ourselves. This can result in massive code blocks. For the configuration [WindowsServices](https://github.com/raandree/DscConfig.Demo/tree/main/source/DSCResources/WindowsServices) the code would look like this:

    ```powershell
    Service $Service.Name {
            Name        = $service.Name
            Ensure      = 'Present'
            Credential  = $service.Credential
            DisplayName = $service.DisplayName
            StartupType = $service.StartupType
            State       = 'Running'
            Path        = $service.Path
    }
    ```

    This is still manageable, but there are resources with 50+ parameter and then things get boring and error-prone.

    Splatting by means of `Get-DscSplattedResource` makes this code look much nicer:

    ```powershell
    Get-DscSplattedResource -ResourceName Service -ExecutionName $service.Name -Properties $service -NoInvoke).Invoke($service)
    ```

    With splatting we don't care how many parameter-argument pairs need to be matched. `Get-DscSplattedResource` does all the work.

    ---

    Going back to the task of creating a new configuration: The following code uses the `Disk` resource published in the [StorageDsc](https://github.com/dsccommunity/StorageDsc) module to configure disk layouts. The `$DiskLayout` hashtable must have a pattern that matches exactly the parameter pattern defined in the `StorageDsc\Disk` resource.

    Please put this code into the file `Disks.schema.psm1`.

    ```powershell
    configuration Disks
    {
        param (
            [Parameter(Mandatory = $true)]
            [hashtable[]]
            $Disks
        )

        Import-DscResource -ModuleName PSDesiredStateConfiguration
        Import-DscResource -ModuleName StorageDsc

        foreach ($disk in $Disks)
        {
            # convert string with KB/MB/GB into Uint64
            if ($null -ne $disk.Size)
            {
                $disk.Size = [Uint64] ($disk.Size / 1)
            }

            # convert string with KB/MB/GB into Uint32
            if ($null -ne $disk.AllocationUnitSize)
            {
                $disk.AllocationUnitSize = [Uint32] ($disk.AllocationUnitSize / 1)
            }

            $executionName = $disk.DiskId
            (Get-DscSplattedResource -ResourceName Disk -ExecutionName $executionName -Properties $disk -NoInvoke).Invoke($disk)
        }
    }
    ```

1. After having added the new DSC composite resource, you need to build the solution. This works the same way like in the `DscWorkshop` repository. Just go in the project's directory (which should be `C:\Git\DscConfig.Demo`) and run the build script:

    ```powershell
    Set-Location -Path C:\Git\DscConfig.Demo
    .\Build.ps1
    ```

    The build will create the module but will fail, as there is no test data yet for the `Disks` configuration that you have created. But this is not an issue for now.

    Great, you have created the first composite resource that serves as a configuration. But this resource only exists in the `DscConfig.Demo` project. We want to use it in the `DscWorkshop` project. In a real-life environment the build pipeline of the `DscWorkshop` project would pull the `DscConfig.Demo` module from an internal gallery. In case of this exercise the build pipeline downloads the `DscConfig.Demo` module from the [PowerShell Gallery](https://www.powershellgallery.com/packages/DscConfig.Demo), which of course doesn't know about the code that you have just added. To skip this step and inject your modified version which has the new `Disks` resource directory, run the following commands:

    > **Note: Please make sure you are in the directory you have cloned the repositories into. If you are not in the right location, these commands will fail. If you have followed the exercises it should be `C:\Git`.**

    ```powershell
    Remove-Item -Path .\DscWorkshop\output\RequiredModules\DscConfig.Demo\ -Recurse -Force

    Copy-Item -Path .\DscConfig.Demo\output\Module\DscConfig.Demo\ -Destination .\DscWorkshop\output\RequiredModules\ -Recurse
    ```

    The folder `C:\Git\DscWorkshop\output\RequiredModules\DscConfig.Demo\DscResources` should now contain your new `Disks` composite resource.

## 2.6 - Use a custom Configuration (DSC Composite Resource)

1. Let's suppose you want to manage the disk layout of all file servers with DSC. In this case the new config goes into the `FileServer.yml` file. Please open it. The full path is `\source\Roles\FileServer.yml`.

    At the top of the file you have the configurations mapped to the file server role. Please add the new `Disks` configuration:

    ```yaml
    Configurations:
    - FilesAndFolders
    - RegistryValues
    - Disks
    ```

    After saving the file, please start a new build using the script `build.ps1`. The build will fail because a Pester tests has discovered that the DSC resource module `StorageDsc` is missing.

    ```
    [-] DSC Resource Module 'StorageDsc' is defined in 'RequiredModules.psd1' 24ms (20ms|4ms)
    at $VersionInPSDependFile | Should -Not -BeNullOrEmpty, E:\Git\DscWorkshop\tests\ConfigData\CompositeResources.Tests.ps1:90
    at <ScriptBlock>, E:\Git\DscWorkshop\tests\ConfigData\CompositeResources.Tests.ps1:90
    Expected a value, but got $null or empty.
    ```

    Please add the following line to the file `.\RequiredModules.psd1`

    ```yaml
    StorageDsc = '5.0.1'
    ```

    Then start the build again and tell the build script via the `ResolveDependency` switch to download the dependencies again.

    ```powershell
    .\build.ps1 -ResolveDependency
    ```

    > Note: This may take a while, good time to grab a coffee.

1. The build should not fail this time but waits for further input. This is what you should see on the console:

    ```code
    Did not find 'RootConfiguration.ps1' and 'CompileRootConfiguration.ps1' in 'source', using the ones in 'Sampler.DscPipeline'
    RootConfiguration will import these composite resource modules as defined in 'build.yaml':
            - PSDesiredStateConfiguration
            - DscConfig.Demo


    ---------------------------------------------------------------------------
    DSCFile02 : DSCFile02 : MOF__ NA
        DSCFile02 : FileServer ::> FilesAndFolders .....................................................OK
        DSCFile02 : FileServer ::> RegistryValues ......................................................OK
    cmdlet Disks at command pipeline position 1
    Supply values for the following parameters:
    Disks[0]: 
    ```

    So why does the build require additional data? Adding the `Disks` resource to the configurations makes the build script calls it when compiling the MOF files. The resource has a mandatory parameter but no argument for this mandatory parameter is available in the configuration data.

    ```powershell
    param
    (
        [Parameter(Mandatory)]
        [hashtable[]]
        $DiskLayout
    )
    ```

1. So let's add the configuration data so the 'Disks' resource knows what to do. Please add the following section to the file server role:

    ```yaml
    Disks:
      Disks:
        - DiskId: 0
          DiskIdType: Number
          DriveLetter: C
          FSLabel: System
        - DiskId: 1
          DiskIdType: Number
          DriveLetter: D
          FSLabel: Data
    ```

    If the build has finished, examine the MOF files in the `output` folder. You should see the config you have made reflected there.

Congratulations! You have walked through the entire process of making this repository your own! We hope you are successful with this concept - we certainly are.

Please continue with [the next task](../Task3/readme.md) when your are ready.
