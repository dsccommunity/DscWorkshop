configuration NetworkIpConfiguration {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]

    param (
        [Parameter()]
        [boolean]
        $DisableNetBios = $false,

        [Parameter()]
        [int16]
        $ConfigureIPv6 = -1, # < 0 -> no configuration code will be generated

        [Parameter()]
        [hashtable[]]
        $Interfaces,

        [Parameter()]
        [hashtable[]]
        $Routes
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName NetworkingDsc

    function NetIpInterfaceConfig
    {
        param (
            [Parameter()]
            [string]
            $InterfaceAlias,

            [Parameter()]
            [string]
            $IpAddress,

            [Parameter()]
            [int]$Prefix,

            [Parameter()]
            [string]$Gateway,

            [Parameter()]
            [string[]]
            $DnsServer,

            [Parameter()]
            [uint32]
            $InterfaceMetric,

            [Parameter()]
            [boolean]
            $DisableNetbios,

            [Parameter()]
            [boolean]
            $EnableDhcp,

            [Parameter()]
            [boolean]
            $EnableLmhostsLookup,

            [Parameter()]
            [boolean]
            $DisableIPv6,

            [Parameter()]
            [ValidateSet('Public', 'Private', 'DomainAuthenticated')]
            [string]
            $NetworkCategory
        )

        if ( $EnableDhcp -eq $true )
        {
            if (-not [string]::IsNullOrWhiteSpace($IpAddress) -or
                -not [string]::IsNullOrWhiteSpace($Gateway) -or
                ($null -ne $DnsServer -and $DnsServer.Count -gt 0))
            {
                throw "ERROR: Enabled DHCP requires empty 'IpAddress' ($IpAddress), 'Gateway' ($Gateway) and 'DnsServer' ($DnsServer) parameters for interface '$InterfaceAlias'."
            }

            NetIPInterface "EnableDhcp_$InterfaceAlias"
            {
                InterfaceAlias = $InterfaceAlias
                AddressFamily  = 'IPv4'
                Dhcp           = 'Enabled'
            }

            DnsServerAddress "EnableDhcpDNS_$InterfaceAlias"
            {
                InterfaceAlias = $InterfaceAlias
                AddressFamily  = 'IPv4'
            }
        }
        else
        {
            if (-not [string]::IsNullOrWhiteSpace($IpAddress))
            {
                # disable DHCP if IP-Address is specified
                NetIPInterface "DisableDhcp_$InterfaceAlias"
                {
                    InterfaceAlias = $InterfaceAlias
                    AddressFamily  = 'IPv4'
                    Dhcp           = 'Disabled'
                }

                if ( -not ($Prefix -match '^\d+$') )
                {
                    throw "ERROR: Valid 'Prefix' parameter is required for IP address '$IpAddress'."
                }

                $ip = "$($IpAddress)/$($Prefix)"

                IPAddress "NetworkIp_$InterfaceAlias"
                {
                    IPAddress      = $ip
                    AddressFamily  = 'IPv4'
                    InterfaceAlias = $InterfaceAlias
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($Gateway))
            {
                DefaultGatewayAddress "DefaultGateway_$InterfaceAlias"
                {
                    AddressFamily  = 'IPv4'
                    InterfaceAlias = $InterfaceAlias
                    Address        = $Gateway
                }
            }

            if ($null -ne $DnsServer -and $DnsServer.Count -gt 0)
            {
                DnsServerAddress "DnsServers_$InterfaceAlias"
                {
                    InterfaceAlias = $InterfaceAlias
                    AddressFamily  = 'IPv4'
                    Address        = $DnsServer
                }
            }
        }

        if ($null -ne $InterfaceMetric -and $InterfaceMetric -gt 0)
        {
            Script "InterfaceMetric_$InterfaceAlias"
            {
                TestScript =
                {
                    $netIf = Get-NetIpInterface -InterfaceAlias $using:InterfaceAlias -ErrorAction SilentlyContinue
                    if ( $null -eq $netIf )
                    {
                        Write-Verbose "NetIpInterface '$using:InterfaceAlias' not found."
                        return $false
                    }

                    [boolean]$result = $true
                    $netIf | ForEach-Object { Write-Verbose "InterfaceMetric $($_.AddressFamily): $($_.InterfaceMetric)";
                        if ( $_.InterfaceMetric -ne $using:InterfaceMetric )
                        {
                            $result = $false
                        }; }

                    Write-Verbose "Expected Interface Metric: $using:InterfaceMetric"
                    return $result
                }
                SetScript  =
                {
                    $netIf = Get-NetIpInterface -InterfaceAlias $using:InterfaceAlias

                    $netIf | ForEach-Object { Write-Verbose "Set $($_.AddressFamily) InterfaceMetric to $using:InterfaceMetric";
                        $_ | Set-NetIpInterface -InterfaceMetric $using:InterfaceMetric }
                }
                GetScript  = { return `
                    @{
                        result = 'N/A'
                    }
                }
            }
        }

        WinsSetting "LmhostsLookup_$InterfaceAlias"
        {
            EnableLmHosts    = $EnableLmhostsLookup
            IsSingleInstance = 'Yes'
        }

        if ($DisableNetbios)
        {
            NetBios "DisableNetBios_$InterfaceAlias"
            {
                InterfaceAlias = $InterfaceAlias
                Setting        = 'Disable'
            }
        }

        if ($DisableIPv6)
        {
            NetAdapterBinding "DisableIPv6_$InterfaceAlias"
            {
                InterfaceAlias = $InterfaceAlias
                ComponentId    = 'ms_tcpip6'
                State          = 'Disabled'
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($NetworkCategory))
        {
            if (-not ($NetworkCategory -match '^(Public|Private|DomainAuthenticated)$'))
            {
                throw "ERROR: Invalid value of attribute 'NetworkCategory'."
            }

            Script "NetworkCategory_$InterfaceAlias"
            {
                TestScript = {
                    $val = Get-NetConnectionProfile -InterfaceAlias $using:InterfaceAlias

                    Write-Verbose "Current NetworkCategory of interface '$using:InterfaceAlias': $($val.NetworkCategory)"

                    if ($null -ne $val -and $val.NetworkCategory -eq $using:NetworkCategory)
                    {
                        return $true
                    }
                    Write-Verbose "Values are different (expected NetworkCategory: $using:NetworkCategory)"
                    return $false
                }
                SetScript  = {
                    if ($using:NetworkCategory -eq 'DomainAuthenticated')
                    {
                        Write-Verbose "Set NetworkCategory of interface '$using:InterfaceAlias' to '$using:NetworkCategory ' is not supported. The computer automatically sets this value when the network is authenticated to a domain controller."

                        # Workaround if the computer is domain joined -> Restart NLA service to restart the network location check
                        # see https://newsignature.com/articles/network-location-awareness-service-can-ruin-day-fix/
                        Write-Verbose "Restarting NLA service to reinitialize the network location check..."
                        Restart-Service nlasvc -Force
                        Start-Sleep 5

                        $val = Get-NetConnectionProfile -InterfaceAlias $using:InterfaceAlias

                        Write-Verbose "Current NetworkCategory is now: $($val.NetworkCategory)"

                        if ($val.NetworkCategory -ne $using:NetworkCategory)
                        {
                            Write-Error "Interface '$using:InterfaceAlias' is not '$using:NetworkCategory'."
                        }
                    }
                    else
                    {
                        Write-Verbose "Set NetworkCategory of interface '$using:InterfaceAlias' to '$using:NetworkCategory '."
                        Set-NetConnectionProfile -InterfaceAlias $using:InterfaceAlias -NetworkCategory $using:NetworkCategory
                    }
                }
                GetScript  = { return `
                    @{
                        result = 'N/A'
                    }
                }
            }
        }
    }

    if ($DisableNetbios -eq $true)
    {
        NetBios DisableNetBios_System
        {
            InterfaceAlias = '*'
            Setting        = 'Disable'
        }
    }

    if ($ConfigureIPv6 -ge 0)
    {
        # see https://docs.microsoft.com/en-US/troubleshoot/windows-server/networking/configure-ipv6-in-windows

        if ($ConfigureIPv6 -gt 255)
        {
            throw "ERROR: Invalid IPv6 configuration value $ConfigureIPv6 (expected value: 0-255)."
        }

        $configIPv6KeyName = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
        $configIPv6VarName = 'DisabledComponents'

        Script ConfigureIPv6_System
        {
            TestScript = {
                $val = Get-ItemProperty -Path $using:configIPv6KeyName -Name $using:configIPv6VarName -ErrorAction SilentlyContinue

                Write-Verbose "Current IPv6 Configuration value: '$($val.$using:configIPv6VarName)' - expected value: '$using:ConfigureIPv6'"

                if ($null -ne $val -and $val.$using:configIPv6VarName -eq $using:ConfigureIPv6)
                {
                    return $true
                }
                Write-Verbose 'Values are different'
                return $false
            }

            SetScript  = {
                if ( -not (Test-Path -Path $using:configIPv6KeyName) )
                {
                    New-Item -Path $using:configIPv6KeyName -Force
                }
                Set-ItemProperty -Path $using:configIPv6KeyName -Name $using:configIPv6VarName -Value $using:ConfigureIPv6 -Type DWord
                $global:DSCMachineStatus = 1
            }

            GetScript  = { return `
                @{
                    result = 'N/A'
                }
            }
        }
    }

    if ($null -ne $Interfaces)
    {
        foreach ( $netIf in $Interfaces )
        {
            # Remove case sensitivity of ordered Dictionary or Hashtables
            $netIf = @{} + $netIf

            if ( [string]::IsNullOrWhitespace($netIf.InterfaceAlias) )
            {
                $netIf.InterfaceAlias = 'Ethernet'
            }
            if ( $DisableNetbios -eq $true -or [string]::IsNullOrWhitespace($netIf.DisableNetbios) )
            {
                $netIf.DisableNetbios = $false
            }
            if ( [string]::IsNullOrWhitespace($netIf.EnableLmhostsLookup) )
            {
                $netIf.EnableLmhostsLookup = $false
            }
            if ( [string]::IsNullOrWhitespace($netIf.EnableDhcp) )
            {
                $netIf.EnableDhcp = $false
            }
            if ( $DisableIPv6 -eq $true -or [string]::IsNullOrWhitespace($netIf.DisableIPv6) )
            {
                $netIf.DisableIPv6 = $false
            }
            if ( $netIf.EnableDhcp -eq $true -and [string]::IsNullOrWhitespace($netIf.Prefix) )
            {
                $netIf.Prefix = 24
            }

            NetIpInterfaceConfig @netIf
        }
    }

    if ($null -ne $Routes)
    {
        foreach ( $netRoute in $Routes )
        {
            # Remove case sensitivity of ordered Dictionary or Hashtables
            $netRoute = @{} + $netRoute

            if ( [string]::IsNullOrWhitespace($netRoute.InterfaceAlias) )
            {
                $netRoute.InterfaceAlias = 'Ethernet'
            }

            if ( [string]::IsNullOrWhitespace($netRoute.AddressFamily) )
            {
                $netRoute.AddressFamily = 'IPv4'
            }

            if ( [string]::IsNullOrWhitespace($netRoute.Ensure) )
            {
                $netRoute.Ensure = 'Present'
            }

            $executionName = "route_$($netRoute.InterfaceAlias)_$($netRoute.AddressFamily)_$($netRoute.DestinationPrefix)_$($netRoute.NextHop)" -replace '[().:\s]', ''
            (Get-DscSplattedResource -ResourceName Route -ExecutionName $executionName -Properties $netRoute -NoInvoke).Invoke($netRoute)
        }
    }
}
