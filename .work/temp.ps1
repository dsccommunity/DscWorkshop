#Get-AzPolicyAssignment -Scope $resourceGroup.ResourceId

$uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$machineName/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments?api-version=2022-01-25"
$uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments?api-version=2022-01-25"
Invoke-AzRestMethod -Method GET -Uri $uri | Select-Object -ExpandProperty content | ConvertFrom-Json |
    Select-Object -ExpandProperty value |
        Format-Table name, @{n = 'assignmentType'; e = { $PSItem.properties.guestConfiguration.assignmentType } }, @{n = 'lastComplianceStatusChecked'; e = { $PSItem.properties.lastComplianceStatusChecked } }#,@{n='configurationSetting';e={$PSItem.properties.guestConfiguration.configurationSetting}}

# Assign policy to resource group containing Azure Arc lab servers
$ResourceGroup = Get-AzResourceGroup -Name 'azure-jumpstart-arcbox-rg'
$Policy = Get-AzPolicyDefinition | Where-Object { $PSItem.Properties.DisplayName -eq '[Windows]Ensure 7-Zip is installed' }
$PolicyParameterObject = @{'IncludeArcMachines' = 'True' } # <- IncludeArcMachines is important - given you want to target Arc as well as Azure VMs

New-AzPolicyAssignment -Name '[Windows]Ensure 7-Zip is installed' -PolicyDefinition $Policy -Scope $ResourceGroup.ResourceId -PolicyParameterObject $PolicyParameterObject -IdentityType SystemAssigned -Location westeurope -DisplayName '[Windows]Ensure7-Zip is installed'
