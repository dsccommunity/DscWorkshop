$tfsServer = Get-LabVM -Role Tfs2018
$artifactsShareName = 'Artifacts'
$artifactsSharePath = "C:\$artifactsShareName"

Invoke-LabCommand -ActivityName 'Create Aftifacts Share' -ComputerName $tfsServer -ScriptBlock {
    Install-Module -Name NTFSSecurity -Repository PowerShell
    mkdir -Path C:\Artifacts
    
    New-SmbShare -Name Artifacts -Path C:\Artifacts -FullAccess Everyone
    Add-NTFSAccess -Path C:\Artifacts -Account Everyone -AccessRights FullControl
}

# Create a new release pipeline
# Get those build steps from Get-LabBuildStep
$buildSteps = @(
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
            arguments           = "-ResolveDependency -GalleryRepository PowerShell"
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
        alwaysRun       = $falsecls
        displayName     = 'Publish Artifact: MOFs'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)\BuildOutput\MOF' # Type: filePath, Default: , Mandatory: True
            ArtifactName = 'MOF' # Type: string, Default: , Mandatory: True
            ArtifactType = 'FilePath' # Type: pickList, Default: , Mandatory: True
            TargetPath = '\\{0}\{1}\$(Build.DefinitionName)\$(Build.BuildNumber)' -f $tfsServer, $artifactsShareName
        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $falsecls
        displayName     = 'Publish Artifact: Meta MOFs'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)\BuildOutput\MetaMof' # Type: filePath, Default: , Mandatory: True
            ArtifactName = 'MOF' # Type: string, Default: , Mandatory: True
            ArtifactType = 'FilePath' # Type: pickList, Default: , Mandatory: True
            TargetPath = '\\{0}\{1}\$(Build.DefinitionName)\$(Build.BuildNumber)' -f $tfsServer, $artifactsShareName
        }
    }
    @{
        enabled         = $true
        continueOnError = $false
        alwaysRun       = $falsecls
        displayName     = 'Publish Artifact: CompressedModules'
        task            = @{
            id          = '2ff763a7-ce83-4e1f-bc89-0ae63477cebe'
            versionSpec = '*'
        }
        inputs          = @{
            PathtoPublish = '$(Build.SourcesDirectory)\BuildOutput\CompressedModules' # Type: filePath, Default: , Mandatory: True
            ArtifactName = 'MOF' # Type: string, Default: , Mandatory: True
            ArtifactType = 'FilePath' # Type: pickList, Default: , Mandatory: True
            TargetPath = '\\{0}\{1}\$(Build.DefinitionName)\$(Build.BuildNumber)' -f $tfsServer, $artifactsShareName
        }
    }
)

# Which will make use of TFS, clone the stuff, add the necessary build step, publish the test results and so on
# You will see two remotes, Origin (Our code on GitHub) and TFS (Our code pushed to your lab)
Write-ScreenInfo 'Creating TFS project and cloning from GitHub...' -NoNewLine
New-LabReleasePipeline -ProjectName DscWorkshop -SourceRepository https://github.com/AutomatedLab/DscWorkshop -BuildSteps $buildSteps

<#
THIS IS REMOVED DUE TO A POSSIBLE BUG IN GIT.EXE

        Push-Location
        cd "$labSources\GitRepositories\$((Get-Lab).Name)\DscWorkshop"
        git checkout master 2>&1 | Out-Null
        git pull origin master 2>&1 | Out-Null

        Write-Host 'Starting git push to TFS'
        $retryCount = 20
        $pushResult = git -c http.sslverify=false push tfs 2>&1
        do
        {
        Write-Host "failed, retrying (RetryCount = $retryCount)"
        $pushResult = git -c http.sslverify=false push tfs 2>&1
        $retryCount--
        Start-Sleep -Seconds 2
        }
        until ($pushResult -like '*Everything up-to-date*' -or $retryCount -le 0)
        Write-Host 'Finished git push to TFS'

        Pop-Location
#>
Write-ScreenInfo done

# in case you screw something up
Checkpoint-LabVM -All -SnapshotName AfterPipeline
Write-Host "3. - Creating Snapshot 'AfterPipeline'" -ForegroundColor Magenta