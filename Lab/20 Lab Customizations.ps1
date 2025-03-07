param (
    [Parameter()]
    [string]$LabName = 'DscWorkshop'
)

if ((Get-Lab -ErrorAction SilentlyContinue).Name -ne $LabName)
{
    try
    {
        Write-host "Importing lab '$LabName'"
        Import-Lab -Name $LabName -NoValidation -ErrorAction Stop
    }
    catch
    {
        Write-Host "Lab '$LabName' could not be imported. Trying to find a lab with a name starting with 'DscWorkshop*'"
        $possibleLabs = Get-Lab -List | Where-Object { $_ -like 'DscWorkshop*' }
        if ($possibleLabs.Count -gt 1)
        {
            Write-Error "There are multiple 'DscWorkshop' labs ($($possibleLabs -join ', ')). Please remove the ones you don't need."
            exit
        }
        else
        {
            Write-Host "Importing lab '$possibleLabs'"
            Import-Lab -Name $possibleLabs -NoValidation -ErrorAction Stop
        }
    }
}

$here = $PSScriptRoot

Write-Host 'Stopping all VMs...'
Stop-LabVM -All -Wait
Write-Host 'Starting Domain Controller VMs...'
Start-LabVM -RoleName ADDS -Wait
Write-Host 'Starting SQL Server VMs...'
Start-LabVM -RoleName SQLServer -Wait
Write-Host 'Starting Azure DevOps VMs...'
Start-LabVM -RoleName AzDevOps -Wait
Write-Host 'Starting remaining VMs...'
Start-LabVM -RoleName FileServer, WebServer, HyperV -Wait
Write-Host 'Restarted all machines'

$requiredModules = Import-PowerShellDataFile -Path "$here\..\RequiredModules.psd1"
$requiredModules.Remove('PSDependOptions')

#Adding modules that are not defined in the PSDepend files but required in the lab
$requiredModules.NTFSSecurity = 'latest'
$requiredModules.PSDepend = 'latest'
$requiredModules.PSDeploy = 'latest'
$requiredModules.PowerShellGet = '2.2.5'
$requiredModules.ProtectedData = 'latest'
$requiredModules.'Sampler.DscPipeline' = '0.2.0-preview0015'

$requiredChocolateyPackages = @{
    putty                 = '0.76'
    winrar                = '6.0.2'
    notepadplusplus       = '8.1.9'
    vscode                = '1.61.2'
    wireshark             = '3.4.9'
    winpcap               = '4.1.3.20161116'
    'gitversion.portable' = '5.7.0'
    firefox               = '94.0.1'
}

#-------------------------------------------------------------------------------------------------------------------------------------

#region Lab customizations
$lab = Get-Lab
$dc = Get-LabVM -Role ADDS | Select-Object -First 1
$domainName = $lab.Domains[0].Name
$devOpsServer = Get-LabVM -Role AzDevOps
$devOpsRole = $devOpsServer.Roles | Where-Object Name -EQ AzDevOps
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
$sqlServer = Get-LabVM -Role SQLServer2017, SQLServer2019
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
    $domainSid = [byte[]]$domain.Properties['objectSID'].Value
    $domainSid = (New-Object System.Security.Principal.SecurityIdentifier($domainSid, 0)).Value
    $domainSid

} -ComputerName $dc -Variable (Get-Variable -Name domainName) -NoDisplay -PassThru
#endregion

if (-not (Test-LabMachineInternetConnectivity -ComputerName $devOpsServer))
{
    Write-Error "The lab is not connected to the internet. Check the connectivity of the machine '$router' which is acting as a router." -ErrorAction Stop
}
Write-Host 'Lab is connected to the internet, continuing with customizations.'

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
$deployUserPassword = (Get-LabVM -Role WebServer).GetCredential((Get-Lab)).GetNetworkCredential().Password

