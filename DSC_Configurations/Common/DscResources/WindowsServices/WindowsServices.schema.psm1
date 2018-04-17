Configuration WindowsServices {
    Param(
        [Parameter(Mandatory)]
        [hashtable[]]$Services
    )
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    foreach ($service in $Services) {
        $service.Credential = New-Object pscredential('Install', ('Somepass1' | ConvertTo-SecureString -AsPlainText -Force))
        $service.Ensure = 'Present'
        if (-not $service.State)
        {
            $service.State = 'Running'
        }

        #how splatting of DSC resources works: https://gaelcolas.com/2017/11/05/pseudo-splatting-dsc-resources/
        (Get-DscSplattedResource -ResourceName Service -ExecutionName $service.Name -Properties $service -NoInvoke).Invoke($service)

        <#
        Service $Service.Name {
            Name        = $service.Name
            Ensure      = 'Present'
            Credential  = New-Object pscredential('Install', ('Somepass1' | ConvertTo-SecureString -AsPlainText -Force))
            DisplayName = $service.DisplayName
            StartupType = $service.StartupType
            State       = 'Running'
            Path        = $service.Path
        }
        #>    
    }

}