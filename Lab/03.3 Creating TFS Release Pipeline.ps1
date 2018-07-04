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
            scriptName          = ".Build.ps1"
            arguments           = "-resolveDependency"
            failOnStandardError = $false
        }
    }
    @{
        enabled         = $True
        continueOnError = $False
        alwaysRun       = $False
        displayName     = 'Publish test results' # e.g. Publish Test Results $(testResultsFiles) or Publish Test Results
        task            = @{
            id          = '0b0f01ed-7dde-43ff-9cbb-e48954daf9b1'
            versionSpec = '*'
        }
        inputs          = @{
            testRunner       = 'NUnit' # Type: pickList, Default: JUnit, Mandatory: True
            testResultsFiles = '**/testresults.xml' # Type: filePath, Default: **/TEST-*.xml, Mandatory: True

        }
    }
)

# Which will make use of TFS, clone the stuff, add the necessary build step, publish the test results and so on
# You will see two remotes, Origin (Our code on GitHub) and TFS (Our code pushed to your lab)
Write-ScreenInfo 'Creating TFS project and cloning from GitHub...' -NoNewLine
New-LabReleasePipeline -ProjectName PSConfEU2018 -SourceRepository https://github.com/AutomatedLab/DscWorkshop -BuildSteps $buildSteps
Push-Location
cd "$labSources\GitRepositories\psconf18\DscWorkshop"
git checkout master 2>&1 | Out-Null
git pull origin master 2>&1 | Out-Null
git -c http.sslverify=false push tfs 2>&1 | Out-Null
Pop-Location
Write-ScreenInfo done

# in case you screw something up
Checkpoint-LabVM -All -SnapshotName AfterPipeline
Write-Host "3. - Creating Snapshot 'AfterPipeline'" -ForegroundColor Magenta
#endregion