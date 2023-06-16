configuration LocalGroups {
    param (
        [Parameter()]
        [hashtable[]]
        $Groups
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    foreach ($group in $Groups)
    {
        $executionName = $group.GroupName -replace '[\s(){}/\\:-]', '_'
        (Get-DscSplattedResource -ResourceName xGroup -ExecutionName $executionName -Properties $group -NoInvoke).Invoke($group)
    }
}
