$requiredModules = @{
    'powershell-yaml'            = 'latest'
    BuildHelpers                 = 'latest'
    datum                        = '0.39.0'
    DscBuildHelpers              = 'latest'
    InvokeBuild                  = 'latest'
    Pester                       = '4.10.1'
    ProtectedData                = 'latest'
    PSDepend                     = 'latest'
    PSDeploy                     = 'latest'
    PSScriptAnalyzer             = 'latest'
    xDSCResourceDesigner         = 'latest'
    xPSDesiredStateConfiguration = '9.1.0'
    ComputerManagementDsc        = '8.4.0'
    NetworkingDsc                = '8.1.0'
    NTFSSecurity                 = 'latest'
    JeaDsc                       = '0.7.2'
    XmlContentDsc                = '0.0.1'
    PowerShellGet                = 'latest'
    PackageManagement            = 'latest'
    xWebAdministration           = '3.2.0'
    ActiveDirectoryDsc           = '6.0.1'
    SecurityPolicyDsc            = '2.10.0.0'
    StorageDsc                   = '5.0.1'
    Chocolatey                   = '0.0.79'
    'Datum.ProtectedData'        = '0.0.1'
    'Datum.InvokeCommand'        = '0.1.1'
    xDscDiagnostics              = '2.8.0'
    CertificateDsc               = '4.7.0.0'
    DfsDsc                       = '4.4.0.0'
    WdsDsc                       = '0.11.0'
    xDhcpServer                  = '2.0.0.0'

}

$requiredChocolateyPackages = @{
    putty            = '0.73'
    winrar           = '5.90.0.20200401'
    notepadplusplus  = '7.8.5'
    'microsoft-edge' = '80.0.361.111'
    vscode           = '1.44.0'
    wireshark        = '3.2.2'
    winpcap          = '4.1.3.20161116'
}

$vsCodeDownloadUrl = 'https://go.microsoft.com/fwlink/?Linkid=852157'
$gitDownloadUrl = 'https://github.com/git-for-windows/git/releases/download/v2.25.0.windows.1/Git-2.25.0-64-bit.exe'
$vscodePowerShellExtensionDownloadUrl = 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/PowerShell/2020.1.0/vspackage'
$edgeDownloadUrl = 'http://dl.delivery.mp.microsoft.com/filestreamingservice/files/0af31313-0430-454d-908a-d55ce3df7b69/MicrosoftEdgeEnterpriseX64.msi'
$chromeDownloadUrl = 'https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BC9D94BD4-6037-E88E-2D5A-F6B7D7F8F4CF%7D%26lang%3Den%26browser%3D5%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Dempty/chrome/install/ChromeStandaloneSetup64.exe'
$notepadPlusPlusDownloadUrl = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v7.8.6/npp.7.8.6.Installer.x64.exe'

#-------------------------------------------------------------------------------------------------------------------------------------

#region Lab customizations
$lab = Get-Lab
$dc = Get-LabVM -Role ADDS | Select-Object -First 1
$domainName = $lab.Domains[0].Name
$devOpsServer = Get-LabVM -Role AzDevOps
$devOpsRole = $devOpsServer.Roles | Where-Object Name -eq AzDevOps
$devOpsPort = $originalPort = 8080
if ($devOpsRole.Properties.ContainsKey('Port'))
{
    $devOpsPort = $devOpsRole.Properties['Port']
}
if ($lab.DefaultVirtualizationEngine -eq 'Azure')
{
    $devOpsPort = (Get-LabAzureLoadBalancedPort -DestinationPort $devOpsPort -ComputerName $devOpsServer).Port
}
$buildWorkers = Get-LabVM -Role TfsBuildWorker
$sqlServer = Get-LabVM -Role SQLServer2017
$pullServer = Get-LabVM -Role DSCPullServer
$dscNodes = Get-LabVM -Filter { $_.Name -match 'file|web(\d){2}' }
$router = Get-LabVM -Role Routing
$nugetServer = Get-LabVM -Role AzDevOps
$firstDomain = (Get-Lab).Domains[0]
$nuGetApiKey = "$($firstDomain.Administrator.UserName)@$($firstDomain.Name):$($firstDomain.Administrator.Password)"

