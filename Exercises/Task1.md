# Task 1 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script [Build.ps1](../DscSample/Build.ps1) is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.  

To do this, there are many moving parts. Different PowerShell modules like Datum, PSDepend, BuildHelpers, Pester and more are necessary to do a succesful build. In order to provision all dependencies, the build script is executed with the ResolveDependency parameter. The Environment parameter directly relates to the project structure and can be used in a pipeline to build artifacts for one specific environment like Dev.

## 1.1 Running a manual build

1. Open Windows PowerShell by typing pressing Windows+R and running ```powershell.exe```
2. Execute the ```Get-ExecutionPolicy``` cmdlet. The resulting execution policy should be either RemoteSigned, Unrestricted or Bypass:  
    ```code
    Get-ExecutionPolicy -List

            Scope ExecutionPolicy
            ----- ---------------
    MachinePolicy       Undefined
    UserPolicy       Undefined
        Process       Undefined
    CurrentUser       Undefined
    LocalMachine    RemoteSigned
    ```  
    If this is not the case, execute
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Force
    ```
3. Change to a suitable directory, for example
    ```powershell
    Set-Location -Path $home
    ```
4. If you have not yet installed git, please do so now by executing the following lines of code:  
    ```powershell
    Install-PackageProvider -Name nuget -Force
    Install-Module Chocolatey -Force
    Install-ChocolateySoftware
    Install-ChocolateyPackage -Name git -Force
    ```
5. In this and the following exercises we are working with the open-source DscWorkshop repository hosted at <https://github.com/automatedlab/dscworkshop>. To clone this repository, please execute:
    ```powershell
    git clone https://github.com/automatedlab/dscworkshop
    ```
6. Change into the newly cloned repository and checkout the dev branch to move into the development environment:
    ```powershell
    Set-Location -Path .\dscworkshop
    git checkout dev
    ```
7. Examine the repository contents by executing:
    ```powershell
    tree /F
    ```
8. For a build to succeed, multiple dependencies have to be met. These are defined in files:  
    ```powershell
    Get-ChildItem -Recurse -Filter PSDepend* | Get-Content
    ```  
    PSDepend is another PowerShell module being used here which can be leveraged to define project dependencies to PowerShell modules, GitHub repositories and more.  
    To learn more about PSDepend, have a look at <https://github.com/RamblingCookieMonster/PSDepend>
9. Without modifying anything yet, start the build script by executing:
    ```powershell
    .\DscSample\Build.ps1 -ResolveDependency
    ```  
    This command will download all dependencies that have been defined and build the entire environment.
10. After the build process has finished, a number of artifacts have been created. Since we are in the dev branch, only the development nodes have been built.  
    To see which nodes are part of your development environment, please execute the following command:
    ```powershell
    ise ((ls .\DscSample\DSC_ConfigData\AllNodes\Dev).FullName -join ',')
    ```
11. The previous command should have opened two files: DSCFile01.yml and DSCWeb01.yml. Both files are in the YAML format. YAML, like JSON, has been around since 2000/2001 and can be used to serialize data.  
    The file server for example might look like this:
    ```yaml
    NodeName: DSCFile01
    Environment: Dev
    Role: FileServer
    Description: 'File Server in Dev'
    Location: Frankfurt

    PSDscAllowPlainTextPassword: True
    PSDscAllowDomainUser: True

    LcmConfig:
    Settings:
        ConfigurationModeFrequencyMins: 15
        ConfigurationMode: ApplyAndAutoCorrect
    ConfigurationRepositoryWeb:
        Server:
        ConfigurationNames: DSCFile01
    ```  
    A node's YAML will contain data that is unique to the node, like its name. It will also contain role assignments like "FileServer", the location of the node as well as the optional LCM configuration.
12. The role of a node is effectively a link to another YAML file, for example FileServer.yaml. A role describes settings that are meant for a group of nodes and is the next level of generalization. Notice that the content starts with the Configurations key. Nodes, Roles and Locations can all subscribe to DSC composite resources, which we call configurations:
    ```yaml
    Configurations:
    - FilesAndFolders
    - RegistryValues
    ```  
    Each composite resource can receive parameters by specifying them a little further down in the YAML:  
    ```yaml
    FilesAndFolders:
      Items:
        - DestinationPath: C:\GpoBackup
          SourcePath: \\dscdc01\SYSVOL\contoso.com\Policies
          Type: Directory
    ```  
    In this case, the composite resource FilesAndFolders accepts a (very generic) parameter called Items. The Items parameter is simply a hashtable expecting the same settings that the File resource would use as well.  
    The location of a node is even more generic than the role and can be used to describe location-specific items like network topology and other settings.
13. The build process created three types of artifacts: MOF files, Meta.MOF files and RSOP YAML files. Among these, the RSOP will be very helpful as these files will show you what configuration items exactly will be applied to your nodes. Examine the RSOP of one node now:  
    ```powershell
    $firstRsop = Get-ChildItem -File -Path .\BuildOutput\RSOP | Select-Object -First 1 -ExpandProperty FullName
    ise $firstRsop
    ```  
14. If you compare this output to the node's YAML file, you will notice that there are much more properties filled that came from the node's role and location.
15. The usable artifacts are your MOF and meta.MOF files - these files will be part of your release pipeline.

Congratulations. You have just built the entire development environment! Want to test this, but don't have the infrastructure (Azure DevOps Server, SQL, AD, PKI, target nodes)? Try <https://github.com/automatedlab/automatedlab>, the module that helps you with rapid prototyping of your apps ;) Included in this repository is [the entire lab script](../Lab/03.10%20Full%20Lab%20with%20DSC%20and%20TFS.ps1).

## 1.2 Add a new node

You are tasked with onboarding a new node DSCFile04 to your environment. The node should be a file server in your branch office in Singapore. You also know that it should be part of the Pilot servers or canaries that receive new DSC configurations before other production servers.

1. Create a new file called DSCFile04.yml as a copy of DSCFile02.yml in the folder DSC_ConfigData\AllNodes\Pilot which will be the first step when adding a new node.
2. Open the newly created file and modify the properties NodeName, Location, Description and ConfigurationNames.  
  *Please note that outside of a workshop environment, this step can easily be scripted to e.g. use a CMDB as the source for new nodes*  
    ```yaml
    NodeName: DSCFile04
    Environment: Pilot
    Role: FileServer
    Description: 'SIN secondary file server'
    Location: Singapore
    ```
3. This simple file is already enough for your new node. Produce new artifacts now by committing your changes and running a build again:  
    ```powershell
    git add .
    git commit -m "Added node DSCFile04"
    .\DscSample\Build.ps1 -Environment Pilot
    ```
4. If you now examine the contents of your BuildOutput folder, you will notice that your new node will have received an RSOP file and two MOF files.  

It really is as simple as that. If you as a DevOps person can provide the building blocks (Configurations) to your customers, they can easily collaborate and onboard their workloads to DSC without even knowing it.

## 1.3 Add a new role

Now, your branch office in Frankfurt needs a new role for SQL servers. The business has defined the following requirements:

- A specific network config. The new VM needs the address 10.0.1.42/24, with its DNS servers being 10.0.1.10 and 10.0.1.11. The gateway address should be 10.0.1.1
- The windows features NET-Framework-Core and NET-Framework-45-Core need to be installed.

This new role should enable SQL administrators to build on top of the basic infrastructure.

1. Create a new file called SqlServer.yml in the folder DSC_ConfigData\Roles to serve as your starting point.
2. We already know that new SQL servers should subscribe to two configurations: NetworkIpConfiguration and WindowsFeatures. By adding them to the role you can declare this dependency:  
    ```yaml
    Configurations:
    - NetworkIpConfiguration
    - WindowsFeatures
    ```
3. Once added, your Configurations can receive parameters leveraging the easy structure that YAML provides.  
    ```yaml
    NetworkIpConfiguration :
    - IpAddress : 10.0.1.42
    - Prefix : 24
    - Gateway : 10.0.0.1
    - DnsServer : 
        - 10.0.0.10
        - 10.0.0.11
    WindowsFeatures :
    Name:
    - +NET-Framework-Core
    - +NET-Framework-Core-45
    ```  
4. To make use of your new role, you need to assign it to a node's Role setting. Commit your changes, modify any node's yml file and add your new role. Then start the build again!

Once again, it is that easy. New roles, environments and nodes just require adding a YAML file. The devil is in the details: Providing the appropriate configuration data for your configurations like the network configuration requires knowledge of the underlying infrastructure of course.

## 1.4 Modify a role

Modifying a role is as easy as modifying a node. Try changing the default time server to another host:  

1. Open the FileServer.yml from your Roles directory. We are modifying an already existing role definition now.
2. In order to change a configuration item, just modify or add to your YAML file:
    ```yaml
    RegistryValues:
    Values:
        - Key: HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Parameters
        ValueName: NtpServer
        ValueData: pool.contoso.local,0x2
        ValueType: DWORD
        Ensure: Present
    ```
3. After committing your changes, you can restart the build again to see your results in action. All file server artifacts that have been created will now have a modified MOF, meta.MOF and RSOP.

## 1.5 Add another layer to your hierarchy

You are tasked with creating another layer that better reflects separate fire sections for your locations. All locations have two fire sections that are physically kept apart from each other.

1. To create a new layer, you need to find an appropriate structure. Since the file system is already quite good when it comes to displaying hierarchical data, we can add a subfolder called FireSections which should contain for example Section1.yml and Section2.yml.
2. In order to add completely new layers to your configuration, you need to modify the lookup precedence. This is done in the global configuration file called Datum.yml.
3. Examine the current contents of Datum.yml and notice the resolution order for your files:  
    | Name      | Description |  
    | ----------- | ----------- |  
    | AllNodes\$($Node.Environment)\$($Node.NodeName) | The settings unique to one node
    | Roles\$($Node.Role) | The settings unique to the role of a node
    | Roles\Baseline | The baseline settings that should apply to all nodes and roles
    | Environment\$($Node.Environment) | The settings that are environment specific
    | MetaConfig\LCM | The basic settings for the LCM
    | MetaConfig\DscTagging | Version info that should apply to all nodes
4. The settings get more generic the further down you go in the list. This way, your node will always win and will always be able to override settings that have been defined on a more global scale like the environment.
5. A good place to add your new layer thus would be somewhere before the node-specific data is applied, since a separate fire section might mean different IP configurations.
6. In order for Datum to incorporate your new layer, you need to update the global lookup precedence. Depending on when you want your new layer to apply, this could look like:
    ```yaml
    ResolutionPrecedence:
    - AllNodes\$($Node.Environment)\$($Node.NodeName)
    - Roles\$($Node.Role)
    - Roles\Baseline
    - FireSections\$($Node.FireSection)
    - Environment\$($Node.Environment)
    - MetaConfig\LCM
    - MetaConfig\DscTagging
    ```  
    You can use node-specific settings to select the correct files to import. Here, we can add a new property called FireSection to all physical nodes for example.

Adding new layers is a bit more involved than adding a new role. You need to think about the resolution precedence and the way your settings will be merged. Our project can serve as a good starting point, but you still need to take care of organizational requirements and so on.

## 1.6 - Create a custom Configuration (DSC Composite Resource)

*This is a stretch goal, if the other tasks have been too easy.*

Extending configurations based on the customer's needs will eventually require you to develop actual DSC configurations in the form of composite resources. The guiding principle is that your composite resources should be able to take all their parameters from configuration data.  

There should rarely be the need for hardcoded values in your composite resources. Keep in mind though that they should abstract some of the complexity of DSC. A composite resource that requires massive amounts of configuration data is probably not the best choice.  

We cannot give you a blueprint that covers all your needs. However, the repository <https://github.com/automatedlab/commontasks> can serve as a starting point again. The CommonTasks module is our trusted module in the build and release pipeline and collects commonly used DSC composite resources.  

At your customer, this is all customer-specific code and should be collected in one or more separate PowerShell modules with their own build and release pipeline. This pipeline is trusted and will always deliver tested and working code to an internal gallery, for example [ProGet](https://inedo.com/proget), [Azure DevOps](https://dev.azure.com) or the free and open-source [NuGet](https://nuget.org).

1. Clone the repository CommonTasks  
    ```powershell
    cd $home
    git clone https://github.com/automatedlab/commontasks
    Get-ChildItem -Directory -Path  ./CommonTasks/CommonTasks/DSCResource
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