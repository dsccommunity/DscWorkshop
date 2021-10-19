# Task 2 - The build

*Estimated time to completion: 30-60 minutes*

This task is about building the solution locally. For that, no infrastructure or service is required. All you need is having cloned the public DscWorkshop repository to your machine.

To kick off a new build, the script ```/DSC/Build.ps1``` is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

After completing this task, you have a gone through the build process for all artifacts that are required for a DSC pull server scenario (on-prem or Azure).

> ## Note: Remember to check the [prerequisites](../CheckPrereq.ps1) first

---

## 2.1 Running a manual build locally

1. Open Windows PowerShell as elevated Admin. Do this by pressing the Windows and then typing ```powershell.exe``` and then right-click select 'Run As Administrator'
2. Execute the ```Get-ExecutionPolicy``` cmdlet. The resulting execution policy should be either RemoteSigned, Unrestricted or Bypass:

    ```code
    Get-ExecutionPolicy

    RemoteSigned
    ```

    If this is not the case, execute

    ```powershell
    Set-ExecutionPolicy RemoteSigned -Force
    ```

3. Change to a suitable directory in which to clone the workshop files. As you will navigate to that folder quite often, keep it easy like

    ```powershell
    mkdir C:\Git
    Set-Location -Path C:\Git
    ```

4. **Optional**: If you have not yet installed git, please do so now by executing the following lines of code:

    ```powershell
    Install-PackageProvider -Name nuget -Force
    Install-Module Chocolatey -Force
    Install-ChocolateySoftware
    Install-ChocolateyPackage -Name git -Force
    ```  

    If you do not want to install Chocolatey, you can also browse to <https://git-scm.org> and download and install git from there.

5. Ensure that the git executable is in your path to make the next exercises work. Otherwise, please use the full or relative path to git.exe in the following steps.

    > Note: After installing git, you may need to close and open VSCode or the ISE again to make the process read the new path environment variable.

6. In this and the following exercises we will be working with the open-source DscWorkshop repository hosted at <https://github.com/dsccommunity/DscWorkshop>. To clone this repository, please execute:

    > Note: Please make sure you are in the 'C:\Git' folder or wherever you want to store project.
    
    ```powershell
    git clone https://github.com/dsccommunity/DscWorkshop
    ```

7. Change into the newly cloned repository and checkout the dev branch to move into the development

    ```powershell
    Set-Location -Path .\dscworkshop
    ```

    To get the branch you are currently using, just type:
    ```powershell
    git branch
    ```

    If the command did not return 'dev', please switch for the 'dev' branch like this:
  
    ```powershell
    git checkout dev
    ```

    > Note: If you want to read more about this, have a look at the documentation about [git branches](https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell)

8. Open the DscWorkshop folder in VSCode and examine the repository contents. The shortcut in VSCode to open a folder is ```CTRL+K CTRL+O```. You can also press ```F1``` and type in the command you are looking for. And of course there is the classical way using the file menu.

9. For a build to succeed, multiple dependencies have to be met. These are defined in files containing hashtables of key/value pairs much like a module manifest (*.psd1) file. Take a look at the content of these files by navigating to the DSC folder in VSCode and open the \*PSDepend\*.psd1 files:

    PSDepend is another PowerShell module being used here which can be leveraged to define project dependencies to PowerShell modules, GitHub repositories and more.
    To learn more about PSDepend, have a look at <https://github.com/RamblingCookieMonster/PSDepend>

10. Without modifying anything yet, start the build script by executing:

    > Note: It is important to go into the DSC folder and start the build script form there. Don't invoke it like ```.\DSC\Build.ps1```.

    ```powershell
    cd DSC
    .\Build.ps1 -ResolveDependency
    ```

    This command will download all dependencies that have been defined first and then build the entire environment. Downloading all the dependencies can take This can take a short while.

    While the script is running, you may want to explore the following folders. The PSDepend module downloads and stores the dependencies into these folders based on the information in the files in brackets.
    - DSC\BuildOutput (DSC\PSDepend.Build.psd1)
    - DSC\DscConfigurations (DSC\PSDepend.DscConfigurations.psd1)
    - DSC\DscResources (DSC\PSDepend.DscResources.psd1)
  
    >Note: Depending on you machine's speed, your internet connection and the performance of the PowerShell Gallery, the initial build with downloading all the resources may take 20 to 30 minutes. Subsequent builds should take around 3 minutes.