#Create Azure DevOps artifacts feed
$domainSid = Invoke-LabCommand -ActivityName 'Get domain SID' -ScriptBlock {

    $domainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext('Domain', $domainName)
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($domainContext).GetDirectoryEntry()
    $domainSid = [byte[]]$domain.Properties["objectSID"].Value
    $domainSid = (New-Object System.Security.Principal.SecurityIdentifier($domainSid, 0)).Value
    $domainSid

} -ComputerName $dc -Variable (Get-Variable -Name domainName) -NoDisplay -PassThru
#endregion

if (-not (Test-LabMachineInternetConnectivity -ComputerName $devOpsServer)) {
    Write-Error "The lab is not connected to the internet. Check the connectivity of the machine '$router' which is acting as a router." -ErrorAction Stop
}
Write-Host "Lab is connected to the internet, continuing with customizations."

$feedPermissions = @()
$feedPermissions += (New-Object pscustomobject -Property @{ role = 'administrator'; identityDescriptor = "System.Security.Principal.WindowsIdentity;$domainSid-1000" })
$feedPermissions += (New-Object pscustomobject -Property @{ role = 'contributor'; identityDescriptor = "System.Security.Principal.WindowsIdentity;$domainSid-513" })
$feedPermissions += (New-Object pscustomobject -Property @{ role = 'contributor'; identityDescriptor = "System.Security.Principal.WindowsIdentity;$domainSid-515" })
$feedPermissions += (New-Object pscustomobject -Property @{ role = 'reader'; identityDescriptor = 'System.Security.Principal.WindowsIdentity;S-1-5-7' })

$powerShellFeed = Get-LabTfsFeed -ComputerName $nugetServer -FeedName PowerShell -ErrorAction SilentlyContinue
if (-not $powerShellFeed)
{
    $powerShellFeed = New-LabTfsFeed -ComputerName $nugetServer -FeedName PowerShell -FeedPermissions $feedPermissions -PassThru -ErrorAction Stop
}
$replace = '$1{0}${{Separator}}{1}$4' -f $devOpsServer.Name, $originalPort
$powerShellFeed.NugetV2Url = $powerShellFeed.NugetV2Url -replace '(https:\/\/)([\w\.]+)(?<Separator>:)(\d{2,4})(.+)', $replace
Write-Host "Created artifacts feed 'PowerShell' on Azure DevOps Server '$nugetServer'"
$chocolateyFeed = Get-LabTfsFeed -ComputerName $nugetServer -FeedName Software -ErrorAction SilentlyContinue
if (-not $chocolateyFeed)
{
    $chocolateyFeed = New-LabTfsFeed -ComputerName $nugetServer -FeedName Software -FeedPermissions $feedPermissions -PassThru -ErrorAction Stop
}
$chocolateyFeed.NugetV2Url = $chocolateyFeed.NugetV2Url -replace '(https:\/\/)([\w\.]+)(?<Separator>:)(\d{2,4})(.+)', $replace
Write-Host "Created artifacts feed 'Software' on Azure DevOps Server '$nugetServer'"

# Web server
$deployUserName = (Get-LabVM -Role WebServer).GetCredential((Get-Lab)).UserName
$deployUserPassword = (Get-LabVM  -Role WebServer).GetCredential((Get-Lab)).GetNetworkCredential().Password

Copy-LabFileItem -Path "$PSScriptRoot\LabData\LabSite.zip" -ComputerName (Get-LabVM -Role WebServer)
Copy-LabFileItem -Path "$PSScriptRoot\LabData\DummyService.exe" -ComputerName (Get-LabVM -Role WebServer)
$desktopPath = Invoke-LabCommand -ComputerName $devOpsServer -ScriptBlock { [System.Environment]::GetFolderPath('Desktop') } -PassThru
Copy-LabFileItem -Path "$PSScriptRoot\LabData\Helpers.psm1" -ComputerName $devOpsServer -DestinationFolderPath $desktopPath

Invoke-LabCommand -Activity 'Setup Web Site' -ComputerName (Get-LabVM -Role WebServer) -ScriptBlock {

    New-Item -ItemType Directory -Path C:\PSConfSite
    Expand-Archive -Path C:\LabSite.zip -DestinationPath C:\PSConfSite -Force
    
    $pool = New-WebAppPool -Name PSConfSite
    $pool.processModel.identityType = 3 
    $pool.processModel.userName = $deployUserName 
    $pool.processModel.password = $deployUserPassword 
    $pool | Set-Item

    New-Website -name "PSConfSite" -PhysicalPath C:\PsConfSite -ApplicationPool "PSConfSite"  
} -Variable (Get-Variable deployUserName, deployUserPassword)