Copy-LabFileItem -Path "$here\LabData\LabSite.zip" -ComputerName (Get-LabVM -Role WebServer)
Copy-LabFileItem -Path "$here\LabData\DummyService.exe" -ComputerName (Get-LabVM -Role WebServer)
$desktopPath = Invoke-LabCommand -ComputerName $devOpsServer -ScriptBlock { [System.Environment]::GetFolderPath('Desktop') } -PassThru
Copy-LabFileItem -Path "$here\LabData\Helpers.psm1" -ComputerName $devOpsServer -DestinationFolderPath $desktopPath

Invoke-LabCommand -Activity 'Setup Web Site' -ComputerName (Get-LabVM -Role WebServer) -ScriptBlock {

    New-Item -ItemType Directory -Path C:\PSConfSite
    Expand-Archive -Path C:\LabSite.zip -DestinationPath C:\PSConfSite -Force

    $pool = New-WebAppPool -Name PSConfSite
    $pool.processModel.identityType = 3
    $pool.processModel.userName = $deployUserName
    $pool.processModel.password = $deployUserPassword
    $pool | Set-Item

    New-Website -name 'PSConfSite' -PhysicalPath C:\PsConfSite -ApplicationPool 'PSConfSite'
} -Variable (Get-Variable deployUserName, deployUserPassword)

#in server 2019 there seems to be an issue with dynamic DNS registration, doing this manually
foreach ($domain in (Get-Lab).Domains)
{
    $vms = Get-LabVM -All -IncludeLinux | Where-Object {
        $_.DomainName -eq $domain.Name -and
        $_.OperatingSystem -like '*2019*' -or
        $_.OperatingSystem -like '*CentOS*'
    }

    $dc = Get-LabVM -Role ADDS | Where-Object DomainName -EQ $domain.Name | Select-Object -First 1

    Invoke-LabCommand -ActivityName 'Registering DNS records' -ScriptBlock {
        foreach ($vm in $vms)
        {
            if (-not (Get-DnsServerResourceRecord -Name $vm.Name -ZoneName $vm.DomainName -ErrorAction SilentlyContinue))
            {
                "Running 'Add-DnsServerResourceRecord -ZoneName $($vm.DomainName) -IPv4Address $($vm.IpV4Address) -Name $($vm.Name) -A'"
                Add-DnsServerResourceRecord -ZoneName $vm.DomainName -IPv4Address $vm.IpV4Address -Name $vm.Name -A
            }
        }
    } -ComputerName $dc -Variable (Get-Variable -Name vms) -PassThru
}

Remove-LabPSSession #this is required to make use of the new version of PowerShellGet

Invoke-LabCommand -ActivityName 'Get tested nuget.exe and register Azure DevOps Artifact Feed' -ComputerName (Get-LabVM) -ScriptBlock {

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -Force
    mkdir -Path C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet -Force
    Invoke-WebRequest -Uri 'https://nuget.org/nuget.exe' -OutFile C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet\nuget.exe -ErrorAction Stop

    Install-Module -Name PackageManagement -RequiredVersion 1.1.7.0 -Force -WarningAction SilentlyContinue
    Install-Module -Name PowerShellGet -RequiredVersion 1.6.0 -Force -WarningAction SilentlyContinue

    if (-not (Get-PSRepository -Name PowerShell -ErrorAction SilentlyContinue))
    {
        Register-PSRepository -Name PowerShell -SourceLocation $powerShellFeed.NugetV2Url -PublishLocation $powerShellFeed.NugetV2Url -Credential $powerShellFeed.NugetCredential -InstallationPolicy Trusted -ErrorAction Stop
    }

} -Variable (Get-Variable -Name powerShellFeed)

#Removing session so the new version of PowerShellGet will be used.
Remove-LabPSSession

