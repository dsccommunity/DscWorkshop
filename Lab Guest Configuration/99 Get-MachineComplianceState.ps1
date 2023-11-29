#Get-AzPolicyAssignment -Scope $resourceGroup.ResourceId
$subscriptionId = '<SubscriptionId>'
$resourceGroupName = '<ResourceGroupName>'
$machineName = '<MachineName>'

$uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/virtualMachines/$machineName/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments?api-version=2022-01-25"

Invoke-AzRestMethod -Method GET -Uri $uri | Select-Object -ExpandProperty content | ConvertFrom-Json |
    Select-Object -ExpandProperty value |
        Format-Table Name,
        @{
            Name       = 'AssignmentType'
            Expression = { $PSItem.properties.guestConfiguration.assignmentType }
        },
        @{
            Name       = 'LastComplianceStatusChecked'
            Expression = { $PSItem.properties.lastComplianceStatusChecked }
        },
        @{
            Name       = 'ComplianceStatus'
            Expression = { $PSItem.properties.complianceStatus }
        },
        @{
            Name       = 'Version'
            Expression = { $PSItem.properties.guestConfiguration.version }
        }
