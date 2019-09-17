#region Lab customizations
$devOpsServer = Get-LabVM -Role AzDevOps
$buildWorkers = Get-LabVM -Role TfsBuildWorker
$sqlServer = Get-LabVM -Role SQLServer2017
$pullServer = Get-LabVM -Role DSCPullServer
$router = Get-LabVM -Role Routing
$progetServer = Get-LabVM | Where-Object { $_.PostInstallationActivity.RoleName -like 'ProGet*' }
$progetUrl = "http://$($progetServer.FQDN)/nuget/PowerShell"
$firstDomain = (Get-Lab).Domains[0]
$nuGetApiKey = "$($firstDomain.Administrator.UserName)@$($firstDomain.Name):$($firstDomain.Administrator.Password)"
 
$requiredModules = @{
    'powershell-yaml'            = 'latest'
    BuildHelpers                 = 'latest'
    datum                        = 'latest'
    DscBuildHelpers              = 'latest'
    InvokeBuild                  = 'latest'
    Pester                       = 'latest'
    ProtectedData                = 'latest'
    PSDepend                     = 'latest'
    PSDeploy                     = 'latest'
    PSScriptAnalyzer             = 'latest'
    xDSCResourceDesigner         = 'latest'
    xPSDesiredStateConfiguration = '8.9.0.0'
    ComputerManagementDsc        = '6.5.0.0'
    NetworkingDsc                = '7.3.0.0'
    NTFSSecurity                 = 'latest'
    JeaDsc                       = '0.6.5'
    XmlContentDsc                = '0.0.1'
    PowerShellGet                = 'latest'
    PackageManagement            = 'latest'
    xWebAdministration           = '2.7.0.0'
    ActiveDirectoryDsc           = '4.0.0.0'
    SecurityPolicyDsc            = '2.9.0.0'
    StorageDsc                    = '4.8.0.0'
}

if (-not (Test-LabMachineInternetConnectivity -ComputerName $devOpsServer)) {
    Write-Error "The lab is not connected to the internet. Check the connectivity of the machine '$router' which is acting as a router." -ErrorAction Stop
}
Write-Host "Lab is connected to the internet, continuing with customizations."

# Web server
$deployUserName = (Get-LabVm -Role WebServer).GetCredential((Get-Lab)).UserName
$deployUserPassword = (Get-LabVm  -Role WebServer).GetCredential((Get-Lab)).GetNetworkCredential().Password

Copy-LabFileItem -Path "$PSScriptRoot\LabData\LabSite.zip" -ComputerName (Get-LabVM -Role WebServer)
Copy-LabFileItem -Path "$PSScriptRoot\LabData\DummyService.exe" -ComputerName (Get-LabVM -Role WebServer)
$desktopPath = Invoke-LabCommand -ComputerName $devOpsServer -ScriptBlock { [System.Environment]::GetFolderPath('Desktop') } -PassThru
Copy-LabFileItem -Path "$PSScriptRoot\LabData\Helpers.psm1" -ComputerName $devOpsServer -DestinationFolderPath $desktopPath

Invoke-LabCommand -Activity 'Setup Web Site' -ComputerName (Get-LabVm  -Role WebServer) -ScriptBlock {

    New-Item -ItemType Directory -Path C:\PSConfSite
    Expand-Archive -Path C:\LabSite.zip -DestinationPath C:\PSConfSite -Force
    
    $pool = New-WebAppPool -Name PSConfSite
    $pool.processModel.identityType = 3 
    $pool.processModel.userName = $deployUserName 
    $pool.processModel.password = $deployUserPassword 
    $pool | Set-Item

    New-Website -name "PSConfSite" -PhysicalPath C:\PsConfSite -ApplicationPool "PSConfSite"  
} -Variable (Get-Variable deployUserName, deployUserPassword)

Invoke-LabCommand -ActivityName 'Add ProGet DNS A record' -ComputerName (Get-LabVM -Role RootDC) -ScriptBlock {
    Add-DnsServerResourceRecord -ZoneName $pullServer.DomainName -IPv4Address $pullServer.IpV4Address -Name ProGet -A
} -Variable (Get-Variable -Name pullServer)

# File server
Invoke-LabCommand -Activity 'Creating folders and shares' -ComputerName (Get-LabVM -Role FileServer) -ScriptBlock {
    New-Item -ItemType Directory -Path C:\UserHome
    foreach ($User in (Get-ADUser -Filter * | Select-Object -First 1000)) {
        New-Item -ItemType Directory -Path C:\UserHome -Name $User.samAccountName
    }

    New-Item -ItemType Directory -Path C:\GroupData

    'Accounting', 'Legal', 'HR', 'Janitorial' | ForEach-Object { New-Item -ItemType Directory -Path C:\GroupData -Name $_ }

    New-SmbShare -Name Home -Path C:\UserHome
    New-SmbShare -Name Department -Path C:\GroupData
}

