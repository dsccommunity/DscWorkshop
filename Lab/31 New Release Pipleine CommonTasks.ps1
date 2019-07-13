$lab = Get-Lab
$tfsServer = Get-LabVM -Role Tfs2018
$tfsHostName = if ($lab.DefaultVirtualizationEngine -eq 'Azure') {$tfsServer.AzureConnectionInfo.DnsName} else {$tfsServer.FQDN}

$role = $tfsServer.Roles | Where-Object Name -like Tfs????
$tfsCred = $tfsServer.GetCredential($lab)
$tfsPort = $originalPort = 8080
if ($role.Properties.ContainsKey('Port'))
{
    $tfsPort = $role.Properties['Port']
}
if ($lab.DefaultVirtualizationEngine -eq 'Azure')
{
    $tfsPort = (Get-LabAzureLoadBalancedPort -DestinationPort $tfsPort -ComputerName $tfsServer).Port
}

$projectName = 'CommonTasks'
$projectGitUrl = 'https://github.com/AutomatedLab/CommonTasks'
$collectionName = 'AutomatedLab'

# Which will make use of TFS, clone the stuff, add the necessary build step, publish the test results and so on
# You will see two remotes, Origin (Our code on GitHub) and TFS (Our code pushed to your lab)
Write-ScreenInfo 'Creating TFS project and cloning from GitHub...' -NoNewLine

New-LabReleasePipeline -ProjectName $projectName -SourceRepository $projectGitUrl -CodeUploadMethod FileCopy
$tfsAgentQueue = Get-TfsAgentQueue -InstanceName $tfsHostName -Port $tfsPort -Credential $tfsCred -ProjectName $projectName -CollectionName $collectionName -QueueName Default -UseSsl -SkipCertificateCheck

#region Build and Release Definitions
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
            targetType = "inline"
            script     = @'
#always make sure the local PowerShell Gallery is registered correctly
$uri = '$(GalleryUri)'
$name = 'PowerShell'
$r = Get-PSRepository -Name $name -ErrorAction SilentlyContinue
if (-not $r -or $r.SourceLocation -ne $uri -or $r.PublishLocation -ne $uri) {
    Write-Host "The Source or PublishLocation of the repository '$name' is not correct or the repository is not registered"
    Unregister-PSRepository -Name $name -ErrorAction SilentlyContinue
    Register-PSRepository -Name $name -SourceLocation $uri -PublishLocation $uri -InstallationPolicy Trusted
    Get-PSRepository
}
'@
        }
    }
    @{
        "enabled"     = $true
        "displayName" = "Execute Build.ps1"
        "task"        = @{
            "id"          = "e213ff0f-5d5c-4791-802d-52ea3e7be1f1"
            "versionSpec" = "2.*"
        }
        "inputs"      = @{
            targetType = "filePath"
            filePath   = "Build.ps1"
            arguments  = '-ResolveDependency -GalleryRepository PowerShell -Tasks ClearBuildOutput, Init, SetPsModulePath, CopyModule, IntegrationTest'
        }
    }
    @{
        enabled     = $true
        displayName = 'Publish Integration Test Results'
        condition   = 'always()'
        task        = @{
            id          = '0b0f01ed-7dde-43ff-9cbb-e48954daf9b1'
            versionSpec = '*'
        }
        inputs      = @{
            testRunner       = 'NUnit'
            testResultsFiles = '**/IntegrationTestResults.xml'
            searchFolder     = '$(System.DefaultWorkingDirectory)'

        }
    }
    @{
        enabled     = $true
        displayName = 'Publish Artifact: $(Build.Repository.Name) Module'
        task        = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs      = @{
            PathtoPublish = '$(Build.SourcesDirectory)\BuildOutput\Modules\$(Build.Repository.Name)'
            ArtifactName  = '$(Build.Repository.Name)'
            ArtifactType  = 'Container'
        }
    }
    @{
        enabled     = $true
        displayName = 'Publish Artifact: BuildFolder'
        task        = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs      = @{
            PathtoPublish = '$(Build.SourcesDirectory)'
            ArtifactName  = 'SourcesDirectory'
            ArtifactType  = 'Container'
        }
    }
)

