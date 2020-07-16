$devOpsServer = Get-LabVM -Role AzDevOps

Write-Host "Creating Active Directory group 'DscAutoJoin'"
& $PSScriptRoot\New-AdDscAutoJoinGroup.ps1

Write-Host "Creating DSC JEA Service Endpoint on '$devOpsServer'"
& $PSScriptRoot\New-DscAutoJoinEndpoint.ps1 -DevOpsServer $devOpsServer
