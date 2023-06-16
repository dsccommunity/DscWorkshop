configuration SoftwarePackages {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Packages
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    foreach ($p in $Packages)
    {
        $p.Ensure = 'Present'
        if (-not $p.ProductId)
        {
            $p.ProductId = ''
        }

        $executionName = $p.Name -replace '\(|\)|\.| ', ''
        (Get-DscSplattedResource -ResourceName xPackage -ExecutionName $executionName -Properties $p -NoInvoke).Invoke($p)
    }
}
