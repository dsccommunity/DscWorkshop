# Task 1

Desired State Configuration has been introduced with Windows Management Framework 4 and has been improved in WMF5.1. DSC gives administrators the necessary tools to generate configuration files, called MOF files, that machines can consume.

## Exercise 1

1. Open Windows PowerShell ISE or another PowerShell Editor of your choice
2. DSC always starts with the configuration keyword. Much like a function, a configuration has a name and a body

    ```powershell
        configuration MyFirstConfig
        {

        }
    ```

3. Inside a configuration, there may be one or more node blocks. As this exercise is to work on the local machine, please add a node block for 'localhost'.

    ```powershell
        configuration MyFirstConfig
        {
            node localhost
            {

            }
        }
    ```

4. Each node can consume one or more resources. Let's try to control some files and folders with DSC by adding the following configuration items to the node:

    ```powershell
        configuration MyFirstConfig
        {
            node localhost
            {
                File Folder1
                {
                    DestinationPath = 'C:\TestFolder'
                    Type = 'Directory'
                    Ensure = 'Present'
                }

                File File1
                {
                    DestinationPath = 'C:\TestFolder\TestFile1'
                    Ensure = 'Present'
                    DependsOn = '[File]Folder1'
                    Type = 'File'
                    Contents = 'Hello World'
                }
            }
        }
    ```

    >**Note:** Most DSC resources can be set to 'Present' and 'Absent' by using the 'Ensure' parameter. Setting the parameter to 'Absent' will delete an item without further confirmation.

    >**Info:** The 'DependsOn' parameter is supported by all DSC resources and guarantees, that the used resources are called in the order as defined. Of course, it does not make sense to create a file in the test folder before the test folder exists.

5. In order to actually convert this code into something that the target machines can properly enact, you need to compile the configuration element into a MOF file.

    >Info: A configuration is pretty similar to a function. In the following script the configuration is called like a function at the very last line. The parameter 'OutputPath' defines where the MOF file shall be created.

    ```powershell
        configuration MyFirstConfig
        {
            node localhost
            {
                File Folder1
                {
                    DestinationPath = 'C:\TestFolder'
                    Type = 'Directory'
                    Ensure = 'Present'
                }

                File File1
                {
                    DestinationPath = 'C:\TestFolder\TestFile1'
                    Ensure = 'Present'
                    DependsOn = '[File]Folder1'
                    Type = 'File'
                    Contents = 'Hello World'
                }
            }
        }

        MyFirstConfig -OutputPath C:\DSC
    ```

6. Running the configuration has produced a MOF file that has the same name as the node block. Try examining one of them now with ```Get-Content``` or by opening the file in any editor:

    ```powershell
        Get-Content C:\DSC\MyFirstConfig\DSCWeb01.mof
    ```

    > Notice the complexity of the produced file. Would you have been able to write this on your own without syntax issues?

Continue with [Exercise2](Exercise2.md) when you are ready.
