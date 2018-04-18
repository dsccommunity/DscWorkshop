Configuration FilesAndFolders {
    Param(
        [Parameter(Mandatory)]
        [hashtable[]]$Items
    )
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    foreach ($item in $Items) {
        
        if (-not $item.ContainsKey('Ensure'))
        {
            $item.Ensure = 'Present'
        }

        (Get-DscSplattedResource -ResourceName File -ExecutionName $item.DestinationPath -Properties $item -NoInvoke).Invoke($item)
    }
}