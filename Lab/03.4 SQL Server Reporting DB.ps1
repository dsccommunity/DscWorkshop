$sqlServer = Get-LabVM -Role DSCPullServer
Invoke-LabCommand -ActivityName 'Creating DSC SQl Database' -FilePath E:\LabSources\PostInstallationActivities\SetupDscPullServer\CreateDscSqlDatabase.ps1 `
-ComputerName DSCCASQL01 -ArgumentList $sqlServer.DomainAccountName