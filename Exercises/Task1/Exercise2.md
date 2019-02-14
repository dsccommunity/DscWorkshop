# Task 1 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script Build.ps1 is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](..\CheckPrereq.ps1)!***

## Add a new node

You are tasked with on-boarding a new node (DSCFile04) to your environment. The node should be a file server (Role) in your branch office in Singapore (Location). You also know that it should be part of the Pilot servers or canaries that receive new DSC configurations before other production servers.

1. Make a copy of DSCFile02.yml (use as a template) to the folder DSC_ConfigData\AllNodes\Pilot and call it DSCFile04.yml. This new yml will represent your new node.

    ```powershell
    Copy-Item -Path .\DSC_ConfigData\AllNodes\Pilot\DSCFile02.yml -Destination .\DSC_ConfigData\AllNodes\Pilot\DscFile04.yml
    ```

2. Open the newly created file and modify the properties NodeName, Location, Description and ConfigurationNames with the below values.
  *Please note that outside of a workshop environment, this step can easily be scripted to e.g. use a CMDB as the source for new nodes*

    ```powershell
    ise .\DSC_ConfigData\AllNodes\Pilot\DscFile04.yml
    ```

    ```yaml
    NodeName: DSCFile04
    .
    .
    Description: 'SIN secondary file server'
    .
    .
    Location: Singapore
    .
    .
    ConfigurationNames : DSCFile04

    ```
3. This simple file is already enough for your new node. Produce new artifacts now by committing your changes and running a build again:
    ```powershell
    git add .
    git commit -m "Added node DSCFile04"
    .\Build.ps1
    ```
4. If you now examine the contents of your BuildOutput folder, you will notice that your new node will have received an RSOP file and two MOF files.

   ```powershell
   Get-ChildItem -Path .\BuildOutput -Recurse -Filter DSCFile04* -File
   ```

It really is as simple as that. If you as a DevOps person can provide the building blocks (Configurations) to your customers, they can easily collaborate and onboard their workloads to DSC without even knowing it.

Please continue with [Exercise 3](Exercise3.md) when your are ready.
