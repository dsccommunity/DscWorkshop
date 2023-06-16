configuration WindowsEventLogs {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Logs
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc

    foreach ($log in $Logs)
    {
        # convert string with KB/MB/GB to Sint64
        if ($null -ne $log.MaximumSizeInBytes)
        {
            $log.MaximumSizeInBytes = [System.Int64] ($log.MaximumSizeInBytes / 1)
        }

        $executionName = "$($log.LogName)" -replace ' ', ''
        (Get-DscSplattedResource -ResourceName WindowsEventLog -ExecutionName $executionName -Properties $log -NoInvoke).Invoke($log)

    }

}
