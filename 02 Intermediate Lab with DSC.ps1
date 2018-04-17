$labName = 'psconf18'

#--------------------------------------------------------------------------------------------------------------------
#----------------------- CHANGING ANYTHING BEYOND THIS LINE SHOULD NOT BE REQUIRED ----------------------------------
#----------------------- + EXCEPT FOR THE LINES STARTING WITH: REMOVE THE COMMENT TO --------------------------------
#----------------------- + EXCEPT FOR THE LINES CONTAINING A PATH TO AN ISO OR APP   --------------------------------
#--------------------------------------------------------------------------------------------------------------------

#create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV

#make the network definition
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 192.168.111.0/24
Add-LabVirtualNetworkDefinition -Name External -HyperVProperties @{ SwitchType = 'External'; AdapterName = 'Ethernet' }

#and the domain definition with the domain admin account
Add-LabDomainDefinition -Name psconf.eu -AdminUser Install -AdminPassword Somepass1

#these credentials are used for connecting to the machines. As this is a lab we use clear-text passwords
Set-LabInstallationCredential -Username Install -Password Somepass1

# Add the reference to our necessary ISO files
Add-LabIsoImageDefinition -Name SQLServer2016 -Path $labsources\ISOs\en_sql_server_2016_enterprise_x64_dvd_8701793.iso


$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network' = $labName
    'Add-LabMachineDefinition:ToolsPath'= "$labSources\Tools"
    'Add-LabMachineDefinition:DomainName' = 'psconf.eu'
    'Add-LabMachineDefinition:DnsServer1' = '192.168.111.10'
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2016 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:Gateway' = '192.168.111.50'
}

#The PostInstallationActivity is just creating some users
$postInstallActivity = @()
$postInstallActivity += Get-LabPostInstallationActivity -ScriptFileName 'New-ADLabAccounts 2.0.ps1' -DependencyFolder $labSources\PostInstallationActivities\PrepareFirstChildDomain
$postInstallActivity += Get-LabPostInstallationActivity -ScriptFileName PrepareRootDomain.ps1 -DependencyFolder $labSources\PostInstallationActivities\PrepareRootDomain
Add-LabMachineDefinition -Name DSCDC01 -Memory 512MB -Roles RootDC -IpAddress 192.168.111.10 -PostInstallationActivity $postInstallActivity

1..4 | Foreach-Object {
    Add-LabMachineDefinition -Name "DSCSRV0$_" -Memory 1GB -OperatingSystem 'Windows Server 2016 Datacenter' # No GUI, we want DSC to configure our core servers
}

$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch $labName -Ipv4Address 192.168.111.50
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch External -UseDhcp

# The good, the bad and the ugly
# RootCA, SQL and Routing. CA and SQL needed for DSC Pull Server and MOF encryption
Add-LabMachineDefinition -Name DSCCASQL01 -Memory 4GB -Roles CaRoot, SQLServer2016, Routing -NetworkAdapter $netAdapter

# DSC Pull Server with SQL server backing
$role = @(
    Get-LabMachineRoleDefinition -Role DSCPullServer -Properties @{ DoNotPushLocalModules = 'true'; DatabaseEngine = 'mdb' }
)
Add-LabMachineDefinition -Name DSCPULL01 -Memory 2GB -Roles $role

Install-Lab

Install-LabWindowsFeature -ComputerName (Get-LabVM -Role DSCPullServer) -FeatureName RSAT-AD-Tools

Enable-LabCertificateAutoenrollment -Computer -User

Show-LabDeploymentSummary -Detailed
