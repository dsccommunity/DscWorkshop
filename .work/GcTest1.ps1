Set-AzContext -SubscriptionName 'S1 Contoso3'
$subscriptionId = (Get-AzContext).Subscription.Id

$resourceGroupName = 'GCLab1'
$storageAccountName = "$($resourceGroupName)sa1".ToLower()
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName
$guestConfigurationContainerName = 'guestconfiguration'
$path = 'D:\DscWorkshop\output\GCPackages\UserAmyPresent_2.0.0.zip'
$policyName = (Get-Item -Path $path).BaseName.Split('_')[0]

New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -Location $resourceGroup.Location -SkuName Standard_LRS -Kind StorageV2 -ErrorAction SilentlyContinue | Out-Null
$storageAccountKeys = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKeys[0].Value

New-AzStorageContainer -Context $storageContext -Name guestconfiguration -Permission Blob -ErrorAction SilentlyContinue
Set-AzStorageBlobContent -Container $guestConfigurationContainerName -File $path -Blob (Get-Item -Path $path).Name -Context $storageContext -Force

$contentUri = New-AzStorageBlobSASToken -Context $storageContext -FullUri -Container $guestConfigurationContainerName -Blob (Get-Item -Path $path).Name -Permission rwd

$params = @{
    PolicyId      = New-Guid
    ContentUri    = $contentUri
    DisplayName   = (Get-Item -Path $path).BaseName
    Description   = 'none'
    Path          = '.\output\GCPolicies'
    Platform      = 'Windows'
    PolicyVersion = '1.1.0'
    Mode          = 'ApplyAndAutoCorrect'
    Verbose       = $true
}

$policy = New-GuestConfigurationPolicy @params

$policyDefinition = New-AzPolicyDefinition -Name $policyName -Policy $Policy.Path

$managedIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name GCLab1_Remediation
$vms = Get-AzVM -ResourceGroupName $resourceGroupName

foreach ($vm in $vms)
{
    $param = @{
        Name             = $policyName
        DisplayName      = $policyDefinition.Properties.DisplayName
        Scope            = $vm.Id
        PolicyDefinition = $policyDefinition
        Location         = 'uksouth'
        IdentityType     = 'UserAssigned'
        IdentityId       = $managedIdentity.Id
    }
    $assignment = New-AzPolicyAssignment @param

    $param = @{
        Name                  = "$($policyName)Remediation"
        PolicyAssignmentId    = $assignment.PolicyAssignmentId
        Scope                 = $vm.Id
        ResourceDiscoveryMode = 'ReEvaluateCompliance'
    }
    Start-AzPolicyRemediation @param
}
Get-AzPolicyAssignment -Scope $resourceGroup.ResourceId


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
