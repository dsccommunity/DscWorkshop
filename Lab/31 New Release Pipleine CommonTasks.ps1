$lab = Get-Lab
$domain = $lab.Domains[0]
$devOpsServer = Get-LabVM -Role AzDevOps
$devOpsHostName = if ($lab.DefaultVirtualizationEngine -eq 'Azure') { $devOpsServer.AzureConnectionInfo.DnsName } else { $devOpsServer.FQDN }
$nugetServer = Get-LabVM -Role AzDevOps
$nugetFeed = Get-LabTfsFeed -ComputerName $nugetServer -FeedName PowerShell

$role = $devOpsServer.Roles | Where-Object Name -eq AzDevOps
$devOpsCred = $devOpsServer.GetCredential($lab)
$devOpsPort = $originalPort = 8080
if ($role.Properties.ContainsKey('Port'))
{
    $devOpsPort = $role.Properties['Port']
}
if ($lab.DefaultVirtualizationEngine -eq 'Azure')
{
    $devOpsPort = (Get-LabAzureLoadBalancedPort -DestinationPort $devOpsPort -ComputerName $devOpsServer).Port
}

$projectName = 'CommonTasks'
$projectGitUrl = 'https://github.com/AutomatedLab/CommonTasks'
$collectionName = 'AutomatedLab'

# Which will make use of Azure DevOps, clone the stuff, add the necessary build step, publish the test results and so on
# You will see two remotes, Origin (Our code on GitHub) and Azure DevOps (Our code pushed to your lab)
Write-ScreenInfo 'Creating Azure DevOps project and cloning from GitHub...' -NoNewLine

New-LabReleasePipeline -ProjectName $projectName -SourceRepository $projectGitUrl -CodeUploadMethod FileCopy
$tfsAgentQueue = Get-TfsAgentQueue -InstanceName $devOpsHostName -Port $devOpsPort -Credential $devOpsCred -ProjectName $projectName -CollectionName $collectionName -QueueName Default -UseSsl -SkipCertificateCheck

#region Release Definitions
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
            TargetFolder = '\\{0}\Artifacts\$(Build.DefinitionName)\$(Build.BuildNumber)\$(Build.Repository.Name)' -f $devOpsServer.FQDN
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
Write-Host "$(System.DefaultWorkingDirectory)"
Set-Location -Path "$(System.DefaultWorkingDirectory)\$(Build.DefinitionName)\SourcesDirectory"
.\Build.ps1 -Tasks Init, SetPsModulePath, Deploy, TestReleaseAcceptance -GalleryRepository PowerShell
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
            testResultsFiles = '**/AcceptanceTestResults.xml'
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
            GalleryUri = @{ value = $nugetFeed.NugetV2Url }
            NugetApiKey = @{ value = $nugetFeed.NugetApiKey }            
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

$repo = Get-TfsGitRepository -InstanceName $devOpsHostName -Port $devOpsPort -CollectionName $collectionName -ProjectName $projectName -Credential $devOpsCred -UseSsl -SkipCertificateCheck
$repo.remoteUrl = $repo.remoteUrl -replace $originalPort, $devOpsPort

$param =  @{
    Uri = "https://$($devOpsHostName):$devOpsPort/$collectionName/_apis/git/repositories/{$($repo.id)}/refs?api-version=4.1"
    Credential = $devOpsCred    
}
if ($PSVersionTable.PSEdition -eq 'Core')
{
    $param.Add('SkipCertificateCheck', $true)
}
$refs = (Invoke-RestMethod @param).value.name

Invoke-LabCommand -ActivityName 'Set GalleryUri and create Build Pipeline' -ScriptBlock {

    Set-Location -Path C:\Git\CommonTasks
    $c = Get-Content '.\azure-pipelines On-Prem.yml' -Raw
    $c = $c -replace '  GalleryUri: ggggg', "  GalleryUri: $($nugetFeed.NugetV2Url)"
    $c = $c -replace '  Domain: ddddd', "  Domain: $($nugetFeed.NugetCredential.GetNetworkCredential().Domain)"
    $c = $c -replace '  UserName: uuuuu', "  Username: $($nugetFeed.NugetCredential.GetNetworkCredential().UserName)"
    $c = $c -replace '  Password: ppppp', "  Password: $($nugetFeed.NugetCredential.GetNetworkCredential().Password)"
    $c | Set-Content '.\azure-pipelines.yml'
    git add .
    git commit -m 'Set GalleryUri and create Build Pipeline'
    git push 2>$null

} -ComputerName $devOpsServer -Variable (Get-Variable -Name nugetFeed)

New-TfsReleaseDefinition -ProjectName $projectName -InstanceName $devOpsHostName -Port $devOpsPort -ReleaseName "$($projectName) CD" -Environments $releaseEnvironments -Credential $devOpsCred -CollectionName $collectionName -UseSsl -SkipCertificateCheck

Write-ScreenInfo done
