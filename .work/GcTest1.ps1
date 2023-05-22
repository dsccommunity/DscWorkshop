Set-AzContext -SubscriptionName 'S1 Contoso3'
$subscriptionId = (Get-AzContext).Subscription.Id

$resourceGroupName = 'GCLab1'
$storageAccountName = "$($resourceGroupName)sa1".ToLower()
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName
$guestConfigurationContainerName = 'guestconfiguration'

New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -Location $resourceGroup.Location -SkuName Standard_LRS -Kind StorageV2 -ErrorAction SilentlyContinue | Out-Null
$storageAccountKeys = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName
$storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKeys[0].Value
New-AzStorageContainer -Context $storageContext -Name guestconfiguration -Permission Blob -ErrorAction SilentlyContinue
$moduleVersion = '2.0.0'

$managedIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name GCLab1_Remediation

$gpPackages = Get-ChildItem -Path 'D:\DscWorkshop\output\GCPackages' -Filter '*.zip' -Recurse
foreach ($gpPackage in $gpPackages)
{
    $policyName = $gpPackage.BaseName.Split('_')[0]

    Set-AzStorageBlobContent -Container $guestConfigurationContainerName -File $gpPackage.FullName -Blob $gpPackage.Name -Context $storageContext -Force

    $contentUri = New-AzStorageBlobSASToken -Context $storageContext -FullUri -Container $guestConfigurationContainerName -Blob $gpPackage.Name -Permission rwd

    $params = @{
        PolicyId      = New-Guid
        ContentUri    = $contentUri
        DisplayName   = $policyName
        Description   = 'none'
        Path          = 'd:\dscworkshop\output\GPPolicies'
        Platform      = 'Windows'
        PolicyVersion = $moduleVersion
        Mode          = 'ApplyAndAutoCorrect'
        Verbose       = $true
    }

    $policy = New-GuestConfigurationPolicy @params

    $policyDefinition = New-AzPolicyDefinition -Name $policyName -Policy $Policy.Path

    $vm = Get-AzVM -Name $policyName -ResourceGroupName $resourceGroupName

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
