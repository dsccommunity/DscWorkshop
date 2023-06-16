param
(
    [Parameter()]
    [string]
    $LocationName = 'West Europe',

    [Parameter()]
    [string]
    $SubscriptionName
)

New-LabDefinition -Name GCLab1 -DefaultVirtualizationEngine Azure

$param = @{
    DefaultLocationName = $LocationName
}
if ($SubscriptionName)
{
    $param.SubscriptionName = $SubscriptionName
}
Add-LabAzureSubscription @param

Add-LabDomainDefinition -Name contoso.com -AdminUser Install -AdminPassword Somepass1
Set-LabInstallationCredential -Username Install -Password Somepass1

$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:AzureRoleSize'   = 'Standard_D2ds_v4'
    'Add-LabMachineDefinition:DomainName'      = 'contoso.com'
}

$postInstallActivity = @()
$postInstallActivity += Get-LabPostInstallationActivity -ScriptFileName 'New-ADLabAccounts 2.0.ps1' -DependencyFolder $labSources\PostInstallationActivities\PrepareFirstChildDomain
$postInstallActivity += Get-LabPostInstallationActivity -ScriptFileName PrepareRootDomain.ps1 -DependencyFolder $labSources\PostInstallationActivities\PrepareRootDomain
Add-LabMachineDefinition -Name DSCDC01 -Roles RootDC -PostInstallationActivity $postInstallActivity

Add-LabMachineDefinition -Name DSCFile01 -Roles FileServer
Add-LabMachineDefinition -Name DSCWeb01 -Roles WebServer

Add-LabMachineDefinition -Name DSCFile02 -Roles FileServer
Add-LabMachineDefinition -Name DSCWeb02 -Roles WebServer

Add-LabMachineDefinition -Name DSCFile03 -Roles FileServer
Add-LabMachineDefinition -Name DSCWeb03 -Roles WebServer

Install-Lab

Checkpoint-LabVM -All -SnapshotName AfterInstall

Show-LabDeploymentSummary -Detailed
