# Task 1 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script Build.ps1 is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](..\CheckPrereq.ps1)!***

## 1.6 - Create a custom Configuration (DSC Composite Resource)

***This is a stretch goal, if the other tasks have been too easy.***

Extending configurations based on the customer's needs will eventually require you to develop actual DSC configurations in the form of composite resources. The guiding principle is that your composite resources should be able to take all their parameters from configuration data.

There should rarely be the need for hardcoded values in your composite resources. Keep in mind though that they should abstract some of the complexity of DSC. A composite resource that requires massive amounts of configuration data is probably not the best choice.

We cannot give you a blueprint that covers all your needs. However, the repository <https://github.com/automatedlab/commontasks> can serve as a starting point again. The CommonTasks module is our trusted module in the build and release pipeline and collects commonly used DSC composite resources.

At your customer, this is all customer-specific code and should be collected in one or more separate PowerShell modules with their own build and release pipeline. This pipeline is trusted and will always deliver tested and working code to an internal gallery, for example [ProGet](https://inedo.com/proget), [Azure DevOps](https://dev.azure.com) or the free and open-source [NuGet](https://nuget.org).

1. Clone the repository CommonTasks
    ```powershell
    cd $home
    git clone https://github.com/automatedlab/commontasks
    Get-ChildItem -Directory -Path  ./CommonTasks/CommonTasks/DSCResources
    ```
2. This module contains many small DSC composite resources, or configurations, that the project uses. Try adding your own composite resource by adding the following files to the structure:
    ```code
    CommonTasks\
    DscResources\
        <YourResourceName>\
        <YourResourceName>.psd1
        <YourResourceName>.schema.psm1
    ```
3. Either copy the module manifest content from another resource or add your own minimal content, describing which DSC resource is exposed:
    ```powershell
    @{
        RootModule           = '<YourResourceName>.schema.psm1'
        ModuleVersion        = '0.0.1'
        GUID                 = '27238df7-8c89-4acf-8eef-80750b964380'
        Author               = 'NA'
        CompanyName          = 'NA'
        Copyright            = 'NA'
        DscResourcesToExport = @('<YourResourceName>')
    }
    ```
4. Your psm1 file now should only contain your DSC configuration element, the composite resource. Depending on the DSC resources that you use in this composite, you can make use of Datum's cmdlet Gt-DscSplattedResource or its alias x to pass parameter values to the resource in a single, beautiful line of code.
    The following code for example uses the Disk resource to configure disk layouts. The parameters can be passed to your resource in the YAML file.
    ```powershell
    Configuration <YourResourceName>
    {
        param
        (
            [Parameter(Mandatory)]
            [hashtable[]]
            $DiskLayout
        )

        Import-DscResource -ModuleName StorageDsc -ModuleVersion 4.4.0.0

        foreach ($disk in $DiskLayout.GetEnumerator())
        {
            (Get-DscSplattedResource -ResourceName Disk -ExecutionName $disk.DiskId -Properties $disk -NoInvoke).Invoke($disk)
        }
    }
    ```
5. Your YAML file, for example the file server role, can now easily use the new configuration by subscribing to it and configuring it:
    ```yaml
    Configurations:
    - <YourResourceName>

    <YourResourceName> :
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