# File server
Invoke-LabCommand -Activity 'Creating folders and shares' -ComputerName (Get-LabVM -Role FileServer) -ScriptBlock {
    New-Item -ItemType Directory -Path C:\UserHome -Force
    foreach ($User in (Get-ADUser -Filter * | Select-Object -First 1000)) {
        New-Item -ItemType Directory -Path C:\UserHome -Name $User.samAccountName -Force
    }

    New-Item -ItemType Directory -Path C:\GroupData -Force

    'Accounting', 'Legal', 'HR', 'Janitorial' | ForEach-Object {
        New-Item -ItemType Directory -Path C:\GroupData -Name $_  -Force
    }

    New-SmbShare -Name Home -Path C:\UserHome -ErrorAction SilentlyContinue
    New-SmbShare -Name Department -Path C:\GroupData -ErrorAction SilentlyContinue
}

# Azure DevOps Server
$vscodeInstaller = Get-LabInternetFile -Uri $vscodeDownloadUrl -Path $labSources\SoftwarePackages -PassThru
$gitInstaller = Get-LabInternetFile -Uri $gitDownloadUrl -Path $labSources\SoftwarePackages -PassThru
Get-LabInternetFile -Uri $vscodePowerShellExtensionDownloadUrl -Path $labSources\SoftwarePackages\VSCodeExtensions\ps.vsix
$edgeInstaller = Get-LabInternetFile -Uri $edgeDownloadUrl -Path $labSources\SoftwarePackages -PassThru
$chromeInstaller = Get-LabInternetFile -Uri $chromeDownloadUrl -Path $labSources\SoftwarePackages -PassThru
$notepadPlusPlusInstaller = Get-LabInternetFile -Uri $notepadPlusPlusDownloadUrl -Path $labSources\SoftwarePackages -PassThru

Install-LabSoftwarePackage -Path $notepadPlusPlusInstaller.FullName -CommandLine /S -ComputerName (Get-LabVM)
Install-LabSoftwarePackage -Path $vscodeInstaller.FullName -CommandLine /SILENT -ComputerName $devOpsServer
Install-LabSoftwarePackage -Path $gitInstaller.FullName -CommandLine /SILENT -ComputerName ((@($devOpsServer) + $buildWorkers) | Select-Object -Unique)
Install-LabSoftwarePackage -Path $edgeInstaller.FullName -ComputerName $devOpsServer
Install-LabSoftwarePackage -Path $chromeInstaller.FullName -ComputerName ((@($devOpsServer) + $buildWorkers) | Select-Object -Unique) -CommandLine '/silent /install'
Invoke-LabCommand -ActivityName 'Enable WIA for Edge' -ScriptBlock {
    New-Item -Path HKCU:\SOFTWARE\Policies\Microsoft\Edge
    New-ItemProperty -Path HKCU:\SOFTWARE\Policies\Microsoft\Edge -Name AuthServerAllowlist -Value * -PropertyType String -Force
} -ComputerName ((@($devOpsServer) + $buildWorkers) | Select-Object -Unique)
Restart-LabVM -ComputerName $devOpsServer #somehow required to finish all parts of the VSCode installation

Copy-LabFileItem -Path $labSources\SoftwarePackages\VSCodeExtensions -ComputerName $devOpsServer
Invoke-LabCommand -ActivityName 'Install VSCode Extensions' -ComputerName $devOpsServer -ScriptBlock {
    dir -Path C:\VSCodeExtensions | ForEach-Object {
        code --install-extension $_.FullName 2>$null #suppressing errors
    }
} -NoDisplay

