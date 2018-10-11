$lab = Get-Lab
$tfsServer = Get-LabVM -Role Tfs2018
$tfsCred = $tfsServer.GetCredential($lab)

$tfsAgentQueue = Get-TfsAgentQueue -InstanceName $tfsServer -Port 8080 -Credential $tfsCred -ProjectName CommonTasks -CollectionName AutomatedLab -QueueName Default

# Create a new release pipeline
# Get those build steps from Get-LabBuildStep
$buildSteps = @(
    @{
        "enabled"         = $true
        "continueOnError" = $false
        "alwaysRun"       = $false
        "displayName"     = "Register PowerShell Gallery"
        "task"            = @{
            "id"          = "e213ff0f-5d5c-4791-802d-52ea3e7be1f1"
            "versionSpec" = "2.*"
        }
        "inputs"          = @{
            targetType          = "inline"
            scriptName          = ""
            arguments           = ""
            script              = @'
#always make sure the local PowerShell Gallery is registered correctly
$uri = 'http://dscpull01.contoso.com/nuget/PowerShell'
$name = 'PowerShell'
$r = Get-PSRepository -Name $name -ErrorAction SilentlyContinue
if (-not $r -or $r.SourceLocation -ne $uri -or $r.PublishLocation -ne $uri) {
    Write-Host "The Source or PublishLocation of the repository '$name' is not correct or the repository is not registered"
    Unregister-PSRepository -Name $name -ErrorAction SilentlyContinue
    Register-PSRepository -Name $name -SourceLocation $uri -PublishLocation $uri -InstallationPolicy Trusted
    Get-PSRepository
}
'@
            failOnStderr = $false
            errorActionPreference = 'stop'
        }
    }
    @{
        "enabled"         = $true
        "continueOnError" = $false
        "alwaysRun"       = $false
        "displayName"     = "Execute Build.ps1"
        "task"            = @{
            "id"          = "e213ff0f-5d5c-4791-802d-52ea3e7be1f1" # We need to refer to a valid ID - refer to Get-LabBuildStep for all available steps
            "versionSpec" = "*"
        }
        "inputs"          = @{
            scriptType          = "filePath"
            scriptName          = "Build.ps1"
            arguments           = "-ResolveDependency -GalleryRepository PowerShell -Tasks ClearBuildOutput, Init, SetPsModulePath, CopyModule, Test"
            failOnStandardError = $false
        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $false
        displayName     = 'Publish test results' # e.g. Publish Test Results $(testResultsFiles) or Publish Test Results
        task            = @{
            id          = '0b0f01ed-7dde-43ff-9cbb-e48954daf9b1'
            versionSpec = '*'
        }
        inputs          = @{
            testRunner       = 'NUnit' # Type: pickList, Default: JUnit, Mandatory: True
            testResultsFiles = '**/TestResults.xml' # Type: filePath, Default: **/TEST-*.xml, Mandatory: True

        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $false
        displayName     = 'Publish Artifact: $(Build.Repository.Name) Module'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)\BuildOutput\Modules\$(Build.Repository.Name)'
            ArtifactName = '$(Build.Repository.Name)'
            ArtifactType = 'Container'
        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $false
        displayName     = 'Publish Artifact: BuildFolder'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)'
            ArtifactName = 'SourcesDirectory'
            ArtifactType = 'Container'
        }
    }
)

$workflowTasks = @(
    @{
        taskId = '5bfb729a-a7c8-4a78-a7c3-8d717bb7c13c'
        version = '2.*'
        name = 'Copy Files to: Artifacte Share'
        refName = ''
        enabled = $true
        alwaysRun = $false
        continueOnError = $false
        timeoutInMinutes = 0
        definitionType = 'task'
        overrideInputs = @{}
        condition = 'succeeded()'
        inputs = @{
            SourceFolder = '$(System.DefaultWorkingDirectory)/$(Build.DefinitionName)/$(Build.Repository.Name)'
            Contents = '**'
            TargetFolder = '\\dsctfs01\Artifacts\$(Build.DefinitionName)\$(Build.BuildNumber)\$(Build.Repository.Name)'
            CleanTargetFolder = $false
            OverWrite = $false
            flattenFolders = $false
        }
    }
    @{
        taskId = 'e213ff0f-5d5c-4791-802d-52ea3e7be1f1'
        version = '1.*'
        name = 'Execute Build.ps1 for Deployment'
        refName = ''
        enabled = $true
        alwaysRun = $false
        continueOnError = $false
        timeoutInMinutes = 0
        definitionType = 'task'
        overrideInputs = @{}
        condition = 'succeeded()'
        inputs = @{
            scriptType = 'inlineScript'
            scriptName = ''
            arguments = ''
            workingFolder = ''
            inlineScript = @'
Write-Host $(System.DefaultWorkingDirectory)
cd $(System.DefaultWorkingDirectory)\$(Build.DefinitionName)\SourcesDirectory
.\Build.ps1 -Tasks Init, SetPsModulePath, Deploy -GalleryRepository PowerShell'
'@
            failOnStandardError = $false
        }
    }
)

