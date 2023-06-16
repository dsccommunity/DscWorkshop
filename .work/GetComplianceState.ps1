#Get-AzPolicyAssignment -Scope $resourceGroup.ResourceId
$subscriptionId = 'da78bd51-11ab-418d-8222-db661c2aa8d9'
$resourceGroupName = 'GCLab1'
$machineName = 'DSCFile03'

$uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$machineName/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments?api-version=2022-01-25"

Invoke-AzRestMethod -Method GET -Uri $uri | Select-Object -ExpandProperty content | ConvertFrom-Json |
    Select-Object -ExpandProperty value |
        Format-Table Name,
            @{ Name = 'AssignmentType'; Expression = { $PSItem.properties.guestConfiguration.assignmentType } },
            @{ Name = 'LastComplianceStatusChecked'; Expression = { $PSItem.properties.lastComplianceStatusChecked } },
            @{ Name = 'ComplianceStatus'; Expression = { $PSItem.properties.complianceStatus } },
            @{ Name = 'Version'; Expression = { $PSItem.properties.guestConfiguration.version } }
