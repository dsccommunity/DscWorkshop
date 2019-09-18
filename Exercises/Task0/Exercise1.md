# Task 0

Desired State Configuration has been introduced with Windows Management Framework 4 and has been improved in WMF5.1. DSC gives administrators the necessary tools to generate configuration files, called MOF files, that machines can consume.

## Exercise 1

1. Open Windows PowerShell ISE or another PowerShell Editor of your choice
2. DSC always starts with the configuration keyword. Much like a function, a configuration has a name and a body
    ```powershell
        configuration MyFirstConfig
        {
    
        }
    ```
3. Inside a configuration, there may be one or more node blocks. Add some nodes now!
    ```powershell
        configuration MyFirstConfig
        {
            node DSCFil01
            {

            }

            node DSCWeb01
            {

            }
        }
    ```
4. Each node can consume one or more resources. Try to add some Windows features to your servers:
    ```powershell
        configuration MyFirstConfig
        {
            node DSCFil01
            {
                WindowsFeature DFS
                {
                    Name = 'FS-DFS-Replication'
                }
            }

            node DSCWeb01
            {
                WindowsFeature Web
                {
                    Name = 'Web-Server'
                }
            }
        }
    ```
5. In order to actually convert this code into something that target machines can properly enact, you need to compile the configuration element into a MOF file. Try it now!
    ```powershell
        configuration MyFirstConfig
        {
            node DSCFil01
            {
                WindowsFeature DFS
                {
                    Name = 'FS-DFS-Replication'
                }
            }

            node DSCWeb01
            {
                WindowsFeature Web
                {
                    Name = 'Web-Server'
                }
            }
        }

        MyFirstConfig
    ```
6. Running the configuration has produced two MOF files, DSCFile01.mof and DSCWeb01.mof. Try examining one of them now:
    ```powershell
        Get-Content ./MyFirstConfig/DSCWeb01.mof
    ```
    > Notice the complexity of the produced file. Would you have been able to write this on your own without syntax issues?

Continue with [Exercise2](Exercise2.md) when you are ready!