Invoke-LabCommand -ActivityName 'Downloading required modules from PSGallery' -ComputerName $devOpsServer -ScriptBlock {

    Write-Host "Installing $($requiredModules.Count) modules on $(hostname.exe) for pushing them to the lab"
    $repositoryName = 'PowerShell'

    foreach ($requiredModule in $requiredModules.GetEnumerator())
    {
        $installModuleParams = @{
            Name               = $requiredModule.Key
            Repository         = 'PSGallery'
            AllowClobber       = $true
            SkipPublisherCheck = $true
            Force              = $true
            WarningAction      = 'SilentlyContinue'
            ErrorAction        = 'Stop'
        }
        if ($requiredModule.Value -ne 'latest')
        {
            $installModuleParams.Add('RequiredVersion', $requiredModule.Value)
        }
        if ($requiredModule.Value -like '*-*' -or $requiredModule.Value -eq 'Latest')
        {
            #if pre-release version
            $installModuleParams.Add('AllowPrerelease', $true)
        }
        Write-Host "Installing module '$($requiredModule.Key)' with version '$($requiredModule.Value)'"
        Install-Module @installModuleParams
    }

    $installedModules = Get-InstalledModule
    $loopCount = 3
    Write-Host "Publishing modules to internal gallery $loopCount times. This is reuqired due to cross dependencies within the module list."
    foreach ($loop in (1..$loopCount))
    {
        Write-Host "Publishing $($installedModules.Count) modules to the internal repository (loop $loop)"
        foreach ($installedModule in $installedModules)
        {
            $findParams = @{
                Name            = $installedModule.Name
                RequiredVersion = $installedModule.Version
                Repository      = $repositoryName
                AllowPrerelease = $true
                ErrorAction     = 'SilentlyContinue'
            }

            if (-not (Find-Module @findParams))
            {
                $publishModuleParams = @{
                    Name            = $installedModule.Name
                    RequiredVersion = $installedModule.Version
                    Repository      = $repositoryName
                    NuGetApiKey     = $nuGetApiKey
                    AllowPrerelease = $true
                    ErrorAction     = 'SilentlyContinue'
                    WarningAction   = 'SilentlyContinue'
                }

                #Removing ErrorAction and WarningAction to see errors in the last publish loop.
                if ($loop -eq $loopCount)
                {
                    $publishModuleParams.Remove('ErrorAction')
                    $publishModuleParams.Remove('WarningAction')
                }
                Publish-Module @publishModuleParams

                Write-Host "Published the module '$($installedModule.Name)' with version '$($installedModule.Version)' is already available repository '$repositoryName'"
            }
            else
            {
                Write-Host "The module '$($installedModule.Name)' with version '$($installedModule.Version)' is already available repository '$repositoryName'"
            }
        }
    }

    foreach ($installedModule in $installedModules)
    {
        $moduleVersion = if ($installedModule.Version -like '*-*')
        {
            ($installedModule.Version -split '-')[0]
        }
        else
        {
            $installedModule.Version
        }
        Remove-Item -Path "C:\Program Files\WindowsPowerShell\Modules\$($installedModule.Name)\$moduleVersion" -Recurse -Force -ErrorAction SilentlyContinue
    }

    Get-ChildItem -Path 'C:\Program Files\WindowsPowerShell\Modules' -Directory | Where-Object { $_.GetFileSystemInfos().Count -eq 0 } | Remove-Item

} -Variable (Get-Variable -Name requiredModules, nuGetApiKey)

Invoke-LabCommand -ActivityName 'Install Chocolatey to all lab VMs' -ScriptBlock {

    if (([Net.ServicePointManager]::SecurityProtocol -band 'Tls12') -ne 'Tls12')
    {
        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }

    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    if (-not (Find-PackageProvider NuGet -ErrorAction SilentlyContinue))
    {
        Install-PackageProvider -Name NuGet
    }
    Import-PackageProvider -Name NuGet

    if (-not (Get-PackageSource -Name $chocolateyFeed.name -ErrorAction SilentlyContinue))
    {
        Register-PackageSource -Name $chocolateyFeed.name -ProviderName NuGet -Location $chocolateyFeed.NugetV2Url -Trusted
    }

    choco source add -n=Software -s $chocolateyFeed.NugetV2Url

} -ComputerName (Get-LabVM) -Variable (Get-Variable -Name chocolateyFeed) -ThrottleLimit 1 #to prevent error 429: Too Many Requests

Remove-LabPSSession #this is required to make use of the new version of PowerShellGet

