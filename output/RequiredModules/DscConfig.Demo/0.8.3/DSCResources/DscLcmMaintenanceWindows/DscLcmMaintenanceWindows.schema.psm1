configuration DscLcmMaintenanceWindows {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]$MaintenanceWindows
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    $on = '1st', '2nd', '3rd', '4th', 'last'
    $daysOfWeek = [System.Enum]::GetNames([System.DayOfWeek])

    foreach ($window in $MaintenanceWindows.GetEnumerator())
    {
        if ($window.DayOfWeek)
        {
            if ($window.DayOfWeek -notin $daysOfWeek)
            {
                Write-Error "DayOfWeek '$($window.DayOfWeek)' of maintenance window '$($window.Name)' is not in the supported range ('$($daysOfWeek -join ', ')')."
            }
        }

        if ($window.On)
        {
            if ($window.On -notin $on)
            {
                Write-Error "Property 'On' set to '$($window.On)' of maintenance window '$($window.Name)' is not in the supported range ('$($on -join ', ')')."
            }
        }
    }

    Script MaintenanceWindowsCheck
    {
        TestScript = {
            try
            {
                $existingWindows = Get-ChildItem -Path HKLM:\SOFTWARE\DscLcmController\MaintenanceWindows -ErrorAction Stop | Select-Object -ExpandProperty PSChildName
                $diff = Compare-Object -ReferenceObject $existingWindows -DifferenceObject $using:MaintenanceWindows.Name
                Write-Verbose "Result: $([bool]-not $diff)  -  $diff"
                [bool]-not $diff
            }
            catch
            {
                Write-Verbose "Result: False`n$_"
                $false
            }
        }
        SetScript  = {
            Write-Verbose 'There is a difference in the maintainance window definition. Removing currently configured maintenance windows.'
            Remove-Item -Path HKLM:\SOFTWARE\DscLcmController\MaintenanceWindows -Force -Recurse -ErrorAction SilentlyContinue
        }

        GetScript  = {
            @{
                Result = Get-ChildItem -Path HKLM:\SOFTWARE\DscLcmController\MaintenanceWindows -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName
            }
        }
    }

    foreach ($window in $MaintenanceWindows.GetEnumerator())
    {
        xRegistry "StartTime_$($window.Name)"
        {
            Key       = "HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController\MaintenanceWindows\$($window.Name)"
            ValueName = 'StartTime'
            ValueData = $window.StartTime
            ValueType = 'String'
            Ensure    = 'Present'
            Force     = $true
        }

        xRegistry "Timespan_$($window.Name)"
        {
            Key       = "HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController\MaintenanceWindows\$($window.Name)"
            ValueName = 'Timespan'
            ValueData = $window.Timespan
            ValueType = 'String'
            Ensure    = 'Present'
            Force     = $true
        }

        xRegistry "DayOfWeek_$($window.Name)"
        {
            Key       = "HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController\MaintenanceWindows\$($window.Name)"
            ValueName = 'DayOfWeek'
            ValueData = $window.DayOfWeek
            ValueType = 'String'
            Ensure    = 'Present'
            Force     = $true
        }

        xRegistry "On_$($window.Name)"
        {
            Key       = "HKEY_LOCAL_MACHINE\SOFTWARE\DscLcmController\MaintenanceWindows\$($window.Name)"
            ValueName = 'On'
            ValueData = $window.On
            ValueType = 'String'
            Ensure    = 'Present'
            Force     = $true
        }
    }
}
