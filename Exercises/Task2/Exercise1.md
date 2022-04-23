# Task 2 - The build

*Estimated time to completion: 30-60 minutes*

This task is about building the solution locally. For that, no infrastructure or service is required. All you need is having cloned the public DscWorkshop repository to your machine.

To kick off a new build, the script ```build.ps1``` is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

After completing this task, you have a gone through the build process for all artifacts that are required for a DSC pull server scenario (on-prem or Azure).

> ## Note: Remember to check the [prerequisites](../CheckPrereq.ps1) first

---

## 2.1 Running a manual build locally

1. Open Windows PowerShell as elevated Admin. Do this by pressing the Windows and then typing ```powershell.exe``` and then right-click select 'Run As Administrator'
1. Execute the ```Get-ExecutionPolicy``` cmdlet. The resulting execution policy should be either RemoteSigned, Unrestricted or Bypass:

    ```code
    Get-ExecutionPolicy

    RemoteSigned
    ```

    If this is not the case, execute

    ```powershell
    Set-ExecutionPolicy RemoteSigned -Force
    ```

1. Change to a suitable directory in which to clone the workshop files. As you will navigate to that folder quite often, keep it easy like

    ```powershell
    mkdir C:\Git
    Set-Location -Path C:\Git
    ```

1. **Optional**: If you have not yet installed git, please do so now by executing the following lines of code:

    ```powershell
    Install-PackageProvider -Name nuget -Force
    Install-Module Chocolatey -Force
    Install-ChocolateySoftware
    Install-ChocolateyPackage -Name git -Force
    ```  

    If you do not want to install Chocolatey, you can also browse to <https://git-scm.org> and download and install git from there.

1. Ensure that the git executable is in your path to make the next exercises work. Otherwise, please use the full or relative path to git.exe in the following steps.

    > Note: After installing git, you may need to close and open VSCode or the ISE again to make the process read the new path environment variable.

1. In this and the following exercises we will be working with the open-source DscWorkshop repository hosted at <https://github.com/dsccommunity/DscWorkshop>. To clone this repository, please execute:

    > Note: Please make sure you are in the 'C:\Git' folder or wherever you want to store project.

    ```powershell
    git clone https://github.com/dsccommunity/DscWorkshop
    ```