Write-Host "Restarting all $((Get-LabVM).Count) machines to make the installation of Chocolaty effective."
Write-Host 'Restarting Domain Controllers'
Restart-LabVM -ComputerName (Get-LabVM -Role ADDS) -Wait
Write-Host 'Restarting SQL Servers'
Restart-LabVM -ComputerName (Get-LabVM -Role SQLServer) -Wait
Write-Host 'Restarting all other machines'
Restart-LabVM -ComputerName (Get-LabVM -Role WebServer, FileServer, DSCPullServer, AzDevOps, SQLServer, HyperV) -Wait

Invoke-LabCommand -ActivityName 'Add Chocolatey internal source' -ScriptBlock {

    if (([Net.ServicePointManager]::SecurityProtocol -band 'Tls12') -ne 'Tls12')
    {
        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }

    choco source add -n=Software -s $chocolateyFeed.NugetV2Url

} -ComputerName (Get-LabVM) -Variable (Get-Variable -Name chocolateyFeed)

Invoke-LabCommand -ActivityName 'Publishing required Chocolatey packages to internal repository' -ScriptBlock {

    if (([Net.ServicePointManager]::SecurityProtocol -band 'Tls12') -ne 'Tls12')
    {
        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }

    Import-PackageProvider -Name NuGet
    $publicFeedUri = 'https://chocolatey.org/api/v2/'

    $tempFolder = mkdir C:\ChocoTemp -Force

    if (-not (Get-PackageSource -Name $chocolateyFeed.name -ErrorAction SilentlyContinue))
    {
        Register-PackageSource -Name $chocolateyFeed.name -ProviderName NuGet -Location $chocolateyFeed.NugetV2Url -Trusted
    }
    if (-not (Get-PackageSource -Name Choco -ErrorAction SilentlyContinue))
    {
        Register-PackageSource -Name Choco -ProviderName NuGet -Location $publicFeedUri
    }

    foreach ($kvp in $requiredChocolateyPackages.GetEnumerator())
    {
        Write-Host "Saving package '$($kvp.Name)', " -NoNewline
        if (-not ($p = Find-Package -Name $kvp.Name -Source Choco))
        {
            Write-Error "Package '$($kvp.Name)' could not be found at the source '$publicFeedUri'"
            continue
        }
        $p | Save-Package -Path $tempFolder
    }

    Get-ChildItem -Path $tempFolder | ForEach-Object {

        Write-Host "Publishing package '$($_.FullName)'"
        choco push $_.FullName -s $chocolateyFeed.NugetV2Url --api-key $chocolateyFeed.NugetApiKey

    }

} -ComputerName $devOpsServer -Variable (Get-Variable -Name chocolateyFeed, requiredChocolateyPackages)

Invoke-LabCommand -ActivityName 'Disable Git SSL Certificate Check' -ComputerName $devOpsServer, $buildWorkers -ScriptBlock {
    [System.Environment]::SetEnvironmentVariable('GIT_SSL_NO_VERIFY', '1', 'Machine')
}

Remove-LabPSSession #this is required to make use of the new version of PowerShellGet

# File server
Invoke-LabCommand -Activity 'Creating folders and shares' -ComputerName (Get-LabVM -Role FileServer) -ScriptBlock {
    New-Item -ItemType Directory -Path C:\UserHome -Force
    foreach ($User in (Get-ADUser -Filter * | Select-Object -First 1000))
    {
        New-Item -ItemType Directory -Path C:\UserHome -Name $User.samAccountName -Force
    }

    New-Item -ItemType Directory -Path C:\GroupData -Force

    'Accounting', 'Legal', 'HR', 'Janitorial' | ForEach-Object {
        New-Item -ItemType Directory -Path C:\GroupData -Name $_ -Force
    }

    New-SmbShare -Name Home -Path C:\UserHome -ErrorAction SilentlyContinue
    New-SmbShare -Name Department -Path C:\GroupData -ErrorAction SilentlyContinue
}

