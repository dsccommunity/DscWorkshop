# Task 2 - The pipeline

*Estimated time to completion: 35 minutes*

This task will guide you through the process of creating an infrastructure build and release pipeline. While the full project also creates a separate pipeline for the DSC Composite Resource module, the same principles apply so that we will concentrate on the build process of your IaaS workloads.  

This task assumes that you have access to dev.azure.com in order to create your own project and your own pipeline.  

*By the way: You can use the PowerShell module [AutomatedLab.Common](https://github.com/automatedlab/automatedlab.common) to automate your interactions with TFS,VSTS and Azure DevOps*

***Remember to check the [prerequisites](..\CheckPrereq.ps1)!***

## Create the release pipeline

While the build process is already a first important step towards infrastructure automation you can trust in, the CD bit of your pipeline is also important. The created artifacts should be automatically deployed to your infrastructure after all. By utilizing staging rings we can move the build artifacts securely through the infrastructure.

If you are using our on-premises lab script to try it on your own, the environment already contains an on-premises DSC pull server. Adapting this to use Azure Automation DSC or any other DSC pull server is trivial.

1. First of all, navigate to "Pipelines\Releases" on the right-hand side and select "New pipeline".
The template selection will pop up. Select "Empty job".

1. Once your pipeline is created, notice that the Artifacts are yet to be filled. Select "Add an artifact" and use the output of your build. A successful build will now trigger your pipeline.  
    ![This belongs in a museum](./img/AddArtifact.png)
3. Rename 'Stage 1' to 'Dev'. Add two additional stages (environemnts), called 'pilot' and 'production', each with an empty job.

The design of the pipeline depends very much on where it should operate. Your build steps might have included copying the files to an Azure blob storage instead of an on-premises file share. This would be the recommended way in case you want your Azure Automation DSC pull server to host the MOF files. The release step would be to execute New-AzAutomationModule with the URIs of your uploaded, compressed modules.

For now, we will only upload the MOF files to Azure Automation, but you can add a similar release task for uploading the modules for example.

1. Open your first stage, dev, and navigate to variables. For the dev stage, we want for example to deploy to the dev automation account. Variables you add here are available as environment variables. By selecting the appropriate scope, you can control the variable contents for each stage.  
    ![Variable overview](./img/ReleaseVariables.png)
2. Add a new 'Azure PowerShell' task. In the task select your subscription and authorize Azure DevOps to access your subscription.
    ![Task settings](./img/AutomationDscTask.png)
    Add the following inline script:  
    ```powershell
    if (Get-Command Enable-AzureRmAlias -ea silentlycontinue)
    {
        Enable-AzureRmAlias
    }

    foreach ( $config in (Get-ChildItem -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -Recurse -File -Filter *.mof | Where-Object -Property Name -notmatch "(meta|schema)\.mof"))
    {
        Import-AzureRmAutomationDscNodeConfiguration -ResourceGroupName $env:ResourceGroupname -AutomationAccountName $env:AutomationAccountName -Path $config.FullName -ConfigurationName $config.BaseName -Verbose -Force
    }
    ```  
    The simple script works with the artifacts from the build process and uploads them as new DSC configurations to your Azure Automation Account. This is only one of the many ways you could use your artifacts at this stage.  
    Another approach can be to actively push configurations out to all nodes to immediately receive feedback that could be consumed by Pester tests.

You can trigger a new release either manually or automatically after a build has successfully finished. If you have an automation account set up, you can try it out! Simply set up your build variables properly and observe.  

Congratulations! You have successfully created your first, very simple CI/CD pipeline to deploy your infrastructure as code. Now go on, make this project your own and help your company or your customers succeed!