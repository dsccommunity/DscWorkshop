function Get-FilteredConfigurationData {
    param(
        [String]
        $Environment = 'DEV',

        [ScriptBlock]
        $Filter = {},

        $Datum = $(Get-variable Datum -ValueOnly -ErrorAction Stop)
    )

    $allNodes = @(Get-DatumNodesRecursive -Nodes $Datum.AllNodes.$Environment -Depth 20)
    
    if($Filter.ToString() -ne ([System.Management.Automation.ScriptBlock]::Create({})).ToString()) {
        $allNodes = [System.Collections.Hashtable[]]$allNodes.Where($Filter)
    }

    return @{
        AllNodes = $allNodes
        Datum = $Datum
    }
}