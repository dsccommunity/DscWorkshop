if (-not (Get-Lab -ErrorAction SilentlyContinue).Name -eq 'DscWorkshop') {
    Import-Lab -Name DscWorkshop -NoValidation -ErrorAction Stop
}

$projectName = 'DscWorkshop'
$projectGitUrl = 'https://github.com/raandree/DscWorkshop'
$collectionName = 'AutomatedLab'

$lab = Get-Lab
$devOpsServer = Get-LabVM -Role AzDevOps
$devOpsHostName = if ($lab.DefaultVirtualizationEngine -eq 'Azure') { $devOpsServer.AzureConnectionInfo.DnsName } else { $devOpsServer.FQDN }
$nugetServer = Get-LabVM -Role AzDevOps
$nugetFeed = Get-LabTfsFeed -ComputerName $nugetServer -FeedName PowerShell
$pullServer = Get-LabVM -Role DSCPullServer
$hypervHost = Get-LabVM -Role HyperV

$devOpsRole = $devOpsServer.Roles | Where-Object Name -like AzDevOps
$devOpsCred = $devOpsServer.GetCredential($lab)
$devOpsPort = $originalPort = 8080
if ($devOpsRole.Properties.ContainsKey('Port')) {
    $devOpsPort = $devOpsRole.Properties['Port']
}
if ($lab.DefaultVirtualizationEngine -eq 'Azure') {
    $devOpsPort = (Get-LabAzureLoadBalancedPort -DestinationPort $devOpsPort -ComputerName $devOpsServer).Port
}

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
