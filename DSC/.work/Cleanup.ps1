#$computers = Get-ADComputer -Filter *
$nodes = 'DSCFile01.contoso.com', 'DSCFile02.contoso.com', 'DSCFile03.contoso.com', 'DSCWeb01.contoso.com', 'DSCWeb03.contoso.com', 'DSCWeb02.contoso.com'
$buildWorkers = 'DSCPull01.contoso.com', 'DSCTFS01.contoso.com'

Invoke-Command -ScriptBlock { 
    Remove-Item HKLM:\SOFTWARE\DscLcmController\ -Recurse -Force
    Remove-DscConfigurationDocument -Stage Current, Pending, Previous
    Remove-Item -Path C:\ProgramData\Dsc -Force -Recurse
    Get-ScheduledTask | Where-Object TaskName -like *dsc* | Unregister-ScheduledTask -Confirm:$false
} -ComputerName $nodes

Invoke-Command -ScriptBlock {
    dir C:\BuildWorkerSetupFiles\_work | Where-Object { $_.Name.Length -lt 3 } | Remove-Item -Recurse -Force
} -ComputerName $buildWorkers
