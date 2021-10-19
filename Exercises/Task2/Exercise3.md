# Task 2 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script 'Build.ps1' is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](../CheckPrereq.ps1)!***

---

## 2.3 Add a new role

Now, your branch office in Frankfurt has requested a new role for WSUS servers. This requires you to configure the WSUS feature and set a registry key.

This new role should enable WSUS administrators to build on top of the basic infrastructure.

1. Let us now create a new role for a WSUS Server in the 'DSC\DscConfigData\Roles' folder. This role's YAML will subscribe to the configuration "WindowsFeatures" and will define configuration data (Settings) for the configuration.

Create a new file in 'DSC\DscConfigData\Roles' named 'WsusServer.yml'. Paste the following code into the new file and save it.

  ```yml
  Configurations:
  - WindowsFeatures
  
  WindowsFeatures:
    Name:
    - +UpdateServices
  ```

2. Now let us add a new node YAML (DSCWS01.yml) in the Test which is based on this Role. Create the new file 'DSCWS01.yml' in the folder 'DSC\DscConfigData\AllNodes\Test'. Paste the following content into the file and save it.

  ```yml
  NodeName: DSCWS01
  Environment: Test
  Role: WsusServer
  Description: WSUS Server in Test
  Location: Frankfurt
  Baseline: Server

  ComputerSettings:
    Name: DSCWS01
    Description: WSUS Server in Test

  NetworkIpConfiguration:
    Interfaces:
      - InterfaceAlias: Ethernet
        IpAddress: 192.168.111.113
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
        ConfigurationNames: DSCWS01

  DscTagging:
    Layers:
      - AllNodes\Test\DSCWS01
  ```

> Note: The YAML rendering does not always show the indention correctly. Please have a look at another node file to check the indention.
> To discover yaml syntax errors upfront, the VS Code plug-in [YAML](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml) should help.

Once again, it is that easy. New roles (i.e. WsusServer), environments (i.e. Test) and nodes (i.e. DSCWS01) just require adding YAML files. The devil is in the details: Providing the appropriate configuration data for your configurations like the network configuration requires knowledge of the underlying infrastructure of course.

In order to build the new node 'DSCWS01' which uses the 'WsusServer' role, simply start up the build again.

  ```powershell
  .\Build.ps1
  ```

After the build has completed take a look at the new nodes resulting files.

> **NOTE: YAML syntax can be tricky so if you have errors during the build it very likely due to not well formed YAML. Please use also the previously mentioned YAML VS Code plug-in.**

## 2.4 Modify a role

Modifying a role is even easier as adding a new one. Let's try changing the default time server for all the file servers. If the setting effect all time servers, it must be defined in the 'FileServer' role

1. Open the 'FileServer.yml' from your roles directory. We are modifying an already existing role definition now.

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

3. After committing your changes, you can restart the build again to see your results in action. All file server artifacts that have been created will now have a modified MOF and RSoP. You can either use the VSCode UI or the following commands: 

  ```powershell
  git add .
  git commit -m "Modified the ntp server setting for the file server role."
  .\Build.ps1
  ```

You should have a feeling now how easy it is to modify config data used by DSC when using Datum.

Please continue with [Exercise 4](Exercise4.md) when your are ready.
