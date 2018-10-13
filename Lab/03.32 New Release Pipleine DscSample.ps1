$tfsServer = Get-LabVM -Role Tfs2018
$sqlServer = Get-LabVM -Role SQLServer
$artifactsShareName = 'Artifacts'
$artifactsSharePath = "C:\$artifactsShareName"

Invoke-LabCommand -ActivityName 'Create Aftifacts Share' -ComputerName $tfsServer -ScriptBlock {
    Install-Module -Name NTFSSecurity -Repository PowerShell
    mkdir -Path $artifactsSharePath
    
    New-SmbShare -Name $artifactsShareName -Path $artifactsSharePath -FullAccess Everyone
    Add-NTFSAccess -Path $artifactsSharePath -Account Everyone -AccessRights FullControl
} -Variable (Get-Variable -Name artifactsShareName, artifactsSharePath)

# Create a new release pipeline
# Get those build steps from Get-LabBuildStep
$buildSteps = @(
    @{
        "enabled"         = $true
        "continueOnError" = $false
        "alwaysRun"       = $false
        "displayName"     = "Register PowerShell gallery"
        "task"            = @{
            "id"          = "e213ff0f-5d5c-4791-802d-52ea3e7be1f1"
            "versionSpec" = "*"
        }
        "inputs"          = @{
            scriptType          = "inlineScript"
            scriptName          = ""
            arguments           = ""
            inlineScript        = 'if (-not (Get-PSRepository -Name PowerShell -ErrorAction SilentlyContinue)) { Register-PSRepository -Name PowerShell -SourceLocation http://dscpull01.contoso.com/nuget/PowerShell -InstallationPolicy Trusted; Get-PSRepository }'
            failOnStandardError = $false
        }
    }
    @{
        "enabled"         = $true
        "continueOnError" = $false
        "alwaysRun"       = $false
        "displayName"     = "Execute Build.ps1"
        "task"            = @{
            "id"          = "e213ff0f-5d5c-4791-802d-52ea3e7be1f1"
            "versionSpec" = "*"
        }
        "inputs"          = @{
            scriptType          = "inlineScript"
            scriptName          = ""
            arguments           = ""
            inlineScript        = 'cd $(Build.SourcesDirectory)\DscSample; .\Build.ps1 -ResolveDependency -GalleryRepository PowerShell'
            failOnStandardError = $false
        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $false
        displayName     = 'Publish test results'
        task            = @{
            id          = '0b0f01ed-7dde-43ff-9cbb-e48954daf9b1'
            versionSpec = '*'
        }
        inputs          = @{
            testRunner       = 'NUnit'
            testResultsFiles = '**/TestResults.xml'

        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $false
        displayName     = 'Publish Artifact to Share: MOFs'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)\DscSample\BuildOutput\MOF'
            ArtifactName = 'MOFOnShare' 
            ArtifactType = 'FilePath'
            TargetPath = '\\{0}\{1}\$(Build.DefinitionName)\$(Build.BuildNumber)' -f $tfsServer, $artifactsShareName
        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $false
        displayName     = 'Publish Artifact to Share: Meta MOFs'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)\DscSample\BuildOutput\MetaMof'
            ArtifactName = 'MetaMofOnShare'
            ArtifactType = 'FilePath'
            TargetPath = '\\{0}\{1}\$(Build.DefinitionName)\$(Build.BuildNumber)' -f $tfsServer, $artifactsShareName
        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $false
        displayName     = 'Publish Artifact to Share: CompressedModules'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)\DscSample\BuildOutput\CompressedModules'
            ArtifactName = 'CompressedModulesOnShare'
            ArtifactType = 'FilePath'
            TargetPath = '\\{0}\{1}\$(Build.DefinitionName)\$(Build.BuildNumber)' -f $tfsServer, $artifactsShareName
        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $false
        displayName     = 'Publish Artifact: MOFs'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)\DscSample\BuildOutput\MOF'
            ArtifactName = 'MOF'
            ArtifactType = 'Container'
        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $false
        displayName     = 'Publish Artifact: Meta MOFs'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)\DscSample\BuildOutput\MetaMof'
            ArtifactName = 'MetaMof'
            ArtifactType = 'Container'
        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $false
        displayName     = 'Publish Artifact: CompressedModules'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)\DscSample\BuildOutput\CompressedModules'
            ArtifactName = 'CompressedModules'
            ArtifactType = 'Container'
        }
    }
)

$releaseSteps = @(
    @{
        enabled          = $true
        continueOnError  = $false
        alwaysRun        = $false
        timeoutInMinutes = 0
        definitionType   = 'task'
        version          = '*'
        name             = 'YOUR OWN DISPLAY NAME HERE' # e.g. Archive files $(message) or Archive Files
        taskid           = 'd8b84976-e99a-4b86-b885-4849694435b0'
        inputs           = @{
            rootFolder = '$(Build.SourcesDirectory)\BuildOutput\MOF' # Type: filePath, Default: $(Build.BinariesDirectory), Mandatory: True
            includeRootFolder = 'true' # Type: boolean, Default: true, Mandatory: True
            archiveType = 'VALUE' # Type: pickList, Default: default, Mandatory: True
            tarCompression = 'VALUE' # Type: pickList, Default: gz, Mandatory: False
            archiveFile = 'VALUE' # Type: filePath, Default: $(Build.ArtifactStagingDirectory)/$(Build.BuildId).zip, Mandatory: True
            replaceExistingArchive = 'VALUE' # Type: boolean, Default: true, Mandatory: True
        }
    }

)

# Which will make use of TFS, clone the stuff, add the necessary build step, publish the test results and so on
# You will see two remotes, Origin (Our code on GitHub) and TFS (Our code pushed to your lab)
Write-ScreenInfo 'Creating TFS project and cloning from GitHub...' -NoNewLine
New-LabReleasePipeline -ProjectName DscWorkshop -SourceRepository https://github.com/AutomatedLab/DscWorkshop -CodeUploadMethod FileCopy #-BuildSteps $buildSteps 

$repo = Get-TfsGitRepository -InstanceName $tfsServer -Port 8080 -CollectionName AutomatedLab -ProjectName Dscworkshop -Credential $tfsCred
$refs = (Invoke-RestMethod -Uri "http://dsctfs01:8080/AutomatedLab/_apis/git/repositories/{$($repo.id)}/refs?api-version=4.1" -Credential $tfsCred).value.name
New-TfsBuildDefinition -InstanceName $tfsServer -CollectionName AutomatedLab -Port 8080 -Credential $tfsCred -ProjectName DscWorkshop -DefinitionName DscWorkshopBuild -CiTriggerRefs $refs -BuildTasks $buildSteps

Write-ScreenInfo done

# in case you screw something up
#Checkpoint-LabVM -All -SnapshotName AfterPipeline
Write-Host "3. - Creating Snapshot 'AfterPipeline'" -ForegroundColor Magenta