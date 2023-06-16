Get-AzVM -ResourceGroupName GCLab1 | ForEach-Object {
    Get-AzPolicyAssignment -Scope $_.Id | Remove-AzPolicyAssignment
}

Get-AzPolicyDefinition | Where-Object Name -like dsc* | Remove-AzPolicyDefinition -Force