1. Change into the newly cloned repository and checkout the dev branch to move into the development

    ```powershell
    Set-Location -Path .\dscworkshop
    ```

    To get the branch you are currently using, just type:

    ```powershell
    git branch
    ```

    If the command did not return 'dev', please switch for the 'dev' branch like this. If the branch 'dev' does not exist yet, create one like done in the next code block:
  
    ```powershell
    git checkout dev

    #if the previous command failed with: error: pathspec 'dev' did not match any file(s) known to git
    git branch dev
    git checkout dev
    ```

    > Note: If you want to read more about branches in git, have a look at the documentation about [git branches](https://git-scm.com/book/en/v2/Git-Branching-Branches-in-a-Nutshell)

1. Open the DscWorkshop folder in VSCode and examine the repository contents. The shortcut in VSCode to open a folder is `CTRL+K CTRL+O`. You can also press `F1` and type in the command you are looking for. And of course there is the classical way using the file menu.

1. For a build to succeed, multiple dependencies have to be met. These are defined in a file containing hashtables of key/value pairs much like a module manifest (*.psd1) file. Take a look at the content of the file `RequiredModules.psd1` by opening it from the project's root folder in VSCode:

    PSDepend is another PowerShell module being used here which can be leveraged to define project dependencies to PowerShell modules, GitHub repositories and more.
    On learn more about PSDepend, have a look at <https://github.com/RamblingCookieMonster/PSDepend>

1. Without modifying anything yet, start the build script by executing:

    ```powershe
    ll
    .\build.ps1
    ```

    This command will download all dependencies that have been defined in the previously mentioned file `RequiredModules.psd1` and then build the entire environment. Downloading all the dependencies can take a short while.

    While the script is running, you may want to explore the following folders. The `PSDepend` module downloads and stores the dependencies into the folder defined as target in the `RequiredModules.psd1`, which is `output\RequiredModules`.

    >Note: Depending on you machine's speed, your internet connection and the performance of the PowerShell Gallery, the initial build with downloading all the resources may take 5 to 15 minutes. Subsequent builds should take around 2 to 4 minutes.

1. After the build process has finished, a number of artifacts have been created. The artifacts that we need for DSC are the
    - MOF files
    - Meta.MOF files
    - compressed modules

    Additionally, you have artifacts that help when investigating issues with the configuration data or when debugging something but which are not required for DSC.
    - CompressedArtifacts
    - Logs
    - RSOP
    - RsopWithSource
  
    Before having a closer look at the artifacts, let's have a look how nodes are defined for the dev environment. In VSCode, please navigate to the folder `source\AllNodes\Dev`.

    You should see two files here for the `DSCFile01.yml` and `DSCWeb01.yml`.

1. Please open the files `DSCFile01.yml` and `DSCWeb01.yml`. Both files are in the YAML format. [YAML](https://yaml.org/), like JSON, has been around since 2000 / 2001 and can be used to serialize data.

    The file server for example looks like this:

    ```yaml
    NodeName: '[x={ $Node.Name }=]'
    Environment: '[x={ $File.Directory.BaseName } =]'
    Role: FileServer
    Description: '[x= "$($Node.Role) in $($Node.Environment)" =]'
    Location: Frankfurt
    Baseline: Server

    ComputerSettings:
    Name: '[x={ $Node.NodeName }=]'
    Description: '[x= "$($Node.Role) in $($Node.Environment)" =]'

    NetworkIpConfiguration:
    Interfaces:
        - InterfaceAlias: DscWorkshop 0
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
        ConfigurationNames: '[x={ $Node.NodeName }=]'

    DscTagging:
    Layers:
        - '[x={ Get-DatumSourceFile -Path $File } =]'

    FilesAndFolders:
    Items:
        - DestinationPath: Z:\DoesNotWork
        Type: Directory
    ```

    >Note: The syntax `'[x={ <code> } =]'` invokes PowerShell code for adding data to your yaml files during compilation. More information about this can be found on [Datum.InvokeCommand](https://github.com/raandree/Datum.InvokeCommand).

    A node's YAML will contain data that is unique to the node, like its name or IP address. It will also contain role assignments like `FileServer`, the location of the node as well as the optional LCM configuration name to pull.

1. The role of a node (`FileServer`) is effectively a link to another YAML file, in this case `FileServer.yml` in the folder `.\source\Roles\FileServer.yml`. A role describes settings that are meant for a group of nodes and is the next level of generalization. Notice that the content starts with the `Configurations` key. Nodes, Roles and Locations can all subscribe to DSC composite resources, which we call configurations:

    ```yaml
    Configurations:
    - FilesAndFolders
    - RegistryValues
    ```

    Each composite resource can receive parameters by specifying them a little further down in the YAML:

    ```yaml
    FilesAndFolders:
        Items:
          - DestinationPath: C:\Test
            Type: Directory
    ```

    In this case, the configuration (composite resource) 'FilesAndFolders' accepts a (very generic) parameter called 'Items'. The 'Items' parameter is simply a hashtable expecting the same settings that the [File resource](https://docs.microsoft.com/en-us/powershell/scripting/dsc/reference/resources/windows/fileResource?view=powershell-7.1) would use as well. The configuration is documented and you can find some examples how to use it in [DSC Resource 'FilesAndFolders'](https://github.com/raandree/DscConfig.Demo/blob/main/doc/FilesAndFolders.adoc).

    The location of a node is even more generic than the role and can be used to describe location-specific items like network topology and other settings. Same applies to the environment.

1. Now it's time to focus more on the artifacts. The build process created four types of artifacts:
       - MOF files
       - Meta.MOF files
       - Compressed modules
       - RSoP YAML files with and without source level information

    Among these, the RSoP (Resultant Set of Policy) will be very helpful as these files will show you what configuration items exactly will be applied to your nodes and the parameters given to them. The concept of RSoP is very similar to Windows Group Policies and how to use [Resultant Set of Policy to Manage Group Policy](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn789183(v=ws.11)).

    Examine the RSoP files now which are in the folder `output\RSOP` and `output\RsopWithSource`.

1. Let's take the RSoP artifact for 'DSCFile01'. If you compare the RSoP output of this node (DSC\BuildOutput\RSoP\DSCFile01.yml) to the node's config file (DSC\DscConfigData\AllNodes\Dev\DSCFile01.yml), you will notice that there are many more properties defined than in the original 'DSCFile01.yml'. Where did these come from? They are defined the node's role and location YAML files.

    For understanding how Datum merges different layers, please refer to [Lookup Merging Behavior](https://github.com/gaelcolas/Datum#lookup-merging-behaviour).

1. The usable artifacts are your MOF, Meta.MOF files and compressed modules - these files will be part of your release pipeline.

---

Congratulations. You have just built the entire development environment! Want to test this, but don't have the infrastructure (Azure DevOps Server, SQL, AD, PKI, target nodes)? Try <https://github.com/automatedlab/automatedlab>, the module that helps you with rapid prototyping of your apps ;) Included in this repository is the entire lab script for
- [Azure](../../Lab/10%20HyperV%20Full%20Lab%20with%20DSC%20and%20AzureDevOps.ps1)
- [HyperV](../../Lab/10%20HyperV%20Full%20Lab%20with%20DSC%20and%20AzureDevOps.ps1)

Please continue with [Exercise 2](Exercise2.md) when your are ready.
