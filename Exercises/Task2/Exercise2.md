# Task 2 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script 'Build.ps1' is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](../CheckPrereq.ps1)!***

---

## 2.2 Add a new node

You are tasked with on-boarding a new node (DSCFile04) to your environment. The node should be a file server (Role) in your branch office in Singapore (Location). You also know that it should be part of the Test servers or canaries that receive new DSC configurations before other production servers.

1. Make a copy of DSCFile02.yml (use as a template) inside the folder 'DSC\DscConfigData\AllNodes\Test' and call it 'DSCFile04.yml'. This new yml will represent your new node. You can do this in the VSCode (mark the file and press CTRL+C and then CTRL+V. Rename the new file) or you can use this PowerShell command.

    ```powershell
    Copy-Item -Path .\DscConfigData\AllNodes\Test\DSCFile02.yml -Destination .\DscConfigData\AllNodes\Test\DscFile04.yml
    ```

2. Open the newly created file and modify the properties NodeName, Location, Description and ConfigurationNames with the below values.
  *Please note that outside of a workshop environment, this step can easily be scripted to e.g. use a CMDB as the source for new nodes*

    ```yaml
    NodeName: DSCFile04
    .
    Description: 'SIN secondary file server'
    .
    Location: Singapore
    .
    ComputerSettings:
      Name: DSCFile01
    .
    NetworkIpConfiguration:
    Interfaces:
      - InterfaceAlias: Ethernet
        IpAddress: 192.168.111.112
    .
    LcmConfig:
      ConfigurationRepositoryWeb:
        Server:
          ConfigurationNames: DSCFile01
    .
    DscTagging:
      Layers:
        - AllNodes\Dev\DscFile04
    ```

3. This simple file is already enough for your new node. Produce new artifacts now by committing your changes and running a build again. You can commit the change by means of the VSCode UI or using the git command. You can find some guidance here:
[Using Version Control in VS Code](https://code.visualstudio.com/Docs/editor/versioncontrol). After the commit, start a new build. The commands look like this:

    ```powershell
    git add .
    git commit -m "Added node DSCFile04"
    .\Build.ps1
    ```

4. If you now examine the contents of your BuildOutput folder, you will notice that your new node will have received an RSOP file, a MOF and Meta.MOF file.

   ```powershell
   Get-ChildItem -Path .\BuildOutput -Recurse -Filter DSCFile04* -File
   ```

It really is as simple as that. If you as a DevOps person can provide the building blocks (Configurations) to your customers, they can easily collaborate and onboard their workloads to DSC without even knowing it.

Please continue with [Exercise 3](Exercise3.md) when your are ready.