# Software Installation
$softwarePackages = Import-PowerShellDataFile -Path "$here\20 SoftwarePackages.psd1"
foreach ($softwarePackage in $softwarePackages.GetEnumerator())
{
    $destinationFolder = if ($softwarePackage.Value.DestinationFolder)
    {
        "$labSources\$($softwarePackage.Value.DestinationFolder)"
    }
    else
    {
        "$labSources\SoftwarePackages"
    }
    Write-Host "Downloading '$($softwarePackage.Name)' ($($softwarePackage.Value.Url)) to '$destinationFolder'" -NoNewline
    $softwarePackage.Value.Installer = Get-LabInternetFile -Uri $softwarePackage.Value.Url -Path $labSources\SoftwarePackages -PassThru
    Write-Host done.

    if ($softwarePackage.Value.Roles)
    {
        $machines = if ($softwarePackage.Value.Roles -eq 'All')
        {
            Get-LabVM
        }
        else
        {
            $roles = $softwarePackage.Value.Roles -split ','
            foreach ($role in $roles)
            {
                $role = $role.Trim()
                Get-LabVM -Role $role
            }
        }
        Write-Host "Installing '$($softwarePackage.Name)' to machines '$($machines)'" -NoNewline
        Install-LabSoftwarePackage -ComputerName $machines -Path $softwarePackage.Value.Installer.FullName -CommandLine $softwarePackage.Value.CommandLine
        Write-Host done.
    }

}

Restart-LabVM -ComputerName $devOpsServer -Wait #somehow required to finish all parts of the VSCode installation

Copy-LabFileItem -Path $labSources\SoftwarePackages\VSCodeExtensions -ComputerName $devOpsServer
Invoke-LabCommand -ActivityName 'Install VSCode Extensions' -ComputerName $devOpsServer -ScriptBlock {
    Get-ChildItem -Path C:\VSCodeExtensions | ForEach-Object {
        code --install-extension $_.FullName 2>$null #suppressing errors
    }
} -NoDisplay

Invoke-LabCommand -ActivityName 'Create link on AzureDevOps desktop' -ComputerName $devOpsServer -ScriptBlock {
    $shell = New-Object -ComObject WScript.Shell
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    $shortcut = $shell.CreateShortcut("$desktopPath\DscWorkshop Project.url")
    $shortcut.TargetPath = "https://$($devOpsServer):$($originalPort)/AutomatedLab/DscWorkshop"
    $shortcut.Save()

    $shortcut = $shell.CreateShortcut("$desktopPath\DscConfig.Demo Project.url")
    $shortcut.TargetPath = "https://$($devOpsServer):$($originalPort)/AutomatedLab/DscConfig.Demo"
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
    foreach ($service in $services)
    {
        $service | Invoke-CimMethod -MethodName Change -Arguments @{ StartName = 'LocalSystem' } | Out-Null
    }
}

Invoke-LabCommand -ActivityName "Install module 'xDscDiagnostics' required by DSC JEA endpoint" -ScriptBlock {
    Install-Module -Name xDscDiagnostics -Repository PowerShell -Force
} -ComputerName $dscNodes

Write-Host '----------------------------------------------------------------------------------------------------------' -ForegroundColor Magenta
Write-Host 'It is expected to see errors from here as the WinRM servicer on the pull server gets restarted' -ForegroundColor Magenta
Write-Host 'After the errors you should have the DscData endpoint installed (Get-PSSessionConfiguration -Name DscData)' -ForegroundColor Magenta
Write-Host '----------------------------------------------------------------------------------------------------------' -ForegroundColor Magenta

Invoke-LabCommand -ActivityName 'Create DscData JEA endpoint for allowing the LCM controller to send additional data to the DSC pull server' `
    -FilePath $PSScriptRoot\DscTaggingData\New-DscDataEndpoint.ps1 -ComputerName $pullServer

Restart-LabVM -ComputerName $devOpsServer, $buildWorkers -Wait

Write-Host "2. - Creating Snapshot 'AfterCustomizations'" -ForegroundColor Magenta
Checkpoint-LabVM -All -SnapshotName AfterCustomizations
