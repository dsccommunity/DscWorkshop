$labName = 'DscWorkshop'

#--------------------------------------------------------------------------------------------------------------------
#----------------------- CHANGING ANYTHING BEYOND THIS LINE SHOULD NOT BE REQUIRED ----------------------------------
#----------------------- + EXCEPT FOR THE LINES STARTING WITH: REMOVE THE COMMENT TO --------------------------------
#----------------------- + EXCEPT FOR THE LINES CONTAINING A PATH TO AN ISO OR APP   --------------------------------
#--------------------------------------------------------------------------------------------------------------------

# Create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV

# Make the network definition
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 192.168.111.0/24
Add-LabVirtualNetworkDefinition -Name 'Default Switch' -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Wi-Fi' }

# and the domain definition with the domain admin account
Add-LabDomainDefinition -Name contoso.com -AdminUser Install -AdminPassword Somepass1

# These credentials are used for connecting to the machines. As this is a lab we use clear-text passwords
Set-LabInstallationCredential -Username Install -Password Somepass1

# Add the reference to our necessary ISO files
Add-LabIsoImageDefinition -Name AzDevOps -Path $labSources\ISOs\azuredevops2022.0.1.iso #from https://docs.microsoft.com/en-us/azure/devops/server/download/azuredevopsserver?view=azure-devops
Add-LabIsoImageDefinition -Name SQLServer2019 -Path $labsources\ISOs\SQLServer2019-x64-ENU.iso #from https://www.microsoft.com/en-us/evalcenter/evaluate-sql-server-2019. The EXE downloads the ISO.

# Data Disks
Add-LabDiskDefinition -Name DSCDO01_D -DiskSizeInGb 120 -Label DataDisk1 -DriveLetter D
Add-LabDiskDefinition -Name DSCHost01_D -DiskSizeInGb 120 -Label DataDisk1 -DriveLetter D

# Defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'         = $labName
    'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
    'Add-LabMachineDefinition:DomainName'      = 'contoso.com'
    'Add-LabMachineDefinition:DnsServer1'      = '192.168.111.10'
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:Gateway'         = '192.168.111.50'
}

# The PostInstallationActivity is just creating some users
$postInstallActivity = @()
$postInstallActivity += Get-LabPostInstallationActivity -ScriptFileName 'New-ADLabAccounts 2.0.ps1' -DependencyFolder $labSources\PostInstallationActivities\PrepareFirstChildDomain
$postInstallActivity += Get-LabPostInstallationActivity -ScriptFileName PrepareRootDomain.ps1 -DependencyFolder $labSources\PostInstallationActivities\PrepareRootDomain
Add-LabMachineDefinition -Name DSCDC01 -Memory 1GB -Roles RootDC -IpAddress 192.168.111.10 -PostInstallationActivity $postInstallActivity

# File server and router
$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch $labName -Ipv4Address 192.168.111.50
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'Default Switch' -UseDhcp

# SQL and PKI
Add-LabMachineDefinition -Name DSCCASQL01 -Memory 3GB -Roles CaRoot, SQLServer2019, Routing -NetworkAdapter $netAdapter

# DSC Pull Server with SQL server backing, Azure DevOps Build Worker
$roles = @(
    Get-LabMachineRoleDefinition -Role DSCPullServer -Properties @{
        DoNotPushLocalModules = 'true'
        DatabaseEngine        = 'sql'
        SqlServer             = 'DSCCASQL01'
        DatabaseName          = 'DSC'
    }
    # Get-LabMachineRoleDefinition -Role TfsBuildWorker -Properties @{ NumberOfBuildWorkers = '4' }
    Get-LabMachineRoleDefinition -Role WebServer
)
Add-LabMachineDefinition -Name DSCPull01 -Memory 4GB -Roles $roles -IpAddress 192.168.111.60

# Build Server
Add-LabMachineDefinition -Name DSCDO01 -Memory 6GB -Roles AzDevOps -IpAddress 192.168.111.70 -DiskName DSCDO01_D

# Hyper-V Host
$roles = @(
    Get-LabMachineRoleDefinition -Role TfsBuildWorker -Properties @{ NumberOfBuildWorkers = '4' }
    Get-LabMachineRoleDefinition -Role HyperV
)
Add-LabMachineDefinition -Name DSCHost01 -Memory 8GB -Roles $roles -IpAddress 192.168.111.80 -DiskName DSCHost01_D

# DSC target nodes - our legacy VMs with an existing configuration
Add-LabMachineDefinition -Name DSCFile01 -Memory 1GB -Roles FileServer -IpAddress 192.168.111.100
Add-LabMachineDefinition -Name DSCWeb01 -Memory 1GB -Roles WebServer -IpAddress 192.168.111.101

# Servers in Test
Add-LabMachineDefinition -Name DSCFile02 -Memory 1GB -Roles FileServer -IpAddress 192.168.111.110
Add-LabMachineDefinition -Name DSCWeb02 -Memory 1GB -Roles WebServer -IpAddress 192.168.111.111

# Servers in Prod
Add-LabMachineDefinition -Name DSCFile03 -Memory 1GB -Roles FileServer -IpAddress 192.168.111.120
Add-LabMachineDefinition -Name DSCWeb03 -Memory 1GB -Roles WebServer -IpAddress 192.168.111.121

Install-Lab

Enable-LabCertificateAutoenrollment -Computer -User
Install-LabWindowsFeature -ComputerName (Get-LabVM -Role DSCPullServer, FileServer, WebServer, AzDevOps) -FeatureName RSAT-AD-Tools
Invoke-LabCommand -ActivityName 'Disable Windows Update Service and DisableRealtimeMonitoring' -ComputerName (Get-LabVM) -ScriptBlock {
    Stop-Service -Name wuauserv
    Set-Service -Name wuauserv -StartupType Disabled
    Set-MpPreference -DisableRealtimeMonitoring $true
}

# in case you screw something up
Write-Host "1. - Creating Snapshot 'AfterInstall'" -ForegroundColor Magenta
Checkpoint-LabVM -All -SnapshotName AfterInstall

Show-LabDeploymentSummary -Detailed
