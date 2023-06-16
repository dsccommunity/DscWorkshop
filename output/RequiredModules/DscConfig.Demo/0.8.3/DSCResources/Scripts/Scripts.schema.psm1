configuration Scripts {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Items
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    foreach ($item in $Items)
    {
        # remove case sensivity from hashtable
        $item = @{} + $item

        if ($null -ne $item.Params)
        {
            $params = '$params = ''' + ($item.Params | ConvertTo-Json -Compress) + "' | ConvertFrom-JSON;`n"
        }

        if ([string]::IsNullOrWhiteSpace($item.GetScript))
        {
            $item.GetScript = "@{ Result = 'N/A' }"
        }
        elseif ($null -ne $params)
        {
            $item.GetScript = $params + $item.GetScript
        }

        if ([string]::IsNullOrWhiteSpace($item.SetScript))
        {
            $item.SetScript = "Write-Error 'SetScript is not implemented.'"
        }
        elseif ($null -ne $params)
        {
            $item.SetScript = $params + $item.SetScript
        }

        if ($null -ne $params)
        {
            $item.TestScript = $params + $item.TestScript
        }

        $executionName = "Script_$($item.Name)"

        [void]$item.Remove('Name')
        [void]$item.Remove('Params')

        (Get-DscSplattedResource -ResourceName xScript -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
    }
}
