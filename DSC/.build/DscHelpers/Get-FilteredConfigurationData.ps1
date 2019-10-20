function Get-FilteredConfigurationData {
    param(
        [ScriptBlock]
        $Filter = {},

        $Environment = 'DEV',

        $Datum = $(Get-variable Datum -ValueOnly -ErrorAction Stop)
    )

    #$allNodes = @(Get-DatumNodesRecursive -Nodes $Datum.AllNodes -Depth 20)
    $AllNodes = @($Datum.AllNodes.($Environment).PSObject.Properties.Foreach{
        $Node = $Datum.AllNodes.($Environment).($_.Name)
        $Node['Environment'] = $Environment
        if (!$Node.contains('Name')) {
            $Null = $Node.Add('Name',$_.Name)
        }
        (@{} + $Node)
    })
    
    Write-Host "Node count: $($allNodes.Count)"
    
    if($Filter.ToString() -ne ([System.Management.Automation.ScriptBlock]::Create({})).ToString()) {
        Write-Host "Filter: $($Filter.ToString())"
        $allNodes = [System.Collections.Hashtable[]]$allNodes.Where($Filter)
        Write-Host "Node count after applying filter: $($allNodes.Count)"
    }

    return @{
        AllNodes = $allNodes
        Datum = $Datum
    }
}