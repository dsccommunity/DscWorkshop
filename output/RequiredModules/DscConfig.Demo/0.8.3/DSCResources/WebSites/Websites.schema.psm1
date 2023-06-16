configuration WebSites {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Items
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName WebAdministrationDsc

    $dscResourceName = 'WebSite'

    foreach ($item in $Items)
    {
        # Remove Case Sensitivity of ordered Dictionary or Hashtables
        $item = @{} + $item

        if (-not $item.ContainsKey('Ensure'))
        {
            $item.Ensure = 'Present'
        }

        if ($item.BindingINfo)
        {
            $dscBindingInfos = foreach ($bindingInfo in $item.BindingInfo)
            {
            (Get-DscSplattedResource -ResourceName DSC_WebBindingInformation -Properties $bindingInfo -NoInvoke).Invoke($bindingInfo)
            }
            $item.BindingInfo = $dscBindingInfos
        }

        if ($item.AuthenticationInfo)
        {
            $item.AuthenticationInfo = (Get-DscSplattedResource -ResourceName DSC_WebAuthenticationInformation -Properties $item.AuthenticationInfo -NoInvoke).Invoke($item.AuthenticationInfo)
        }

        $executionName = "website_$($item.Name -replace '[{}#\-\s]','_')"
        (Get-DscSplattedResource -ResourceName $dscResourceName -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
    }
}
