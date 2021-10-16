function Get-FilteredConfigurationData {
    param(
        [ScriptBlock]
        $Filter = {},

        [int]
        $CurrentJobNumber,

        [int]
        $TotalJobCount = 1,

        $Datum = $(Get-variable Datum -ValueOnly -ErrorAction Stop)
    )

    #even if default value is assiged to the Filter parameter, it is sometimes $null
    if ($Filter -eq $null) {
        $Filter = {}
    }

    $allNodes = @(Get-DatumNodesRecursive -Nodes $Datum.AllNodes -Depth 20)
    $totalNodeCount = $allNodes.Count
    
    Write-Host "Node count: $($allNodes.Count)"
    
    if($Filter.ToString() -ne ([System.Management.Automation.ScriptBlock]::Create({})).ToString()) {
        Write-Host "Filter: $($Filter.ToString())"
        $allNodes = [System.Collections.Hashtable[]]$allNodes.Where($Filter)
        Write-Host "Node count after applying filter: $($allNodes.Count)"
    }

    if (-not $allNodes.Count)
    {
        Write-Error "No node data found. There are in total $totalNodeCount nodes defined, but no node was selected. You may want to verify the filter: '$Filter'."
    }

    $CurrentJobNumber--
    $allNodes = Split-Array -List $allNodes -ChunkCount $TotalJobCount
    $allNodes = $allNodes[$CurrentJobNumber]

    return @{
        AllNodes = $allNodes
        Datum = $Datum
    }
}
