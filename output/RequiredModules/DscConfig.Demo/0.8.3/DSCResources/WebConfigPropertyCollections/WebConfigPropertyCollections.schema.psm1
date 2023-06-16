configuration WebConfigPropertyCollections {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Items
    )

    <#
    CollectionName = [string]
    Filter = [string]
    ItemKeyName = [string]
    ItemKeyValue = [string]
    ItemName = [string]
    ItemPropertyName = [string]
    WebsitePath = [string]
    [DependsOn = [string[]]]
    [Ensure = [string]{ Absent | Present }]
    [ItemPropertyValue = [string]]
    [PsDscRunAsCredential = [PSCredential]]
    #>

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName WebAdministrationDsc

    foreach ($item in $Items)
    {
        if (-not $item.ContainsKey('Ensure'))
        {
            $item.Ensure = 'Present'
        }

        $executionName = "$($item.WebsitePath)_$($item.Filter)_$($item.CollectionName)_$($item.ItemKeyValue)_$($item.ItemPropertyName)" -replace '[\s(){}/\\:-]', '_'
        (Get-DscSplattedResource -ResourceName WebConfigPropertyCollection -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
    }
}
