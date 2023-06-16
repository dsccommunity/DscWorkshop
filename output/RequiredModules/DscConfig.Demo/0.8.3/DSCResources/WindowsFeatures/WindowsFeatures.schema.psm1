configuration WindowsFeatures {
    param (
        [Parameter()]
        [string[]]
        $Names,

        [Parameter()]
        [hashtable[]]
        $Features,

        [Parameter()]
        [bool]$UseLegacyResource = $false
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    $resourceName = if ($UseLegacyResource)
    {
        'WindowsFeature'
    }
    else
    {
        'xWindowsFeature'
    }

    foreach ($n in $Names)
    {
        $ensure = 'Present'
        $includeAllSubFeature = $false

        if ($n[0] -in '-', '+', '*')
        {
            if ($n[0] -eq '-')
            {
                $ensure = 'Absent'
            }
            elseif ($n[0] -eq '*')
            {
                $includeAllSubFeature = $true
            }
            $n = $n.Substring(1)
        }

        $params = @{
            Name                 = $n
            Ensure               = $ensure
            IncludeAllSubFeature = $includeAllSubFeature
        }

        (Get-DscSplattedResource -ResourceName $resourceName -ExecutionName $params.Name -Properties $params -NoInvoke).Invoke($params)
    }

    <#
    @{
    Name = [string]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Ensure = [string]{ Absent | Present }]
    [IncludeAllSubFeature = [bool]]
    [LogPath = [string]]
    [PsDscRunAsCredential = [PSCredential]]
    [Source = [string]]
}
    #>
    foreach ($feature in $Features)
    {
        $resourceName = if ($feature.UseLegacyResource)
        {
            'WindowsFeature'
        }
        else
        {
            'xWindowsFeature'
        }
        $feature.remove('UseLegacyResource')

        (Get-DscSplattedResource -ResourceName $resourceName -ExecutionName $feature.Name -Properties $feature -NoInvoke).Invoke($feature)
    }
}
