configuration WindowsOptionalFeatures {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]
        $Names,

        [Parameter()]
        [boolean]
        $RemoveFilesOnDisable = $false,

        [Parameter()]
        [boolean]
        $NoWindowsUpdateCheck = $false
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    foreach ($n in $Names)
    {
        $ensure = 'Enable'

        if ($n[0] -in '-', '+')
        {
            if ($n[0] -eq '-')
            {
                $ensure = 'Disable'
            }
            $n = $n.Substring(1)
        }

        $params = @{
            Name                 = $n
            Ensure               = $ensure
            RemoveFilesOnDisable = $RemoveFilesOnDisable
            NoWindowsUpdateCheck = $NoWindowsUpdateCheck
        }

        (Get-DscSplattedResource -ResourceName WindowsOptionalFeature -ExecutionName $params.Name -Properties $params -NoInvoke).Invoke($params)
    }
}
