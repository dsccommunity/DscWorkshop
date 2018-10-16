#region Lab customizations
$tfsServer = Get-LabVM -Role Tfs2018
$tfsWorker = Get-LabVM -Role TfsBuildWorker
$sqlServer = Get-LabVM -Role SQLServer2017
$pullServer = Get-LabVM -Role DSCPullServer
$souter = Get-LabVM -Role Routing
$progetServer = Get-LabVM | Where-Object { $_.PostInstallationActivity.RoleName -like 'ProGet*' }
$progetUrl = "http://$($progetServer.FQDN)/nuget/PowerShell"

if (-not (Test-LabMachineInternetConnectivity -ComputerName $tfsServer))
{
    Write-Error "The lab is not connected to the internet. Check the connectivity of the machine '$router' which is acting as a router." -ErrorAction Stop
}
Write-Host "Lab is connected to the internet, continuing with customizations."

# Web server
$deployUserName = (Get-LabVm -Role WebServer).GetCredential((Get-Lab)).UserName
$deployUserPassword = (Get-LabVm  -Role WebServer).GetCredential((Get-Lab)).GetNetworkCredential().Password

Copy-LabFileItem -Path "$PSScriptRoot\LabData\LabSite.zip" -ComputerName (Get-LabVm  -Role WebServer)

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

$vm = Get-LabVM -ComputerName DSCPull01
Invoke-LabCommand -ActivityName 'Add ProGet DNS A record' -ComputerName (Get-LabVM -Role RootDC) -ScriptBlock {
    Add-DnsServerResourceRecord -ZoneName $vm.DomainName -IPv4Address $vm.IpV4Address -Name ProGet -A
} -Variable (Get-Variable -Name vm)

# File server
Invoke-LabCommand -Activity 'Creating folders and shares' -ComputerName (Get-LabVM -Role FileServer) -ScriptBlock {
    New-Item -ItemType Directory -Path C:\UserHome
    foreach ($User in (Get-ADUser -Filter * | Select-Object -First 1000)) {
        New-Item -ItemType Directory -Path C:\UserHome -Name $User.samAccountName
    }

    New-Item -ItemType Directory -Path C:\GroupData

    'Accounting', 'Legal', 'HR', 'Janitorial' | ForEach-Object {New-Item -ItemType Directory -Path C:\GroupData -Name $_}

    New-SmbShare -Name Home -Path C:\UserHome
    New-SmbShare -Name Department -Path C:\GroupData
}

# TFS Server
Get-LabInternetFile -Uri https://go.microsoft.com/fwlink/?Linkid=852157 -Path $labSources\SoftwarePackages\VSCodeSetup.exe
Get-LabInternetFile -Uri https://github.com/git-for-windows/git/releases/download/v2.16.2.windows.1/Git-2.16.2-64-bit.exe -Path $labSources\SoftwarePackages\Git.exe
New-Item -ItemType Directory -Path $labSources\SoftwarePackages\VSCodeExtensions -ErrorAction SilentlyContinue | Out-Null
Get-LabInternetFile -Uri https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/PowerShell/1.6.0/vspackage -Path $labSources\SoftwarePackages\VSCodeExtensions\ps.vsix

Install-LabSoftwarePackage -Path $labSources\SoftwarePackages\VSCodeSetup.exe -CommandLine /SILENT -ComputerName $tfsServer
Install-LabSoftwarePackage -Path $labSources\SoftwarePackages\Git.exe -CommandLine /SILENT -ComputerName $tfsServer
Restart-LabVM -ComputerName $tfsServer #somehow required to finish all parts of the VSCode installation

Copy-LabFileItem -Path $labSources\SoftwarePackages\VSCodeExtensions -ComputerName $tfsServer
Invoke-LabCommand -ActivityName 'Install VSCode Extensions' -ComputerName $tfsServer -ScriptBlock {
    dir -Path C:\VSCodeExtensions | ForEach-Object {
        code --install-extension $_.FullName 2>$null #suppressing errors
    }
} -NoDisplay

Invoke-LabCommand -ActivityName 'Create link to TFS' -ComputerName $tfsServer -ScriptBlock {
    $shell = New-Object -ComObject WScript.Shell
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    $shortcut = $shell.CreateShortcut("$desktopPath\DscWorkshop TFS Project.url")
    $shortcut.TargetPath = "http://$($tfsServer):8080/AutomatedLab/DscWorkshop"
    $shortcut.Save()

    $shortcut = $shell.CreateShortcut("$desktopPath\CommonTasks TFS Project.url")
    $shortcut.TargetPath = "http://$($tfsServer):8080/AutomatedLab/CommonTasks"
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
} -Variable (Get-Variable -Name tfsServer, sqlServer, proGetServer, pullServer)