$releaseSteps = @(
    @{
        taskId    = '5bfb729a-a7c8-4a78-a7c3-8d717bb7c13c'
        version   = '2.*'
        name      = 'Copy Files to: Artifacte Share'
        enabled   = $true
        condition = 'succeeded()'
        inputs    = @{
            SourceFolder = '$(System.DefaultWorkingDirectory)/$(Build.DefinitionName)/$(Build.Repository.Name)'
            Contents     = '**'
            TargetFolder = '\\dsctfs01\Artifacts\$(Build.DefinitionName)\$(Build.BuildNumber)\$(Build.Repository.Name)'
        }
    }
    @{
        enabled = $true
        name    = 'Register PowerShell Gallery'        
        taskId  = 'e213ff0f-5d5c-4791-802d-52ea3e7be1f1'
        version = '2.*'
        inputs  = @{
            targetType = 'inline'
            script     = @'
#always make sure the local PowerShell Gallery is registered correctly
$uri = '$(GalleryUri)'
$name = 'PowerShell'
$r = Get-PSRepository -Name $name -ErrorAction SilentlyContinue
if (-not $r -or $r.SourceLocation -ne $uri -or $r.PublishLocation -ne $uri) {
    Write-Host "The Source or PublishLocation of the repository '$name' is not correct or the repository is not registered"
    Unregister-PSRepository -Name $name -ErrorAction SilentlyContinue
    Register-PSRepository -Name $name -SourceLocation $uri -PublishLocation $uri -InstallationPolicy Trusted
    Get-PSRepository
}
'@
        }
    }
    @{
        enabled = $true
        name    = "Print Environment Variables"
        taskid  = 'e213ff0f-5d5c-4791-802d-52ea3e7be1f1'
        version = '2.*'
        inputs  = @{
            targetType = "inline"
            script     = 'dir -Path env:'
        }
    }
    @{
        enabled = $true
        name    = "Execute Build.ps1 for Deployment"
        taskId  = 'e213ff0f-5d5c-4791-802d-52ea3e7be1f1'
        version = '2.*'
        inputs  = @{
            targetType = 'inline'
            script     = @'
Write-Host $(System.DefaultWorkingDirectory)
cd $(System.DefaultWorkingDirectory)\$(Build.DefinitionName)\SourcesDirectory
.\Build.ps1 -Tasks Init, SetPsModulePath, Deploy, TestBuildAcceptance -GalleryRepository PowerShell
'@
        }
    }
    @{
        enabled   = $true
        name      = 'Publish Build Acceptance Test Results'
        condition = 'always()'
        taskid    = '0b0f01ed-7dde-43ff-9cbb-e48954daf9b1'
        version   = '*'
        inputs    = @{
            testRunner       = 'NUnit'
            testResultsFiles = '**/BuildAcceptanceTestResults.xml'
            searchFolder     = '$(System.DefaultWorkingDirectory)'
        }
    }
)

$releaseEnvironments = @(
    @{
        id                  = 3
        name                = "PowerShell Repository"
        rank                = 1
        owner               = @{
            displayName = 'Install'
            id          = '196672db-49dd-4968-8c52-a94e43186ffd'
            uniqueName  = 'Install'
        }
        variables           = @{
            GalleryUri = @{ value = "http://dscpull01.contoso.com/nuget/PowerShell" }
        }
        preDeployApprovals  = @{
            approvals = @(
                @{
                    rank             = 1
                    isAutomated      = $true
                    isNotificationOn = $false
                    id               = 7
                }
            )
        }
        deployStep          = @{ id = 10 }
        postDeployApprovals = @{
            approvals = @(
                @{
                    rank             = 1
                    isAutomated      = $true
                    isNotificationOn = $false
                    id               = 11
                }
            )
        }
        deployPhases        = @(
            @{
                deploymentInput = @{
                    parallelExecution         = @{ parallelExecutionType = 'none' }
                    skipArtifactsDownload     = $false
                    artifactsDownloadInput    = @{ downloadInputs = $() }
                    queueId                   = $tfsAgentQueue.id
                    demands                   = @()
                    enableAccessToken         = $false
                    timeoutInMinutes          = 0
                    jobCancelTimeoutInMinutes = 1
                    condition                 = 'succeeded()'
                    overrideInputs            = @{}
                }
                rank            = 1
                phaseType       = 1
                name            = 'Run on agent'
                workflowTasks   = $releaseSteps
            }
        )
        environmentOptions  = @{
            emailNotificationType   = 'OnlyOnFailure'
            emailRecipients         = 'release.environment.owner;release.creator'
            skipArtifactsDownload   = $false
            timeoutInMinutes        = 0
            enableAccessToken       = $false
            publishDeploymentStatus = $false
            badgeEnabled            = $false
            autoLinkWorkItems       = $false
        }
        demands             = @()
        conditions          = @(
            @{
                name          = 'ReleaseStarted'
                conditionType = 1
                value         = ''
            }
        )
        executionPolicy     = @{
            concurrencyCount = 0
            queueDepthCount  = 0
        }
        schedules           = @()
        retentionPolicy     = @{
            daysToKeep     = 30
            releasesToKeep = 3
            retainBuild    = $true
        }
        processParameters   = @{}
        properties          = @{}
        preDeploymentGates  = @{
            id           = 0
            gatesOptions = $null
            gates        = @()
        }
        postDeploymentGates = @{
            id           = 0
            gatesOptions = $null
            gates        = @()
        }
    }
)
#endregion

$repo = Get-TfsGitRepository -InstanceName $tfsHostName -Port $tfsPort -CollectionName $collectionName -ProjectName $projectName -Credential $tfsCred -UseSsl -SkipCertificateCheck
$repo.remoteUrl = $repo.remoteUrl -replace $originalPort, $tfsPort

$param =  @{
    Uri = "https://$($tfsHostName):$tfsPort/$collectionName/_apis/git/repositories/{$($repo.id)}/refs?api-version=4.1"
    Credential = $tfsCred    
}
if ($PSVersionTable.PSEdition -eq 'Core')
{
    $param.Add('SkipCertificateCheck', $true)
}
$refs = (Invoke-RestMethod @param).value.name

New-TfsBuildDefinition -ProjectName $projectName -InstanceName $tfsHostName -Port $tfsPort -DefinitionName "$($projectName)Build" -CollectionName $collectionName -BuildTasks $buildSteps -Variables @{ GalleryUri = 'http://dscpull01.contoso.com/nuget/PowerShell' } -CiTriggerRefs $refs -Credential $tfsCred -ApiVersion 4.1 -UseSsl -SkipCertificateCheck

New-TfsReleaseDefinition -ProjectName $projectName -InstanceName $tfsHostName -Port $tfsPort -ReleaseName "$($projectName)Release" -Environments $releaseEnvironments -Credential $tfsCred -CollectionName $collectionName -UseSsl -SkipCertificateCheck
Write-ScreenInfo done
