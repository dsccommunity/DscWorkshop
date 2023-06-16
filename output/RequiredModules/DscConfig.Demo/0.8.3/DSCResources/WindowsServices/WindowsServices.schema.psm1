configuration WindowsServices {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Services
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    foreach ($service in $Services)
    {
        # Remove Case Sensitivity of ordered Dictionary or Hashtables
        $service = @{} + $service

        $service.Ensure = 'Present'

        [boolean]$delayedStart = $false

        # additional Support for delayed start
        if ($service.StartupType -eq 'AutomaticDelayedStart')
        {
            $service.StartupType = 'Automatic'
            $delayedStart = $true
        }

        # set defaults if no state is specified
        if ([string]::IsNullOrWhiteSpace($service.State))
        {
            # check for running service only if none or a compatible startup type is specified
            if ([string]::IsNullOrWhiteSpace($service.StartupType) -or ($service.StartupType -eq 'Automatic'))
            {
                $service.State = 'Running'
            }
            elseif ($service.StartupType -eq 'Disabled')
            {
                $service.State = 'Stopped'
            }
            else
            {
                $service.State = 'Ignore'
            }
        }

        $executionName = "winsvc_$($Service.Name -replace '[-().:$#\s]', '_')"

        #how splatting of DSC resources works: https://gaelcolas.com/2017/11/05/pseudo-splatting-dsc-resources/
        (Get-DscSplattedResource -ResourceName xService -ExecutionName $executionName -Properties $service -NoInvoke).Invoke($service)

        if ($delayedStart -eq $true)
        {
            $serviceName = $Service.Name

            Script "$($executionName)_delayedstart"
            {
                TestScript = {
                    $key = "HKLM:SYSTEM\CurrentControlSet\Services\$using:serviceName"
                    $val = Get-ItemProperty -Path $key -Name 'DelayedAutostart' -ErrorAction SilentlyContinue

                    Write-Verbose "Read DelayedAutostart at $($key): $(if( $null -eq $val.DelayedAutostart ) { 'not found' } else { $val.DelayedAutostart })"
                    if ($null -ne $val.DelayedAutostart -and $val.DelayedAutostart -gt 0 )
                    {
                        return $true
                    }
                    return $false
                }
                SetScript  = {
                    $key = "HKLM:SYSTEM\CurrentControlSet\Services\$using:serviceName"
                    Write-Verbose "Set DelayedAutostart at $($key) to 1"
                    Set-ItemProperty -Path $key -Name 'DelayedAutostart' -Value 1 -Type DWord
                }
                GetScript  = { return `
                    @{
                        result = 'N/A'
                    }
                }
                DependsOn  = "[xService]$executionName"
            }
        }
    }
}
