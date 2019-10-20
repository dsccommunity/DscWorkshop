function Get-FilteredRoleConfigurationData {
    param (
        $RoleName,

        $Datum = (Get-variable Datum -ValueOnly -ErrorAction Stop)
    )

    $Environments = $Datum.AllNodes.PSObject.Properties.ForEach({$_.Name})
    $AllNodes = @()
    $AllNodes_Temp = @()

    foreach ($Environment in $Environments) {
        Write-Host "Looking up role definitions for $($Environment)" -ForeGroundColor Green
        $AllNodes_Temp = @($Datum.AllNodes.($Environment).PSObject.Properties.Foreach{

            if ($Datum.AllNodes.($Environment).($_.Name).role -eq $RoleName) {
                $Node = $Datum.AllNodes.($Environment).($_.Name)
                $Node['Environment'] = $Environment

                if (!$Node.contains('Name')) {
                    $Null = $Node.Add('Name',$_.Name)
                }
                (@{} + $Node)
            }
        })
    $AllNodes += $AllNodes_Temp
    }

    if ($FilterNode) {
        $AllNodes = $AllNodes.Where{$_.Name -in $FilterNode}
    }

    Write-Host "Nodes found with role $($RoleName): $($AllNodes.Count)" -ForeGroundColor Green

    return @{
        AllNodes = $AllNodes
        Datum    = $Datum
    }
}
