param (
    [Parameter()]
    [string]$LabName = 'DscWorkshop'
)

if ((Get-Lab -ErrorAction SilentlyContinue).Name -ne $LabName)
{
    try
    {
        Write-host "Importing lab '$LabName'"
        Import-Lab -Name $LabName -NoValidation -ErrorAction Stop
    }
    catch
    {
        Write-Host "Lab '$LabName' could not be imported. Trying to find a lab with a name starting with 'DscWorkshop*'"
        $possibleLabs = Get-Lab -List | Where-Object { $_ -like 'DscWorkshop*' }
        if ($possibleLabs.Count -gt 1)
        {
            Write-Error "There are multiple 'DscWorkshop' labs ($($possibleLabs -join ', ')). Please remove the ones you don't need."
            exit
        }
        else
        {
            Write-Host "Importing lab '$possibleLabs'"
            Import-Lab -Name $possibleLabs -NoValidation -ErrorAction Stop
        }
    }
}

$projectName = 'DscWorkshop'
$projectGitUrl = 'https://github.com/raandree/DscWorkshop'
$collectionName = 'AutomatedLab'

$lab = Get-Lab
$devOpsServer = Get-LabVM -Role AzDevOps
$devOpsHostName = if ($lab.DefaultVirtualizationEngine -eq 'Azure')
{
    $devOpsServer.AzureConnectionInfo.DnsName
}
else
{
    $devOpsServer.FQDN
}
$nugetServer = Get-LabVM -Role AzDevOps
$nugetFeed = Get-LabTfsFeed -ComputerName $nugetServer -FeedName PowerShell
$pullServer = Get-LabVM -Role DSCPullServer
$hypervHost = Get-LabVM -Role HyperV

$devOpsRole = $devOpsServer.Roles | Where-Object Name -Like AzDevOps
$devOpsCred = $devOpsServer.GetCredential($lab)

# Which will make use of Azure DevOps, clone the stuff, add the necessary build step, publish the test results and so on
# You will see two remotes, Origin (Our code on GitHub) and Azure DevOps (Our code pushed to your lab)
Write-ScreenInfo 'Creating Azure DevOps project and cloning from GitHub...' -NoNewLine

New-LabReleasePipeline -ProjectName $projectName -SourceRepository $projectGitUrl -CodeUploadMethod FileCopy

Invoke-LabCommand -ActivityName 'Set RepositoryUri and create Build Pipeline' -ScriptBlock {

    Set-Location -Path C:\Git\DscWorkshop
    git checkout main *>$null
    Remove-Item -Path '.\azure-pipelines.yml'
    (Get-Content -Path '.\azure-pipelines On-Prem.yml' -Raw) -replace 'RepositoryUri_WillBeChanged', $nugetFeed.NugetV2Url | Set-Content -Path .\azure-pipelines.yml
    (Get-Content -Path .\Resolve-Dependency.psd1 -Raw) -replace 'PSGallery', 'PowerShell' | Set-Content -Path .\Resolve-Dependency.psd1

    $content = [System.Collections.ArrayList](Get-Content -Path .\Resolve-Dependency.psd1)
    $content.Insert(3, '    AllowOldPowerShellGetModule = $true # this is still required because of dependencies not following semantic versioning')
    $content | Set-Content -Path .\Resolve-Dependency.psd1

    (Get-Content -Path .\RequiredModules.psd1 -Raw) -replace 'PSGallery', 'PowerShell' | Set-Content -Path .\RequiredModules.psd1
    git add .
    git commit -m 'Set RepositoryUri and create Build Pipeline'
    git push 2>$null

} -ComputerName $devOpsServer -Variable (Get-Variable -Name nugetFeed)

Write-ScreenInfo done

# in case you screw something up
Checkpoint-LabVM -All -SnapshotName AfterPipelines
Write-Host "3. - Creating Snapshot 'AfterPipelines'" -ForegroundColor Magenta
