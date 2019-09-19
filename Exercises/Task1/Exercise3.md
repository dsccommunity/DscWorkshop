# Task 1

Desired State Configuration has been introduced with Windows Management Framework 4 and has been improved in WMF5.1. DSC gives administrators the necessary tools to generate configuration files, called MOF files, that machines can consume.

## Exercise 3

In exercise 1 we created two MOF files. In your environment, these compiled configurations would be published on a Pull server. Each node would then download these configurations. But how does a node connect to a pull server?

1. Open Windows PowerShell ISE or another PowerShell Editor of your choice ***as an administrator***
2. To configure the engine enacting the changes, the Local Configuration Manager, we write another configuration. This is usually called meta configuration.

    ```powershell
        [DscLocalConfigurationManager()]
        configuration MetaConfiguration
        {

        }
    ```

3. To configure a pull server, you just need the pull server address as well as the registration key.

    > The registration key can be viewed as an API key - it allows a node to access your pull server

    ```powershell
        [DscLocalConfigurationManager()]
        configuration MetaConfiguration
        {
            Settings
            {
                RefreshMode = 'Pull'
            }

            ConfigurationRepositoryWeb PullServer1
            {
                ServerURL = 'https://PullServer1.your.domain'
                RegistrationKey = 'Pre-shared key that is defined on the pull server'
            }
        }

        MetaConfiguration
    ```

4. Have a look at the meta-configuration that has been created:

    ```powershell
        Get-Content .\MetaConfiguration\localhost.meta.mof
    ```

5. Once a configuration has automatically been pulled, changes are constantly monitored by the Local Configuration Manager. To simulate what happens try one of the DSC cmdlets, ```Test-DscConfiguration```

    ```powershell
        Test-DscConfiguration -Reference .\DscWeb01.mof -Verbose
    ```

6. The pull server can also serve as a source of reporting. In this final step, try to onboard your node to the workshop automation account. Ask your trainers for the automation account URL and registration key!

    ```powershell
        [DscLocalConfigurationManager()]
        configuration Reporting
        {
            ReportServerWeb RSAzure
            {
                ServerURL = 'Ask your trainer or use your own automation account'
                RegistrationKey = 'Ask your trainer or use your own Automation accoutn'
            }
        }

        Reporting
    ```

7. This time, you may onboard your own system if you want to. Since there are no configurations being applied, it is safe to do so. The node will appear inside Azure Automation, but will not download any configuration data.

Congratulations! You have just mastered the first steps with DSC! Follow along with the rest of the workshop, which just makes use of DSC, but does not require you to have deep knowledge of it.

It is time now to go to [Task 2](../Task2/readme.md).
