# Task 2 - The pipeline

*Estimated time to completion: 35 minutes*

This task assumes that you have access to `https://dev.azure.com` in order to create your own project and your own pipeline.  

*By the way: You can use the PowerShell module [AutomatedLab.Common](https://github.com/automatedlab/automatedlab.common) to automate your interactions with TFS,VSTS and Azure DevOps*

***Remember to check the [prerequisites](../CheckPrereq.ps1)!***

## Create a new build pipeline

> Note: In the exercise we do not use a YAML pipeline but the old graphical way of defining one. This way is better for learning how a pipeline can be defined and how things work. Later you surely want to switch to YAML.

Again, this step can easily be automated. If you are interested in how this may look like, take a look at the [project code](../../Lab/31%20New%20Release%20Pipeline%20CommonTasks.ps1) in either of the pipeline lab scripts. We are using a hashtable containing all build tasks and pass it to the cmdlets exposed by AutomatedLab.Common.

Our template approach consists of using a trusted, internal (i.e. private) gallery for PowerShell modules. Internal does not necessarily mean on-premises, but means a gallery that you trust in which is usually self-hosted.

In the previous exercise, you have created a new Azure DevOps project to collaborate on your infrastructure code. While this is not strictly necessary, CI tools like Azure DevOps add features like RBAC, a nice interface and boast huge flexibility.

>Info: To start small, just use ```git init [--bare]``` to create a repository you can collaborate in as well.*

To create your own build (Continuous Integration) pipeline, follow the next steps:

1. In your repository, on the left side click on `Pipelines -> Builds` and then on the button `Create Pipeline`.

1. Now you are asked: Where is your code? Please choose `Azure Repos Git`.

1. In the next menu select the repository that has the same name as your project. There should be shown just this single repository anyway.

1. The next step shows you the pipeline as it is part of the DscWorkshop project. The pipeline contains eight steps:

    1. Evaluate the next version using [GitVersion](https://gitversion.net/).

    1. Call the build script like you have done it locally before. As the build is running on a new worker with `ResolveDependency` must be used. This step runs only the build.

    1. The next step runs the pack task which is compressing the modules and previously created artifacts.

    1. The next tasks are just uploading the artifacts into the Azure DevOps database.

    > Note: At the very top of the pipeline definition, there is the section `trigger`. This enables continuous integration meaning that the build is started every time you do a change to any file in any branch. The only exception is if you only change the file `changelog.md`, this path is excluded.

1. Now, just click the `Run` button to kick off your first infrastructure build. The next page informs you about the current status of you job. Lie back and wait for the artifacts to be built.

    > Note: If you create and / or compile software on a dedicated development machine or your personal computer, you pile up a lot of dependencies: Programs, helper tools, DLLs, PowerShell modules, etc. All these things may be required to run you code. In the previous task we have introduced you to [PSDepend](https://github.com/RamblingCookieMonster/PSDepend). This helper module makes sure that we have all the dependencies downloaded that are defined in the `RequiredModules.psd1` file. If your software can be build on a standard build worker, it can be build everywhere and does not have any unwanted and undocumented dependencies.

1. Hopefully each build step is green. If the job is finished, you have the 'Artifacts' button in the upper right corner. Explore the build output a little while and move on to the next exercise once you are satisfied. Also quite interesting are the test results that you may want to examine.

    >Note: All successful tests are hidden, only failed ones are shown by default. Just remove the filter to get the full view.

Please continue with [Exercise 3](Exercise3.md) when your are ready.
