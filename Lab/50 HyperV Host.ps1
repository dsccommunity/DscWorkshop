$hosts = Get-LabVM -Role HyperV

Invoke-LabCommand -ActivityName 'Install AutomatedLab and create LabSources folder' -ComputerName $hosts -ScriptBlock {
    if ($PSVersionTable.PSVersion.Major -lt 6 -and [Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12')
    {
      Write-Verbose -Message 'Adding support for TLS 1.2'
      [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }

    #Add the AutomatedLab Telemetry setting to default to allow collection, otherwise will prompt during installation
    [System.Environment]::SetEnvironmentVariable('AUTOMATEDLAB_TELEMETRY_OPTOUT', '0')
    Install-PackageProvider -Name Nuget -ForceBootstrap -Force -ErrorAction Stop | Out-Null
    Install-Module -Name AutomatedLab -AllowClobber -Force -ErrorAction Stop

    Import-Module -Name AutomatedLab -ErrorAction Stop
    
    Enable-LabHostRemoting -Force

    New-LabSourcesFolder -ErrorAction Stop
    
    Set-PSFConfig -Name MacAddressPrefix -Module AutomatedLab -Value 1017FB -PassThru | Register-PSFConfig -Scope UserDefault
}

Install-LabWindowsFeature -ComputerName $hosts -FeatureName RSAT-AD-Tools

Copy-LabFileItem -Path $labSources\ISOs\en_windows_server_2019_x64_dvd_4cb967d8.iso -DestinationFolderPath C:\LabSources\ISOs -ComputerName DSCHost01

Invoke-LabCommand -ActivityName 'Setup Test VM' -ComputerName $hosts -ScriptBlock {
    [System.Environment]::SetEnvironmentVariable('AUTOMATEDLAB_TELEMETRY_OPTOUT', '0')
    Import-Module -Name AutomatedLab
    $dc = Get-ADDomainController
        
    $netAdapter = Get-NetAdapter -Name 'vEthernet (AlExternal)' -ErrorAction SilentlyContinue
    if (-not $netAdapter)
    {
        $netAdapter = Get-NetAdapter -Name Ethernet -ErrorAction SilentlyContinue
    }
        
    $ip = $netAdapter | Get-NetIPAddress -AddressFamily IPv4
    
    #--------------------------------
    
    New-LabDefinition -Name Lab1 -DefaultVirtualizationEngine HyperV
    $os = Get-LabAvailableOperatingSystem | Where-Object { $_.OperatingSystemName -like '*Datacenter*' -and $_.OperatingSystemName -like '*2019*' -and $_.OperatingSystemName -like '*Desktop*' }
        
    Add-LabVirtualNetworkDefinition -Name AlExternal -AddressSpace "$($ip.IPAddress)/$($ip.PrefixLength)" -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Ethernet' }
        
    Add-LabMachineDefinition -Name $dc.Name -Memory 1GB -OperatingSystem $os -Roles RootDC -DomainName $dc.Domain -IpAddress $dc.IPv4Address -SkipDeployment
    Add-LabMachineDefinition -Name TestVM1 -Memory 1GB -OperatingSystem $os -DomainName $dc.Domain -DnsServer1 $dc.IPv4Address -Gateway (Get-NetIPConfiguration).IPv4DefaultGateway.NextHop
        
    Install-Lab
        
    Show-LabDeploymentSummary -Detailed
}
