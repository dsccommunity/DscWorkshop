configuration WebApplicationPools {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Items
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName WebAdministrationDsc

    foreach ($item in $Items)
    {
        if (-not $item.ContainsKey('Ensure'))
        {
            $item.Ensure = 'Present'
        }

        $executionName = $item.Name
        (Get-DscSplattedResource -ResourceName WebAppPool -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
    }
}
