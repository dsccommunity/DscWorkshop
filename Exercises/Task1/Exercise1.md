# Task 1 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script Build.ps1 is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](..\CheckPrereq.ps1)!***

## 1.1 Running a manual build

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
3. Change to a suitable directory in which to clone the workshop files, for example
    ```powershell
    Set-Location -Path $home
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
5. In this and the following exercises we will be working with the open-source DscWorkshop repository hosted at <https://github.com/automatedlab/dscworkshop>. To clone this repository, please execute:
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
8. For a build to succeed, multiple dependencies have to be met. These are defined in files containing hashtables of Key/Value pairs much like a module manifest (*.psd1) files. In oder to take a look at the contents of these files executed the following:
    ```powershell
    ise ((Get-ChildItem -Filter *PSDepend*.psd1).Fullname -Join ',')
    ```
    PSDepend is another PowerShell module being used here which can be leveraged to define project dependencies to PowerShell modules, GitHub repositories and more.
    To learn more about PSDepend, have a look at <https://github.com/RamblingCookieMonster/PSDepend>

9. Without modifying anything yet, start the build script by executing:
    ```powershell
    .\DscSample\Build.ps1 -ResolveDependency
    ```
    This command will download all dependencies that have been defined and build the entire environment. This can take a short while.
10. After the build process has finished, a number of artifacts have been created. Let's have a look at the dev nodes first.
    To see which nodes are part of your development environment, please execute the following command:
    ```powershell
    ise ((Get-ChildItem .\DscConfigData\AllNodes\Dev).FullName -join ',')
    ```
11. The previous command should have opened two files: DSCFile01.yml and DSCWeb01.yml. Both files are in the YAML format. YAML, like JSON, has been around since 2000/2001 and can be used to serialize data.

    The file server for example might look like this:
    ```yaml
    NodeName: DSCFile01
    Environment: Dev
    Role: FileServer
    Description: 'File Server in Dev'
    Location: Frankfurt

    NetworkIpConfiguration:
        IpAddress: 192.168.111.100
        Prefix: 24
        Gateway: 192.168.111.50
        DnsServer: 192.168.111.10
        InterfaceAlias: Ethernet
        DisableNetbios: True

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
    ise (Get-ChildItem -Path .\BuildOutput\RSOP -File)[0].fullname
    ```
14. If you compare this output to the node's YAML file, you will notice that there are many more properties defined than in the original Node.yaml. Where did these come from? They are defined the node's role and location YAML files.

15. The usable artifacts are your MOF and meta.MOF files - these files will be part of your release pipeline.

Congratulations. You have just built the entire development environment! Want to test this, but don't have the infrastructure (Azure DevOps Server, SQL, AD, PKI, target nodes)? Try <https://github.com/automatedlab/automatedlab>, the module that helps you with rapid prototyping of your apps ;) Included in this repository is [the entire lab script](../Lab/03.10%20Full%20Lab%20with%20DSC%20and%20TFS.ps1).

Please continue with [Exercise 2](Exercise2.md) when your are ready.
