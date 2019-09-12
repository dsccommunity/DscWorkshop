# Task 1 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script 'Build.ps1' is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](..\CheckPrereq.ps1)!***

---

## 1.5 - Create a custom Configuration (DSC Composite Resource)

***This is a stretch goal, if the other tasks have been too easy.***

Extending configurations based on the customer's needs will eventually require you to develop actual DSC configurations in the form of composite resources. The guiding principle is that your composite resources should be able to take all their parameters from configuration data.

There should rarely be the need for hard-coded values in your composite resources. Keep in mind though that they should abstract some of the complexity of DSC. A composite resource that requires massive amounts of configuration data is probably not the best choice.

We cannot give you a blueprint that covers all your needs. However, the repository <https://github.com/automatedlab/commontasks> can serve as a starting point again. The CommonTasks module is our trusted module in the build and release pipeline and collects commonly used DSC composite resources.

At your customer, this is all customer-specific code and should be collected in one or more separate PowerShell modules with their own build and release pipeline. This pipeline is trusted and will always deliver tested and working code to an internal gallery, for example [ProGet](https://inedo.com/proget), [Azure DevOps](https://dev.azure.com) or the free and open-source [NuGet](https://nuget.org).

1. To start we have to clone the repository 'CommonTasks' like we have cloned the 'DscWorkshop' project right at the beginning.

    > Note: Before cloning, please switch to the same directory you cloned the 'DscWorkshop' project into.

    ```powershell
    git clone https://github.com/automatedlab/commontasks
    ```

    After cloning, please open the 'CommonTasks' repository in VSCode. You may want to open a new VSCode window so you can switch between both projects.

2. This module contains many small DSC composite resources (in this context we call them configurations), that the 'DscWorkshop' project uses. Please open the folder 'CommonTasks\DscResources' and have a look at the composite resources defined there.

    You can get a list of all resources also with this comand:

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

5. Your psm1 file now should only contain your DSC configuration element, the composite resource. Depending on the DSC resources that you use in this composite, you can make use of Datum's cmdlet ```Get-DscSplattedResource``` or its alias ```x``` to pass parameter values to the resource in a single, beautiful line of code.


Remove-Item -Path .\DscWorkshopFork\DSC\DscConfigurations\CommonTasks\ -Recurse -Force

Copy-Item -Path .\CommonTasks\BuildOutput\Modules\CommonTasks\ -Destination .\DscWorkshopFork\DSC\DscConfigurations\ -Recurse

    > Note: If you want to read more about how PowerShell supports splatting, have a look at [About Splatting](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_splatting?view=powershell-6). DSC does not support splatting out-of-the-box, but Datum adds that very usful feature.
   
    The following code uses the 'Disks' resource to configure disk layouts. The parameters can be passed to your resource in the YAML file.

    ```powershell
    configuration Disks
    {
        param
        (
            [Parameter(Mandatory)]
            [hashtable[]]
            $DiskLayout
        )

        Import-DscResource -ModuleName StorageDsc -ModuleVersion 4.8.0.0

        foreach ($disk in $DiskLayout.GetEnumerator()) {
            (Get-DscSplattedResource -ResourceName Disk -ExecutionName $disk.DiskId -Properties $disk -NoInvoke).Invoke($disk)
        }
    }
    ```

6. Your YAML file, for example the file server role, can now easily use the new configuration by subscribing to it and configuring it:

    ```yaml
    Configurations:
    - Disks

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

Congratulations! You have walked through the entire process of making this repository your own! We hope you are successful with this concept - we certainly are.
