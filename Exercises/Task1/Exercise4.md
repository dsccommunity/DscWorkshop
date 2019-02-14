# Task 1 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script Build.ps1 is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](..\CheckPrereq.ps1)!***

## Add another layer to your hierarchy

You are tasked with creating another layer that better reflects separate fire sections for your locations. All locations have two fire sections that are physically kept apart from each other.

1. To create a new layer, you need to find an appropriate structure. Since the file system is already quite good when it comes to displaying hierarchical data, we can add a subfolder called FireSections which should contain for example Section1.yml and Section2.yml.

    ```powershell
    New-Item -Path .\DSC_ConfigData\FireSections\Section1.yml -ItemType File -Force
    New-Item -Path .\DSC_ConfigData\FireSections\Section2.yml -ItemType File -Force
    ```
2. In order to add completely new layers to your configuration, you need to modify the lookup precedence. This is done in the global configuration file called Datum.yml.

    ```powershell
    ise .\DSC_ConfigData\Datum.yml
    ```
3. Examine the current contents of Datum.yml and notice the resolution order for your files:
    | Name      | Description |  
    | ----------- | ----------- |  
    | AllNodes\$($Node.Environment)\$($Node.NodeName) | The settings unique to one node|  
    | Roles\$($Node.Role) | The settings unique to the role of a node|  
    | Roles\Baseline | The baseline settings that should apply to all nodes and roles|  
    | Environment\$($Node.Environment) | The settings that are environment specific|  
    | MetaConfig\LCM | The basic settings for the LCM|  
    | MetaConfig\DscTagging | Version info that should apply to all nodes|  
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

Please continue with [the stretch goal](StretchGoal.md) when your are ready.