Invoke-LabCommand -ActivityName 'Create link on AzureDevOps desktop' -ComputerName $devOpsServer -ScriptBlock {
    $shell = New-Object -ComObject WScript.Shell
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    $shortcut = $shell.CreateShortcut("$desktopPath\DscWorkshop Project.url")
    $shortcut.TargetPath = "https://$($devOpsServer):$($originalPort)/AutomatedLab/DscWorkshop"
    $shortcut.Save()

    $shortcut = $shell.CreateShortcut("$desktopPath\CommonTasks Project.url")
    $shortcut.TargetPath = "https://$($devOpsServer):$($originalPort)/AutomatedLab/CommonTasks"
    $shortcut.Save()
    
    $shortcut = $shell.CreateShortcut("$desktopPath\PowerShell Feed.url")
    $shortcut.TargetPath = "https://$($devOpsServer):$($originalPort)/AutomatedLab/_packaging?_a=feed&feed=$($powerShellFeed.name)"
    $shortcut.Save()
    
    $shortcut = $shell.CreateShortcut("$desktopPath\Chocolatey Feed.url")
    $shortcut.TargetPath = "https://$($devOpsServer):$($originalPort)/AutomatedLab/_packaging?_a=feed&feed=$($chocolateyFeed.name)"
    $shortcut.Save()
    
    $shortcut = $shell.CreateShortcut("$desktopPath\SQL RS.url")
    $shortcut.TargetPath = "http://$sqlServer/Reports/browse/"
    $shortcut.Save()

    $shortcut = $shell.CreateShortcut("$desktopPath\Pull Server Endpoint.url")
    $shortcut.TargetPath = "https://$($pullServer.FQDN):$($originalPort)/PSDSCPullServer.svc/"
    $shortcut.Save()
} -Variable (Get-Variable -Name devOpsServer, sqlServer, powerShellFeed, chocolateyFeed, pullServer, originalPort)

#in server 2019 there seems to be an issue with dynamic DNS registration, doing this manually
foreach ($domain in (Get-Lab).Domains) {
    $vms = Get-LabVM -All -IncludeLinux | Where-Object { 
        $_.DomainName -eq $domain.Name -and
        $_.OperatingSystem -like '*2019*' -or
        $_.OperatingSystem -like '*CentOS*'
    }
    
    $dc = Get-LabVM -Role ADDS | Where-Object DomainName -eq $domain.Name | Select-Object -First 1
    
    Invoke-LabCommand -ActivityName 'Registering DNS records' -ScriptBlock {
        foreach ($vm in $vms) {
            if (-not (Get-DnsServerResourceRecord -Name $vm.Name -ZoneName $vm.DomainName -ErrorAction SilentlyContinue)) {
                "Running 'Add-DnsServerResourceRecord -ZoneName $($vm.DomainName) -IPv4Address $($vm.IpV4Address) -Name $($vm.Name) -A'"
                Add-DnsServerResourceRecord -ZoneName $vm.DomainName -IPv4Address $vm.IpV4Address -Name $vm.Name -A
            }
        }    
    } -ComputerName $dc -Variable (Get-Variable -Name vms) -PassThru
}

Invoke-LabCommand -ActivityName 'Get tested nuget.exe and register Azure DevOps Artifact Feed' -ComputerName (Get-LabVM) -ScriptBlock {

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -Force
    mkdir -Path C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet -Force
    Invoke-WebRequest -Uri 'https://nuget.org/nuget.exe' -OutFile C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet\nuget.exe -ErrorAction Stop

    Install-Module -Name PackageManagement -RequiredVersion 1.1.7.0 -Force -WarningAction SilentlyContinue
    Install-Module -Name PowerShellGet -RequiredVersion 1.6.0 -Force -WarningAction SilentlyContinue

    if (-not (Get-PSRepository -Name PowerShell -ErrorAction SilentlyContinue)) {
        Register-PSRepository -Name PowerShell -SourceLocation $powerShellFeed.NugetV2Url -PublishLocation $powerShellFeed.NugetV2Url -Credential $powerShellFeed.NugetCredential -InstallationPolicy Trusted -ErrorAction Stop
    }

} -Variable (Get-Variable -Name powerShellFeed)

