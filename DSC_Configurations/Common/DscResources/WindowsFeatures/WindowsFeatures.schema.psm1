Configuration WindowsFeatures {
    Param(
        [Parameter(Mandatory)]
        [string[]]$Name
    )
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    
    $ensure = 'Present'
    foreach ($n in $Name) {
        if ($n[0] -in '-', '+') {
            if ($n[0] -eq '-') {
                $ensure = 'Absent'
            }
            $n = $n.Substring(1)
        }

        $params = @{
            Name                 = $n
            Ensure               = $ensure
            IncludeAllSubFeature = $true
        }

        (Get-DscSplattedResource -ResourceName WindowsFeature -ExecutionName $params.Name -Properties $params -NoInvoke).Invoke($params)
    }
}