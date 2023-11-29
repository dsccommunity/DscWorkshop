#Requires -Modules AutomatedLab, Az.Resources, Az.ManagedServiceIdentity

<#
.SYNOPSIS
This script customizes the Azure Guest Configuration lab environment.

.NOTES
This script requires the AutomatedLab, Az.Resources, and Az.ManagedServiceIdentity PowerShell modules to be installed.

.EXAMPLE
.\20 Azure Guest Configuration Lab Customizations.ps1

This example customizes the Azure Guest Configuration lab environment.

#>

if (-not $lab)
{
    $lab = Import-Lab -Name GCLab1 -NoValidation -PassThru
}

Get-LabVM | ForEach-Object {

    Write-Host "Assigning system assigned identity to virtual machine '$($_.Name)'"
    $vm = Get-AzVM -Name $_.Name -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName
    Update-AzVM -VM $vm -IdentityType SystemAssigned -ResourceGroupName $vm.ResourceGroupName | Out-Null

    Write-Host "Installing Guest Configuration extension on virtual machine '$($_.Name)'"
    $param = @{
        Publisher = 'Microsoft.GuestConfiguration'
        ExtensionType = 'ConfigurationforWindows'
        Name = 'AzurePolicyforWindows'
        TypeHandlerVersion = '1.0'
        ResourceGroupName = $vm.ResourceGroupName
        Location = $vm.Location
        VMName = $vm.Name
        EnableAutomaticUpgrade = $true
    }
    Set-AzVMExtension @param | Out-Null
}

Write-Host "Creating user assigned identity for remediation '$($lab.Name)_Remediation'"
New-AzUserAssignedIdentity -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup -Name "$($lab.Name)_Remediation" -Location $lab.AzureSettings.DefaultLocation
Start-Sleep -Seconds 10
$managedIdentity = Get-AzADServicePrincipal -DisplayName "$($lab.Name)_Remediation"

Write-Host "Assigning role 'Contributor' to user assigned identity '$($managedIdentity.DisplayName)'"
New-AzRoleAssignment -ObjectId $managedIdentity.Id -RoleDefinitionName Contributor -Scope $lab.AzureSettings.DefaultResourceGroup.ResourceId
Write-Host "Assigning role 'Guest Configuration Resource Contributor' to user assigned identity '$($managedIdentity.DisplayName)'"
New-AzRoleAssignment -ObjectId $managedIdentity.Id -RoleDefinitionName 'Guest Configuration Resource Contributor' -Scope $lab.AzureSettings.DefaultResourceGroup.ResourceId
