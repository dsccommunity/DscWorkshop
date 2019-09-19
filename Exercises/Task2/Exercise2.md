# Task 2 - The build

*Estimated time to completion: 30-60 minutes*

To kick off a new build, the script 'Build.ps1' is going to be used. Whether or not you are in a build pipeline, the build script will create all artifacts in your current environment.

***Remember to check the [prerequisites](../CheckPrereq.ps1)!***

## Create a new build pipeline

Again, this step can easily be automated. ~~If you are interested in how this may look like, take a look at the [project code](../../Lab/31%20New%20Release%20Pipleine%20CommonTasks.ps1) in either of the pipeline lab scripts. We are using a hashtable containing all build tasks and pass it to the cmdlets exposed by AutomatedLab.Common.~~

Our template approach consists of using a trusted, internal (i.e. private) gallery for PowerShell modules. Internal does not necessarily mean on-premises, but means a gallery that you trust in which is usually self-hosted.

In the previous exercise, you have created a new Azure DevOps project to collaborate on your infrastructure code. While this is not strictly necessary, CI tools like Azure DevOps add features like RBAC, a nice interface and boast huge flexibility.

>Info: To start small, just use ```git init [--bare]``` to create a repository you can collaborate in as well.*

To create your own build (Continuous Integration) pipeline, follow the next steps:

1. In your repository, on the left side click on Pipelines -> Builds and then on the button 'New pipeline'.

2. Now you are asked: Where is your code? Please choose 'Other Git'.

3. The next menu lets you 'Select a source'. Please select 'Azure Repos Git'. The required information will be added automatically. Please switch the 'Default branch for manual and scheduled builds' to 'dev' and press the 'Continue' button.

4. On the "Select a template" page, select the "Empty job" right on the very top of the page.

You have created an empty pipeline now. The next tasks will give the pipeline some work to do.

Our build process can run on the hosted agent. A build agent is just a small service/daemon running on a VM that is capable of executing scripts and so on.

On premises, you might want to select a dedicated agent pool for DSC configuration compilation jobs for example.

5. Add the first agent job by clicking the plus icon next to 'Agent job 1'. From the list of tasks, select PowerShell and make sure that the following settings are correct:
    - Display name: Execute build.ps1
    - Type: Inline
    - Script: .\Build.ps1 -ResolveDependency
    - Working Directory: DSC

    ![Build task](./img/ExecuteBuild.png)

6. Next, we would like to publish all test results. In the last task you have triggered a manual build and saw the test cases that were executed. On each build an NUnit XML file is generated that Azure DevOps can pick up. To do so, add another agent task of the type "Publish Test Results". Make sure that it is configured to use NUnit and to pick up the correct file: ```**/IntegrationTestResults.xml```.

## 2.2 Add a new node

You are tasked with on-boarding a new node (DSCFile04) to your environment. The node should be a file server (Role) in your branch office in Singapore (Location). You also know that it should be part of the Pilot servers or canaries that receive new DSC configurations before other production servers.

1. Make a copy of DSCFile02.yml (use as a template) inside the folder 'DSC\DscConfigData\AllNodes\Pilot' and call it 'DSCFile04.yml'. This new yml will represent your new node. You can do this in the VSCode (mark the file and press CTRL+C and then CTRL+V. Rename the new file) or you can use this PowerShell command.

    ```powershell
    Copy-Item -Path .\DscConfigData\AllNodes\Pilot\DSCFile02.yml -Destination .\DscConfigData\AllNodes\Pilot\DscFile04.yml
    ```

2. Open the newly created file and modify the properties NodeName, Location, Description and ConfigurationNames with the below values.
  *Please note that outside of a workshop environment, this step can easily be scripted to e.g. use a CMDB as the source for new nodes*

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
