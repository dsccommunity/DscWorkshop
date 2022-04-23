# Task 2 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script `build.ps1` is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](../CheckPrereq.ps1)!***

---

## 2.2 Add a new node

You are tasked with on-boarding a new node (DSCFile04) to your environment. The node should be a file server (Role) in your branch office in Singapore (Location). You also know that it should be part of the Test servers or canaries that receive new DSC configurations before other production servers.

1. Make a copy of `DSCFile02.yml` (use as a template) inside the folder 'source\AllNodes\Test' and call it `DSCFile04.yml`. This new yml will represent your new node. You can do this in the VSCode (mark the file and press CTRL+C and then CTRL+V. Rename the new file) or you can use this PowerShell command.

    ```powershell
    Copy-Item -Path .\source\AllNodes\Test\DSCFile02.yml -Destination .\source\AllNodes\Test\DSCFile04.yml
    ```

1. Please start the build job again by calling the `build.ps1` script and let's see if it was that easy to add a new node to the configuration data.

  You should see some red on the screen, always the wrong color. What is the problem?

  You should see an error message indicating that there is a IP address conflict. Before the build creates the RSOP files and compiles the MOF files, the configuration data is tested for integrity. There is a number of predefined tests and of course the list of tests can be extended depending on the complexity and design of your configuration data. The tests are invoked by [Pester](https://pester.dev/).

  ```
  [-] Should not have duplicate node names 19ms (17ms|2ms)
    Expected $null or empty, but got DSCFile02.
    at (Compare-Object -ReferenceObject $ReferenceNodes -DifferenceObject $DifferenceNodes).InputObject | Should -BeNullOrEmpty, D:\DscWorkshop\tests\ConfigData\ConfigData.Tests.ps1:127
    at <ScriptBlock>, D:\DscWorkshop\tests\ConfigData\ConfigData.Tests.ps1:127
  ```

1. Open the newly created file and modify the IP address to `192.168.111.112`. All other fields are retrieved dynamically using the Datum handler [Datum.InvokeCommand](https://github.com/raandree/Datum.InvokeCommand).
  
    > Please note that outside of a workshop environment, this step can easily be scripted to e.g. use a CMDB as the source for new nodes*.

    ```yaml
    NodeName: '[x={ $Node.Name }=]'
    Environment: '[x={ $File.Directory.BaseName } =]'
    .

    NetworkIpConfiguration:
      Interfaces:
        - InterfaceAlias: DscWorkshop 0
          IpAddress: 192.168.111.112
          Prefix: 24
          Gateway: 192.168.111.50
          DnsServer:
            - 192.168.111.10
          DisableNetbios: true

    .
    DscTagging:
      Layers:
        - '[x={ Get-DatumSourceFile -Path $File } =]'
    ```

1. After changing the IP address, this simple file is already enough for your new node. Produce new artifacts now by committing your changes and running a build again. You can commit the change by means of the VSCode UI or using the git command. You can find some guidance here:
[Using Version Control in VS Code](https://code.visualstudio.com/Docs/editor/versioncontrol).

You can also trigger the commit using the terminal like this:

  ```powershell
  git add .
  git commit -m 'Added node DSCFile04'
  .\Build.ps1
  ```

  After the commit, start a new build.

1. If you now examine the contents of your `output` folder, you will notice that your new node will have received two RSOP files, a MOF and Meta.MOF file.

   ```powershell
   Get-ChildItem -Path .\BuildOutput -Recurse -Filter DSCFile04* -File
   ```

It really is as simple as that. If you as a DevOps person can provide the building blocks (Configurations) to your customers, they can easily collaborate and onboard their workloads to DSC without even knowing it.

Please continue with [Exercise 3](Exercise3.md) when your are ready.
