Write-Host '------------------- Installing DscAutoOboarding Feature -------------------'
Write-Host '1. Creating an Active Directory Group whos members have permission to'
Write-Host '   request Document Encryption Certificates.'
Write-Host '2. Creating a DSC JEA Service Endpoint on the DevOps VM.'
Write-Host '3. Removing DSC Nodes from Configuartion Data to allow them getting'
Write-Host '   onboarded using DscAutoOboarding.'
Write-Host '4. Copying the DscAutoOboarding scripts to all VMs to be onboarded.'

& $PSScriptRoot\DscAutoOnboarding\Install-DscAutoOnboarding.ps1

$devOpsServer = Get-LabVM -Role AzDevOps
$dscNodes = Get-LabVM -Filter { $_.Name -like 'DSCFile*' -or $_.Name -like 'DSCWeb*' }
Copy-LabFileItem -Path $PSScriptRoot\DscAutoOnboarding\Start-DscAutoOnboarding.ps1 -ComputerName $dscNodes -DestinationFolderPath C:\DscAutoOnboarding
Copy-LabFileItem -Path $PSScriptRoot\DscAutoOnboarding\DscConfigs -ComputerName $dscNodes -DestinationFolderPath C:\DscAutoOnboarding

Invoke-LabCommand -ActivityName "Removing DSC nodes from config data for onboarding them using 'DscAutoOnboardingEndpoint'" -ScriptBlock {

    $temp = "C:\$([System.Guid]::NewGuid())"
    mkdir -Path $temp | Out-Null
    git clone https://contoso\install:Somepass1@dscdo01:8080/AutomatedLab/DscWorkshop/_git/DscWorkshop $temp 2>&1 | Out-Null
    Push-Location -Path $temp

    Rename-Item .\DSC\DscConfigData\AllNodes\ -NewName BackupAllNodes   
    git add .
    git commit -m "Removed all DSC demo nodes for 'DscAutoOnboardingEndpoint' by renaming 'AllNodes' folder" | Out-Null
    $result = git push 2>&1

    Pop-Location
    Remove-Item -Path $temp -Recurse -Force

} -ComputerName $devOpsServer

Write-Host '--------------- Finished Installing DscAutoOboarding Feature --------------'