Invoke-LabCommand -ActivityName 'Install Chocolatey to all lab VMs' -ScriptBlock {
    
    if (([Net.ServicePointManager]::SecurityProtocol -band 'Tls12') -ne 'Tls12') {
        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }
    
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    
    if (-not (Find-PackageProvider NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet
    }
    Import-PackageProvider -Name NuGet

    if (-not (Get-PackageSource -Name $chocolateyFeed.name -ErrorAction SilentlyContinue)) {
        Register-PackageSource -Name $chocolateyFeed.name -ProviderName NuGet -Location $chocolateyFeed.NugetV2Url -Trusted
    }
    
    choco source add -n=Software -s $chocolateyFeed.NugetV2Url

} -ComputerName (Get-LabVM) -Variable (Get-Variable -Name chocolateyFeed)

Remove-LabPSSession #this is required to make use of the new version of PowerShellGet

Write-Host "Restarting all $((Get-LabVM).Count) machines to make the installation of Chocolaty effective."
Write-Host 'Restarting Domain Controllers'
Restart-LabVM -ComputerName (Get-LabVM -Role ADDS) -Wait
Write-Host 'Restarting SQL Servers'
Restart-LabVM -ComputerName (Get-LabVM -Role SQLServer) -Wait
Write-Host 'Restarting all other machines'
Restart-LabVM -ComputerName (Get-LabVM -Role WebServer, FileServer, DSCPullServer, AzDevOps, SQLServer, HyperV) -Wait

Invoke-LabCommand -ActivityName 'Add Chocolatey internal source' -ScriptBlock {
    
    if (([Net.ServicePointManager]::SecurityProtocol -band 'Tls12') -ne 'Tls12') {
        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }
   
    choco source add -n=Software -s $chocolateyFeed.NugetV2Url

} -ComputerName (Get-LabVM) -Variable (Get-Variable -Name chocolateyFeed)

Invoke-LabCommand -ActivityName 'Downloading required modules from PSGallery' -ComputerName $devOpsServer -ScriptBlock {

    Write-Host "Installing $($requiredModules.Count) modules on $(hostname.exe) for pushing them to the lab"
    
    foreach ($requiredModule in $requiredModules.GetEnumerator()) {
        $installModuleParams = @{
            Name               = $requiredModule.Key
            Repository         = 'PSGallery'
            Force              = $true
            AllowClobber       = $true
            SkipPublisherCheck = $true
            WarningAction      = 'SilentlyContinue'
            ErrorAction        = 'Stop'
        }
        if ($requiredModule.Value -ne 'latest') {
            $installModuleParams.Add('RequiredVersion', $requiredModule.Value)
        }
        if ($requiredModule.Value -like '*-*') {
            #if pre-release version
            $installModuleParams.Add('AllowPrerelease', $true)
        }
        Write-Host "Installing module '$($requiredModule.Key)' with version '$($requiredModule.Value)'"
        Install-Module @installModuleParams
    }
} -Variable (Get-Variable -Name requiredModules)

Invoke-LabCommand -ActivityName 'Publishing required modules to internal repository' -ComputerName $devOpsServer -ScriptBlock {

    Write-Host "Publishing $($requiredModules.Count) modules to the internal repository (loop 1)"
    
    foreach ($requiredModule in $requiredModules.GetEnumerator()) {
        $module = Get-Module $requiredModule.Key -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
        $version = $module.Version
        if ($module.PrivateData.PSData.Prerelease) {
            $version = "$version-$($module.PrivateData.PSData.Prerelease)"
        }
        Write-Host "`t'$($module.Name) - $version'"
        if (-not (Find-Module -Name $module.Name -Repository PowerShell -ErrorAction SilentlyContinue)) {
            Publish-Module -Name $module.Name -RequiredVersion $version -Repository PowerShell -NuGetApiKey $nuGetApiKey -AllowPrerelease -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
    
    Write-Host "Publishing $($requiredModules.Count) modules to the internal repository (loop 2)"
    foreach ($requiredModule in $requiredModules.GetEnumerator()) {
        $module = Get-Module $requiredModule.Key -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
        $version = $module.Version
        if ($module.PrivateData.PSData.Prerelease) {
            $version = "$version-$($module.PrivateData.PSData.Prerelease)"
        }
        Write-Host "`t'$($module.Name) - $version'"
        if (-not (Find-Module -Name $module.Name -Repository PowerShell -ErrorAction SilentlyContinue)) {
            Publish-Module -Name $module.Name -RequiredVersion $version -Repository PowerShell -NuGetApiKey $nuGetApiKey -AllowPrerelease -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
    
    $modulesToUninstall = $requiredModules.GetEnumerator() | Where-Object Key -NotIn PowerShellGet, PackageManagement
    Write-Host "Uninstalling $($requiredModules.Count) modules"
    foreach ($module in $modulesToUninstall) {
        Write-Host "`t'$($module.Name)"
        Uninstall-Module -Name $module.Key -ErrorAction SilentlyContinue
    }
    foreach ($module in $modulesToUninstall) {
        Write-Host "`t'$($module.Name)"
        Uninstall-Module -Name $module.Key -ErrorAction SilentlyContinue
    }
} -Variable (Get-Variable -Name requiredModules, nuGetApiKey)

Invoke-LabCommand -ActivityName 'Publishing required Chocolatey packages to internal repository' -ScriptBlock {
    
    if (([Net.ServicePointManager]::SecurityProtocol -band 'Tls12') -ne 'Tls12') {
        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }
        
    Import-PackageProvider -Name NuGet
    $publicFeedUri = 'https://chocolatey.org/api/v2/'

    $tempFolder = mkdir C:\ChocoTemp -Force

    if (-not (Get-PackageSource -Name $chocolateyFeed.name -ErrorAction SilentlyContinue)) {
        Register-PackageSource -Name $chocolateyFeed.name -ProviderName NuGet -Location $chocolateyFeed.NugetV2Url -Trusted
    }
    if (-not (Get-PackageSource -Name Choco -ErrorAction SilentlyContinue)) {
        Register-PackageSource -Name Choco -ProviderName NuGet -Location $publicFeedUri
    }

    foreach ($kvp in $requiredChocolateyPackages.GetEnumerator()) {
        if (-not ($p = Find-Package -Name $kvp.Name -Source Choco)) {
            Write-Error "Package '$($kvp.Name)' could not be found at the source '$publicFeedUri'"
            continue
        }
        $p | Save-Package -Path $tempFolder
    }

    dir -Path $tempFolder | ForEach-Object {

        choco push $_.FullName -s $chocolateyFeed.NugetV2Url --api-key $chocolateyFeed.NugetApiKey

    }

} -ComputerName $devOpsServer -Variable (Get-Variable -Name chocolateyFeed, requiredChocolateyPackages)

Invoke-LabCommand -ActivityName 'Disable Git SSL Certificate Check' -ComputerName $devOpsServer, $buildWorkers -ScriptBlock {
    [System.Environment]::SetEnvironmentVariable('GIT_SSL_NO_VERIFY', '1', 'Machine')
}

Remove-LabPSSession #this is required to make use of the new version of PowerShellGet

Invoke-LabCommand -ActivityName 'Create Artifacts Share' -ComputerName $devOpsServer -ScriptBlock {
    $artifactsShareName = 'Artifacts'
    $artifactsSharePath = "C:\$artifactsShareName"

    Install-Module -Name NTFSSecurity -Repository PowerShell
    mkdir -Path $artifactsSharePath
    
    New-SmbShare -Name $artifactsShareName -Path $artifactsSharePath -FullAccess Everyone
    Add-NTFSAccess -Path $artifactsSharePath -Account Everyone -AccessRights FullControl
}

Invoke-LabCommand -ActivityName 'Create Share on Pull Server' -ComputerName $pullServer -ScriptBlock {
    Install-Module -Name NTFSSecurity -Repository PowerShell
    
    $dscModulesPath = 'C:\Program Files\WindowsPowerShell\DscService\Modules'
    $dscConfigurationPath = 'C:\Program Files\WindowsPowerShell\DscService\Configuration'

    New-SmbShare -Name DscModules -Path $dscModulesPath -FullAccess Everyone
    Add-NTFSAccess -Path $dscModulesPath -Account Everyone -AccessRights FullControl
    
    New-SmbShare -Name DscConfiguration -Path $dscConfigurationPath -FullAccess Everyone
    Add-NTFSAccess -Path $dscConfigurationPath -Account Everyone -AccessRights FullControl
}

Invoke-LabCommand -ActivityName 'Setting the worker service account to local system to be able to write to deployment path' -ComputerName $buildWorkers -ScriptBlock {
    $services = Get-CimInstance -ClassName Win32_Service -Filter 'Name like "vsts%"'
    foreach ($service in $services) {    
        $service | Invoke-CimMethod -MethodName Change -Arguments @{ StartName = 'LocalSystem' } | Out-Null
    }
}

Invoke-LabCommand -ActivityName "Install module 'xDscDiagnostics' required by DSC JEA endpoint" -ScriptBlock {
    Install-Module -Name xDscDiagnostics -Repository PowerShell -Force
} -ComputerName $dscNodes

Invoke-LabCommand -ActivityName "Create DscData JEA endpoint for allowing the LCM controller to send additional data to the DSC pull server" `
-FilePath $PSScriptRoot\..\DscTaggingData\New-DscDataEndpoint.ps1 -ComputerName $pullServer

Restart-LabVM -ComputerName $devOpsServer, $buildWorkers -Wait

Write-Host "2. - Creating Snapshot 'AfterCustomizations'" -ForegroundColor Magenta
Checkpoint-LabVM -All -SnapshotName AfterCustomizations
