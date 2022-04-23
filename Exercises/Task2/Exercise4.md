# Task 2 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script `build.ps1` is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](../CheckPrereq.ps1)!***

---

## 2.4 Add another layer to your hierarchy

You are tasked with creating another layer that better reflects separate fire sections for your locations. All locations have two fire sections that are physically kept apart from each other. Each computer should have the fire section information written to its registry in the key `HKEY_LOCAL_MACHINE\SOFTWARE\Dsc`.

1. To create a new layer, you need to find an appropriate structure. Since the file system is already quite good when it comes to displaying hierarchical data, we can add a subfolder called `FireSections` which should contain for example `Section1.yml` and `Section2.yml`. The file subscribes to the `RegistryValues` configuration to write a registry key to the nodes containing the fire section. You may either use VSCode to create the folder and the files or run the following commands:

> **Note: Before running the commands, make sure you are in the directory `DSC`**.

```powershell
@'
Configurations:
  - RegistryValues

RegistryValues:
  Values:
    - Key: HKEY_LOCAL_MACHINE\SOFTWARE\Dsc
      ValueName: FireSection
      ValueData: 1
      ValueType: DWORD
      Ensure: Present
      Force: true

DscTagging:
  Layers:
    - FireSections\Section1
'@ | New-Item -Path .\source\FireSections\Section1.yml -Force

@'
Configurations:
  - RegistryValues

RegistryValues:
  Values:
    - Key: HKEY_LOCAL_MACHINE\SOFTWARE\Dsc
      ValueName: FireSection
      ValueData: 2
      ValueType: DWORD
      Ensure: Present
      Force: true

DscTagging:
  Layers:
    - FireSections\Section2
'@ | New-Item -Path .\source\FireSections\Section2.yml -Force
```

1. Please start a new build and examine the RSoP files for the new fire section information once completed. Don't try too hard to find the information. It is expected that it's not there. Why?

    We have created config files containing the fire sections but the nodes have not been assigned a fire section yet.

1. To assign a node to a fire section, please open the files for the nodes `DSCFile01` and `DSCWeb01` in the dev environment. Like a node is assigned to a location or role, you can add a line containing the fire section like this:

    ```yml
    NodeName: '[x={ $Node.Name }=]'
    Environment: '[x={ $File.Directory.BaseName } =]'
    Role: FileServer
    Description: '[x= "$($Node.Role) in $($Node.Environment)" =]'
    Location: Frankfurt
    Baseline: Server
    FireSection: Section1
    ```

1. Please build the project again. This time you will see that the fire section number has made it to the node's RSoP files. However, something important is missing: The data about the registry key to write. Why is it still missing?

1. In order to add completely new layers to your configuration, you need to tell Datum about it by modifying the lookup precedence. This is one in the global configuration file called `Datum.yml` stored in the directory `source`. Please open the file.

1. Examine the current contents of `Datum.yml` and notice the resolution order for your files:

    | Name      | Description |
    |-|-|
    | `Baselines\Security` | The security basline overwrites everything|
    | `AllNodes\$($Node.Environment)\$($Node.NodeName)` | The settings unique to one node|
    | `Environment$($Node.Environment)` | The settings that are environment specific|
    | `Environment$($Node.Location)` | The settings that are location specific|
    | `Roles\$($Node.Role)` | The settings unique to the role of a node|
    | `Baselines\$($Node.Baseline)` | The baseline settings that should apply to all nodes and roles|
    | `Baselines\DscLcm` | DSC specific settings like intervals, maintenance windows  and version info

    The settings get more generic the further down you go in the list. This way, your node will always win and will always be able to override settings that have been defined on a more global scale like the environment. This is because the default lookup is set to `MostSpecific`, so the most specific setting wins.

    Some paths are configured to have a different lookup option like `merge_basetype_array: Unique` or `merge_hash: deep`. This tells Datum not to override settings in lower levels but merge the content. An example:

    The `Security.yml` baseline adds the Windows feature `Telnet-Client` to the list of windows features (for removal):

      ```yaml
        WindowsFeatures:
          Names:
          - -Telnet-Client
      ```
  
    And the `WebServer` role contains some other Windows features:

      ```yaml
        WindowsFeatures:
          Names:
          - +Web-Server
          - -WoW64-Support
      ```

    The `Datum.yml` defines the merge behavior for the path `WindowsFeatures\Name`:

      ```yaml
        WindowsFeatures\Name:
          merge_basetype_array: Unique
      ```

    The result can be seen the RSoP files. After building the project, the Windows features config section in the `DSCWeb01.yml` in the folder `output\RSOP` looks like this:

      ```yaml
        WindowsFeatures:
          Names:
          - +Web-Server
          - -WoW64-Support
          - -Telnet-Client
      ```

    More complex merging scenarios are supported that will be explained in later articles.

1. Let's go back to the fire section task. A good place to add your new layer thus would be somewhere before the node-specific data is applied, since a separate fire section might mean different IP configurations.

    Let's add the new layer by adding an entry to Datum's global lookup precedence. Depending on when you want your new layer to apply, this could look like:

    ```yaml
    ResolutionPrecedence:
    - AllNodes\$($Node.Environment)\$($Node.NodeName)
    - Environment\$($Node.Environment)
    - Locations\$($Node.Location)
    - FireSections\$($Node.FireSection)
    - Roles\$($Node.Role)
    - Roles\ServerBaseline
    - Roles\DscBaseline
    ```

    We are using node-specific settings to select the correct files to import. This principle gives you a lot of flexibility to put your infrastructure and business requirements into DSC config data.

    In summary, adding new layers is a bit more involved than adding a new role. You need to think about the resolution precedence and the way your settings will be merged. Our project can serve as a good starting point, but you still need to take care of organizational requirements and so on.

    If you start a new build now, you will find three references in the RSoP files to the fire section:
    - The fire section assignment on the node level.
    - The fire section reference in `DscTagging\Layers`.
    - The fire section registry key.

    The RSOP file should look like this:

    ```yaml
    FireSection: Section1
    .
    DscTagging:
      Environment: Dev
      Version: 0.3.0
      Layers:
      - AllNodes\Dev\DSCFile01
      - Environment\Dev
      - Locations\Frankfurt
      - FireSections\Section1
      - Roles\FileServer
      - Baselines\Security
      - Baselines\Server
      - Baselines\DscLcm
    .
    RegistryValues:
      DependsOn: '[FilesAndFolders]FilesAndFolders'
      Values:
      - ValueName: FireSection
        ValueType: DWORD
        ValueData: 1
        Ensure: Present
        Force: true
        Key: HKEY_LOCAL_MACHINE\SOFTWARE\Dsc
    ```

---

Please continue with [the stretch goal](StretchGoal.md) when your are ready.
