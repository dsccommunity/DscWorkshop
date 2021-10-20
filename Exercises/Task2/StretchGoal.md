# Task 2 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script 'Build.ps1' is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](../CheckPrereq.ps1)!***

---

## 2.5 - Create a custom Configuration (DSC Composite Resource)

***This is a stretch goal, if the other tasks have been too easy.***

Extending configurations based on the customer's needs will eventually require you to develop actual DSC configurations in the form of composite resources. The guiding principle is that your composite resources should be able to take all their parameters from configuration data.

There should rarely be the need for hard-coded values in your composite resources. Keep in mind though that they should abstract some of the complexity of DSC. A composite resource that requires massive amounts of configuration data is probably not the best choice.

We cannot give you a blueprint that covers all your needs. However, the repository <https://github.com/dsccommunity/commontasks> can serve as a starting point again. The CommonTasks module is our trusted module in the build and release pipeline and collects commonly used DSC composite resources.

At your customer, this is all customer-specific code and should be collected in one or more separate PowerShell modules with their own build and release pipeline. This pipeline is trusted and will always deliver tested and working code to an internal gallery, for example [ProGet](https://inedo.com/proget), [Azure DevOps](https://dev.azure.com) or the free and open-source [NuGet](https://nuget.org).

1. To start we have to clone the repository 'CommonTasks' like we have cloned the 'DscWorkshop' project right at the beginning.

    > Note: Before cloning, please switch to the same directory you cloned the 'DscWorkshop' project into.

    ```powershell
    git clone https://github.com/dsccommunity/commontasks
    ```

    After cloning, please open the 'CommonTasks' repository in VSCode. You may want to open a new VSCode window so you can switch between both projects.

2. This module contains many small DSC composite resources (in this context we call them configurations), that the 'DscWorkshop' project uses. Please open the folder 'CommonTasks\DscResources' and have a look at the composite resources defined there.

    You can get a list of all resources also with this command:

    ```powershell
    Get-ChildItem -Directory -Path  ./CommonTasks/CommonTasks/DSCResources
    ```

3. Now let's add your own composite resource / configuration by adding the following files to the structure:

    > Note: You can choose whatever name you like, but here are some recommendations. PowerShell function, cmdlet and parameter names are always in singular. To prevent conflicts, all the DSC composite resources in 'CommonTasks' are named in plural if they can effect one or multiple objects.

    As we are going to create a composite resource that is configuring disks, you may want to name this resource just 'Disks'.

    ```code
    CommonTasks\
    DscResources\
        Disks\
        Disks.psd1
        Disks.schema.psm1
    ```

    > Note: Some people find it easier to duplicate an existing composite resource and replacing the content in the files. That's up to you.

4. Either copy the module manifest content from another resource or add your own minimal content, describing which DSC resource is exposed:

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

5. Your .psm1 file now should only contain your DSC configuration element, the composite resource. Depending on the DSC resources that you use in this composite, you can make use of Datum's cmdlet ```Get-DscSplattedResource``` or its alias ```x``` to pass parameter values to the resource in a single, beautiful line of code.

    > Note: The ['WindowsServices'](https://github.com/dsccommunity/CommonTasks/blob/master/CommonTasks/DscResources/WindowsServices/WindowsServices.schema.psm1) composite resource in 'CommonTasks' shows the difference of splatting vs. passing the parameters in the classical way. If you want to read more about how PowerShell supports splatting, have a look at [About Splatting](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-6). DSC does not support splatting out-of-the-box, but Datum adds that very usful feature.
   
    The following code uses the 'Disk' resource published in the 'StorageDsc' module to configure disk layouts. The '$DiskLayout' hashtable must have a pattern that matches exactly the parameter pattern defined in the 'StorageDsc\Disk' resource.

    Please put this code into the file 'Disks.schema.psm1'.

    ```powershell
    configuration Disks
    {
        param
        (
            [Parameter(Mandatory)]
            [hashtable[]]
            $DiskLayout
        )

        Import-DscResource -ModuleName StorageDsc

        foreach ($disk in $DiskLayout.GetEnumerator()) {
            (Get-DscSplattedResource -ResourceName Disk -ExecutionName $disk.DiskId -Properties $disk -NoInvoke).Invoke($disk)
        }
    }
    ```

    Great, you have greated the first composite resource that serves as a configuration. But this resource only exists in the 'CommonTasks' project. We want to use it in the 'Dscworkshop' project. In a real-life environment the build pipeline of the 'DscWorkshop' project would pull the 'CommonTasks' module from an interal gallery. In case of this exercise the build pipeline downloads the 'CommonTasks' module from the [PowerShell Gallery](https://www.powershellgallery.com/packages/CommonTasks), which of course doesn't know about the code that you want to add. To skip this step and inject your modified version which has the new 'Disks' resource directory, run the following commands:

    > Note: Please make sure you are in the directory you have cloned the repositories into. If you are not in the right location, these commands will fail.

    ```powershell
    Remove-Item -Path .\DscWorkshop\DSC\DscConfigurations\CommonTasks\ -Recurse -Force

    Copy-Item -Path .\CommonTasks\BuildOutput\Modules\CommonTasks\ -Destination .\DscWorkshop\DSC\DscConfigurations\ -Recurse
    ```
    The folder 'C:\Git\DscWorkshopFork\DSC\DscConfigurations\CommonTasks\DscResources' should now contain your new 'Disks' composite resource.


## 2.6 - Use a custom Configuration (DSC Composite Resource)
1. Let's suppose you want to manage the disk layout of all file servers with DSC. In this case the new config goes into the 'FileServer.yml' file. Please open it. The full path is '\DSC\DscConfigData\Roles\FileServer.yml'.

    At the top of the file you have the configurations mapped to the file server role. Please add the new 'Disks' configuration:

    ```yaml
    Configurations:
    - FilesAndFolders
    - RegistryValues
    - Disks
    ```

    After saving the file, please start a new build using the script 'DSC\Build.ps1'. The build will not fail but wait for further input like this:

    ```code
    DSCFile01 : DSCFile01 : MOF__0.0.0 NA
        DSCFile01 : FileServer ::> FilesAndFolders .....................................................OK
        DSCFile01 : FileServer ::> RegistryValues ......................................................OK
    cmdlet Disks at command pipeline position 1
    Supply values for the following parameters:
    DiskLayout[0]:
    ```

    So why does the build require additional data? Adding the 'Disks' resource to the configurations makes the build script calls it when compiling the MOF files. The resource has a mandatory parameter but no argument for this mandatory parameter is available in the configuration data.

    ```powershell
    param
    (
        [Parameter(Mandatory)]
        [hashtable[]]
        $DiskLayout
    )
    ```

2. So let's add the configuration data so the 'Disks' resource knows what to do. Please add the following section to the file server role:

    ```yaml
    Disks:
      DiskLayout:
        - DiskId: 0
          DiskIdType: Number
          DriveLetter: C
          FSLabel: System
        - DiskId: 1
          DiskIdType: Number
          DriveLetter: D
          FSLabel: Data
    ```

    If the build has finished, examine the MOF files in the 'BuildOutput' folder. You should see the config you have made reflected there.

Congratulations! You have walked through the entire process of making this repository your own! We hope you are successful with this concept - we certainly are.

Please continue with [the next task](../Task3/readme.md) when your are ready.