#in server 2019 there seems to be an issue with dynamic DNS registration, doing this manually
foreach ($domain in (Get-Lab).Domains)
{
    $vms = Get-LabVM -All -IncludeLinux | Where-Object { 
        $_.DomainName -eq $domain.Name -and
        $_.OperatingSystem -like '*2019*' -or
        $_.OperatingSystem -like '*CentOS*'
    }
    
    $dc = Get-LabVM -Role ADDS | Where-Object DomainName -eq $domain.Name | Select-Object -First 1
    
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

Invoke-LabCommand -ActivityName 'Getting required modules and publishing them to ProGet' -ComputerName $tfsServer -ScriptBlock {

    $requiredModules = 'powershell-yaml', 'BuildHelpers', 'datum' , 'DscBuildHelpers', 'InvokeBuild', 'Pester', 'ProtectedData', 'PSDepend', 'PSDeploy', 'PSScriptAnalyzer', 'xDSCResourceDesigner', 'xPSDesiredStateConfiguration', 'ComputerManagementDsc', 'NetworkingDsc', 'NTFSSecurity'

    Write-Host "Installing $($requiredModules.Count) modules on $(hostname.exe) for pushing them to the lab"
    Install-Module -Name $requiredModules -Repository PSGallery -Force -AllowClobber -SkipPublisherCheck -WarningAction SilentlyContinue -ErrorAction Stop

    #these modules have been downloaded in a previous step with a dedicated version and should only be published but not dowloaded again.
    $requiredModules += 'PackageManagement'
    $requiredModules += 'PowerShellGet'
    
    Write-Host "Publishing $($requiredModules.Count) modules to the internal gallery (loop 1)"
    foreach ($requiredModule in $requiredModules) {
        Write-Host "`t'$requiredModule'"
        $module = Get-Module $requiredModule -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
        if (-not (Find-Module -Name $requiredModule -Repository PowerShell -ErrorAction SilentlyContinue)) {
            Publish-Module -Name $requiredModule -RequiredVersion $module.Version -Repository PowerShell -NuGetApiKey 'Install@Contoso.com:Somepass1' -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
    
    Write-Host "Publishing $($requiredModules.Count) modules to the internal gallery (loop 2)"
    foreach ($requiredModule in $requiredModules) {
        Write-Host "`t'$requiredModule'"
        $module = Get-Module $requiredModule -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
        if (-not (Find-Module -Name $requiredModule -Repository PowerShell -ErrorAction SilentlyContinue)) {
            Publish-Module -Name $requiredModule -RequiredVersion $module.Version -Repository PowerShell -NuGetApiKey 'Install@Contoso.com:Somepass1' -Force #-ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
    
    Write-Host "Uninstalling $($requiredModules.Count) modules"
    foreach ($requiredModule in $requiredModules) {
        Uninstall-Module -Name $requiredModule -ErrorAction SilentlyContinue
    }
    foreach ($requiredModule in $requiredModules) {
        Uninstall-Module -Name $requiredModule -ErrorAction SilentlyContinue
    }
}

Invoke-LabCommand -ActivityName 'Disable Git SSL Certificate Check' -ComputerName $tfsServer, $tfsWorker -ScriptBlock {
    [System.Environment]::SetEnvironmentVariable('GIT_SSL_NO_VERIFY', '1', 'Machine')
}

Remove-LabPSSession #this is required to make use of the new version of PowerShellGet

Invoke-LabCommand -ActivityName 'Create Aftifacts Share' -ComputerName $tfsServer -ScriptBlock {
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

Invoke-LabCommand -ActivityName 'Setting the worker service account to local system to be able to write to deployment path' -ComputerName $tfsWorker -ScriptBlock {
    $services = Get-CimInstance -ClassName Win32_Service -Filter 'Name like "vsts%"'
    foreach ($service in $services)
    {    
        $service | Invoke-CimMethod -MethodName Change -Arguments @{ StartName = 'LocalSystem' } | Out-Null
    }
}

Restart-LabVM -ComputerName $tfsServer, $tfsWorker -Wait

Write-Host "2. - Creating Snapshot 'AfterCustomizations'" -ForegroundColor Magenta
Checkpoint-LabVM -All -SnapshotName AfterCustomizations