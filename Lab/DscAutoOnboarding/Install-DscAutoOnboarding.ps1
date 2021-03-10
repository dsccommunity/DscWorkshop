$devOpsServer = Get-LabVM -Role AzDevOps

Write-Host "Creating Active Directory group 'DscAutoOnboarding'"
& $PSScriptRoot\New-AdDscAutoOnboardingGroup.ps1 -DevOpsServer $devOpsServer

Invoke-LabCommand -ActivityName "Creating DSC JEA Service Endpoint on '$devOpsServer'" -ComputerName $devOpsServer -FilePath $PSScriptRoot\New-DscAutoOnboardingEndpoint.ps1
