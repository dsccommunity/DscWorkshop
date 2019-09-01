function Get-FilteredConfigurationData {
    param(
        [ScriptBlock]
        $Filter = {},

        $Datum = $(Get-variable Datum -ValueOnly -ErrorAction Stop)
    )

    $allNodes = @(Get-DatumNodesRecursive -Nodes $Datum.AllNodes -Depth 20)
    
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