$releaseEnvironments = @(
    @{
        id = 3
        name = "Dev"
        rank = 1
        owner = @{
            displayName = 'Install'
            #url": "http://dsctfs01:8080/AutomatedLab/_apis/Identities/196672db-49dd-4968-8c52-a94e43186ffd",
            #_links": { "avatar": { "href": "http://dsctfs01:8080/AutomatedLab/_api/_common/identityImage?id=196672db-49dd-4968-8c52-a94e43186ffd" } },
            id = '196672db-49dd-4968-8c52-a94e43186ffd'
            uniqueName = 'contoso\Install'
            #imageUrl": "http://dsctfs01:8080/AutomatedLab/_api/_common/identityImage?id=196672db-49dd-4968-8c52-a94e43186ffd"
        }
        #"variables": {},
        #"variableGroups": [],
        preDeployApprovals = @{
            approvals = @(
                @{
                    rank = 1
                    isAutomated = $true
                    isNotificationOn = $false
                    id = 7
                }
            )
            #"approvalOptions": {
            #  "requiredApproverCount": null,
            #  "releaseCreatorCanBeApprover": false,
            #  "autoTriggeredAndPreviousEnvironmentApprovedCanBeSkipped": false,
            #  "enforceIdentityRevalidation": false,
            #  "timeoutInMinutes": 0,
            #  "executionOrder": 1
            #}
        }
        deployStep = @{ id = 10 }
        postDeployApprovals = @{
            approvals = @(
                @{
                    rank = 1
                    isAutomated = $true
                    isNotificationOn = $false
                    id = 11
                }
            )
            #    "approvalOptions": {
            #        "requiredApproverCount": null,
            #        "releaseCreatorCanBeApprover": false,
            #        "autoTriggeredAndPreviousEnvironmentApprovedCanBeSkipped": false,
            #        "enforceIdentityRevalidation": false,
            #        "timeoutInMinutes": 0,
            #        "executionOrder": 2
            #    }
        }
        deployPhases = @(
            @{
                deploymentInput = @{
                    parallelExecution = @{ parallelExecutionType = 'none' }
                    skipArtifactsDownload = $false
                    artifactsDownloadInput = @{ downloadInputs = $() }
                    queueId = $tfsAgentQueue.id
                    demands = @()
                    enableAccessToken = $false
                    timeoutInMinutes = 0
                    jobCancelTimeoutInMinutes = 1
                    condition = 'succeeded()'
                    overrideInputs = @{}
                }
                rank = 1
                phaseType = 1
                name = 'Run on agent'
                workflowTasks = $workflowTasks
            }
        )
        environmentOptions = @{
            emailNotificationType = 'OnlyOnFailure'
            emailRecipients = 'release.environment.owner;release.creator'
            skipArtifactsDownload = $false
            timeoutInMinutes = 0
            enableAccessToken = $false
            publishDeploymentStatus = $false
            badgeEnabled = $false
            autoLinkWorkItems = $false
        }
        demands = @()
        conditions = @(
            @{
                name = 'ReleaseStarted'
                conditionType = 1
                value = ''
            }
        )
        executionPolicy = @{
            concurrencyCount = 0
            queueDepthCount = 0
        }
        schedules = @()
        retentionPolicy = @{
            daysToKeep = 30
            releasesToKeep = 3
            retainBuild = $true
        }
        processParameters = @{}
        properties = @{}
        preDeploymentGates = @{
            id = 0
            gatesOptions = $null
            gates = @()
        }
        postDeploymentGates = @{
            id = 0
            gatesOptions = $null
            gates = @()
        }
        badgeUrl = "http://dsctfs01:8080/AutomatedLab/_apis/public/Release/badge/4e69800e-ce3f-45fa-a99b-95c0885417b0/3/3"
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
New-LabReleasePipeline -ProjectName CommonTasks -SourceRepository https://github.com/AutomatedLab/CommonTasks -BuildSteps $buildSteps -CodeUploadMethod FileCopy


New-TfsReleaseDefinition -ProjectName CommonTasks -InstanceName $tfsServer -Port 8080 -ReleaseName abc -Environments $releaseEnvironments -Credential $tfsCred -CollectionName AutomatedLab
Write-ScreenInfo done

# in case you screw something up
#Checkpoint-LabVM -All -SnapshotName AfterPipeline
Write-Host "3. - Creating Snapshot 'AfterPipeline'" -ForegroundColor Magenta