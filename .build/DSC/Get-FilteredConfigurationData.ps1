function Get-FilteredConfigurationData {
    Param(
        $Environment = 'DEV',

        [AllowNull()]
        $FilterNode,

        $Datum = (Get-variable Datum -ValueOnly -ErrorAction Stop)
    )

    $AllNodes = @($Datum.AllNodes.($Environment).PSObject.Properties.Foreach{
        $Node = $Datum.AllNodes.($Environment).($_.Name)
        $Node['Environment'] = $Environment
        if(!$Node.contains('Name')) {
            $Null = $Node.Add('Name',$_.Name)
        }
        (@{} + $Node)
    })

    if($FilterNode) {
        $AllNodes = $AllNodes.Where{$_.Name -in $FilterNode}
    }

    return @{
        AllNodes = $AllNodes
        Datum = $Datum
    }
}