11. After the build process has finished, a number of artifacts have been created. The artifacts that we need for DSC are the MOF files, Meta.MOF files and the compressed modules. Before having a closer look at the artifacts, let's have a look how nodes are defined for the dev environment. In VSCode, please navigate to the folder 'DSC\DscConfigData\AllNodes\Dev.

    You should see two files here for the DSCFile01 and DSCWeb01.

12. Please open the files 'DSCFile01.yml' and 'DSCWeb01.yml'. Both files are in the YAML format. YAML, like JSON, has been around since 2000/2001 and can be used to serialize data.

    The file server for example looks like this:

    ```yaml
    NodeName: DSCFile01
    Environment: Dev
    Role: FileServer
    Description: File Server in Dev
    Location: Frankfurt
    Baseline: Server

    ComputerSettings:
    Name: DSCFile01
    Description: File Server in Dev

    NetworkIpConfiguration:
    Interfaces:
        - InterfaceAlias: Ethernet
        IpAddress: 192.168.111.100
        Prefix: 24
        Gateway: 192.168.111.50
        DnsServer:
            - 192.168.111.10
        DisableNetbios: true

    PSDscAllowPlainTextPassword: True
    PSDscAllowDomainUser: True

    LcmConfig:
    ConfigurationRepositoryWeb:
        Server:
        ConfigurationNames: DSCFile01

    DscTagging:
    Layers:
        - AllNodes\Dev\DscFile01

    FilesAndFolders:
    Items:
        - DestinationPath: Z:\DoesNotWork
        Type: Directory
    ```

    A node's YAML will contain data that is unique to the node, like its name or IP address. It will also contain role assignments like 'FileServer', the location of the node as well as the optional LCM configuration name to pull.

13. The role of a node (FileServer) is effectively a link to another YAML file, in this case 'FileServer.yml' in the folder 'DSC\DscConfigData\Roles'. A role describes settings that are meant for a group of nodes and is the next level of generalization. Notice that the content starts with the 'Configurations' key. Nodes, Roles and Locations can all subscribe to DSC composite resources, which we call configurations:

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
          SourcePath: \\DSCDC01\SYSVOL\contoso.com\Policies
          Type: Directory
    ```

    In this case, the composite resource 'FilesAndFolders' accepts a (very generic) parameter called 'Items'. The 'Items' parameter is simply a hashtable expecting the same settings that the [File resource](https://docs.microsoft.com/en-us/powershell/scripting/dsc/reference/resources/windows/fileResource?view=powershell-7.1) would use as well.

    The location of a node is even more generic than the role and can be used to describe location-specific items like network topology and other settings. Same applies to the environment.

14. Now it's time to focus more on the artifacts. The build process created four types of artifacts: MOF files, Meta.MOF files, Compressed modules and RSoP YAML files. Among these, the RSoP (Resultant Set of Policy) will be very helpful as these files will show you what configuration items exactly will be applied to your nodes and the parameters given to them. The concept of RSoP is very similar to Windows Group Policies and how to [use Resultant Set of Policy to Manage Group Policy](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn789183(v=ws.11)).

    Examine the RSoP files now which are in the folder 'DSC\BuildOutput\RSoP'.

15. Let's take the RSoP artifact for 'DSCFile01'. If you compare the RSoP output of this node (DSC\BuildOutput\RSoP\DSCFile01.yml) to the node's config file (DSC\DscConfigData\AllNodes\Dev\DSCFile01.yml), you will notice that there are many more properties defined than in the original 'DSCFile01.yml'. Where did these come from? They are defined the node's role and location YAML files.

    For understanding how Datum merges different layers, please refer to [Lookup Merging Behaviour](https://github.com/gaelcolas/Datum#lookup-merging-behaviour).

16. The usable artifacts are your MOF, meta.MOF files and compressed modules - these files will be part of your release pipeline.

---

Congratulations. You have just built the entire development environment! Want to test this, but don't have the infrastructure (Azure DevOps Server, SQL, AD, PKI, target nodes)? Try <https://github.com/automatedlab/automatedlab>, the module that helps you with rapid prototyping of your apps ;) Included in this repository is the entire lab script for
- [Azure](../../Lab/10%20HyperV%20Full%20Lab%20with%20DSC%20and%20AzureDevOps.ps1)
- [HyperV](../../Lab/10%20HyperV%20Full%20Lab%20with%20DSC%20and%20AzureDevOps.ps1)

Please continue with [Exercise 2](Exercise2.md) when your are ready.
