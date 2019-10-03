$hosts = Get-LabVM -Role HyperV

Invoke-LabCommand -ActivityName 'Install AutomatedLab and create LabSources folder' -ComputerName $hosts -ScriptBlock {

    #Add the AutomatedLab Telemetry setting to default to allow collection, otherwise will prompt during installation
    [System.Environment]::SetEnvironmentVariable('AUTOMATEDLAB_TELEMETRY_OPTOUT', '0')
    Install-PackageProvider -Name Nuget -ForceBootstrap -Force -ErrorAction Stop | Out-Null
    Install-Module -Name AutomatedLab -AllowClobber -Force -ErrorAction Stop

    Import-Module -Name AutomatedLab -ErrorAction Stop
    
    Enable-LabHostRemoting -Force

    New-LabSourcesFolder -ErrorAction Stop
}

Install-LabWindowsFeature -ComputerName $hosts -FeatureName RSAT-AD-Tools

Copy-LabFileItem -Path $labSources\ISOs\en_windows_server_2019_x64_dvd_4cb967d8.iso -DestinationFolderPath C:\LabSources\ISOs -ComputerName DSCHost01

Invoke-LabCommand -ActivityName 'Setup Test VM' -ComputerName $hosts -ScriptBlock {
    Import-Module -Name AutomatedLab
    $dc = Get-ADDomainController
    $ip = Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4
    $network = [AutomatedLab.IPNetwork]"$($ip.IPAddress)/$($ip.PrefixLength)"

    #--------------------------------

    New-LabDefinition -Name Lab1 -DefaultVirtualizationEngine HyperV
    $os = Get-LabAvailableOperatingSystem | Where-Object { $_.OperatingSystemName -like '*Datacenter*' -and $_.OperatingSystemName -like '*2019*' -and $_.OperatingSystemName -like '*Desktop*' }

    Add-LabVirtualNetworkDefinition -Name Lab1 -AddressSpace "$($network.IpAddress)/$($network.Cidr)" -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Ethernet' }

    Add-LabMachineDefinition -Name $dc.Name -Memory 1GB -OperatingSystem $os -Roles RootDC -DomainName $dc.Domain -SkipDeployment
    Add-LabMachineDefinition -Name Client1 -Memory 1GB -OperatingSystem $os #-DomainName $dc.Domain

    Install-Lab

    Show-LabDeploymentSummary -Detailed
}