# Azure DevOps Server
Get-LabInternetFile -Uri https://go.microsoft.com/fwlink/?Linkid=852157 -Path $labSources\SoftwarePackages\VSCodeSetup.exe
Get-LabInternetFile -Uri https://github.com/git-for-windows/git/releases/download/v2.16.2.windows.1/Git-2.16.2-64-bit.exe -Path $labSources\SoftwarePackages\Git.exe
Get-LabInternetFile -Uri https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/PowerShell/1.6.0/vspackage -Path $labSources\SoftwarePackages\VSCodeExtensions\ps.vsix

Install-LabSoftwarePackage -Path $labSources\SoftwarePackages\VSCodeSetup.exe -CommandLine /SILENT -ComputerName $devOpsServer
Install-LabSoftwarePackage -Path $labSources\SoftwarePackages\Git.exe -CommandLine /SILENT -ComputerName ((@($devOpsServer) + $buildWorkers) | Select-Object -Unique)
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
    $shortcut.TargetPath = "https://$($devOpsServer):8080/AutomatedLab/DscWorkshop"
    $shortcut.Save()

    $shortcut = $shell.CreateShortcut("$desktopPath\CommonTasks Project.url")
    $shortcut.TargetPath = "https://$($devOpsServer):8080/AutomatedLab/CommonTasks"
    $shortcut.Save()
    
    $shortcut = $shell.CreateShortcut("$desktopPath\ProGet.url")
    $shortcut.TargetPath = "http://$progetServer/"
    $shortcut.Save()
    
    $shortcut = $shell.CreateShortcut("$desktopPath\SQL RS.url")
    $shortcut.TargetPath = "http://$sqlServer/Reports/browse/"
    $shortcut.Save()

    $shortcut = $shell.CreateShortcut("$desktopPath\Pull Server Endpoint.url")
    $shortcut.TargetPath = "https://$($pullServer.FQDN):8080/PSDSCPullServer.svc/"
    $shortcut.Save()
} -Variable (Get-Variable -Name devOpsServer, sqlServer, proGetServer, pullServer)

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

Invoke-LabCommand -ActivityName 'Get tested nuget.exe and register ProGet Repository' -ComputerName (Get-LabVM) -ScriptBlock {

    Install-PackageProvider -Name NuGet -Force
    mkdir -Path C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet -Force
    Invoke-WebRequest -Uri 'https://nuget.org/nuget.exe' -OutFile C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet\nuget.exe -ErrorAction Stop

    Install-Module -Name PackageManagement -RequiredVersion 1.1.7.0 -Force -WarningAction SilentlyContinue
    Install-Module -Name PowerShellGet -RequiredVersion 1.6.0 -Force -WarningAction SilentlyContinue

    if (-not (Get-PSRepository -Name PowerShell -ErrorAction SilentlyContinue)) {
        Register-PSRepository -Name PowerShell -SourceLocation $progetUrl -PublishLocation $progetUrl -InstallationPolicy Trusted -ErrorAction Stop
    }

} -Variable (Get-Variable -Name progetUrl)

Remove-LabPSSession #this is required to make use of the new version of PowerShellGet

Restart-LabVM -ComputerName $pullServer

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
        Write-Host "Installing module '$($requiredModule.Key)'"
        Install-Module @installModuleParams
    }
} -Variable (Get-Variable -Name requiredModules)

Invoke-LabCommand -ActivityName 'Publishing required modules to internal ProGet repository' -ComputerName $devOpsServer -ScriptBlock {

    Write-Host "Publishing $($requiredModules.Count) modules to the internal gallery (loop 1)"
    
    foreach ($requiredModule in $requiredModules.GetEnumerator()) {
        $module = Get-Module $requiredModule.Key -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
        Write-Host "`t'$($module.Name) - $($module.Version)'"
        if (-not (Find-Module -Name $requiredModule.Key -Repository PowerShell -ErrorAction SilentlyContinue)) {
            Publish-Module -Name $requiredModule.Key -RequiredVersion $module.Version -Repository PowerShell -NuGetApiKey $nuGetApiKey -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
    
    Write-Host "Publishing $($requiredModules.Count) modules to the internal gallery (loop 2)"
    foreach ($requiredModule in $requiredModules.GetEnumerator()) {
        $module = Get-Module $requiredModule.Key -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
        Write-Host "`t'$($module.Name) - $($module.Version)'"
        if (-not (Find-Module -Name $requiredModule.Key -Repository PowerShell -ErrorAction SilentlyContinue)) {
            Publish-Module -Name $requiredModule.Key -RequiredVersion $module.Version -Repository PowerShell -NuGetApiKey $nuGetApiKey -Force
        }
    }
    
    Write-Host "Uninstalling $($requiredModules.Count) modules"
    foreach ($requiredModule in $requiredModules.GetEnumerator()) {
        Uninstall-Module -Name $requiredModule.Key -ErrorAction SilentlyContinue
    }
    foreach ($requiredModule in $requiredModules.GetEnumerator()) {
        Uninstall-Module -Name $requiredModule.Key -ErrorAction SilentlyContinue
    }
} -Variable (Get-Variable -Name requiredModules, nuGetApiKey)

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

Restart-LabVM -ComputerName $devOpsServer, $buildWorkers -Wait

Write-Host "2. - Creating Snapshot 'AfterCustomizations'" -ForegroundColor Magenta
Checkpoint-LabVM -All -SnapshotName AfterCustomizations