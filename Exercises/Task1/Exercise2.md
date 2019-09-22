# Task 1

Desired State Configuration has been introduced with Windows Management Framework 4 and has been improved in WMF5.1. DSC gives administrators the necessary tools to generate configuration files, called MOF files, that machines can consume.

## Exercise 2

Now that you have created you first MOF file, let's see how Windows can enact it.

>**Note: Before going on with the exercise, make sure your computer is not configured with DSC already. Then doing the next steps can break something. Please run the command ```Get-DscConfiguration```. If it returns the error 'Current configuration does not exist', then you are fine to continue.**

1. Inside PowerShell, move into the folder where you MOF file was created in (for example 'C:\DSC'). The call the following command:

    ```powershell
    Start-DscConfiguration -Path C:\DSC -Verbose -Wait
    ```

    This command is no applying each configuration item to you local machine.

2. Have a closer look at the output of the last command. For each resource it starts with a test. After the test is ended, the DSC Local configuration manager calls the set. This happens, if the node has not yet converged to the desired state.

3. Please call the same command again and have a closer look at the output. As the two configuration items defined in the MOF file have been applied already, this time set method will be skipped as the test returns 'true'.

4. You can always test wether a node is in the desired state by calling the command ```Test-DscConfiguration```. Especially the 'Detailed' switch makes the output more informative. Please run the command, then change the contents of the test file and run ```Test-DscConfiguration -Detailed``` again.

5. To reset your machine back into the previous state, it is not enough to remove the test folder. DSC would just recreate it, as we have learned. Please remove the folder and the DSC configuration like this:

    ```powershell
    Remove-Item -Path C:\TestFolder\ -Recurse -Force
    Remove-Item -Path C:\DSC\ -Recurse -Force
    Remove-DscConfigurationDocument -Stage Current, Pending, Previous
    ```

Continue with [Exercise3](Exercise3.md) when you are ready.
