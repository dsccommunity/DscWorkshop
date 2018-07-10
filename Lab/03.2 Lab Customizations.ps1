#region Lab customizations
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
$tfsServer = Get-LabVM -Role Tfs2018
$tfsWorker = Get-LabVM -Role TfsBuildWorker

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
        code --install-extension $_.FullName
    }
} -NoDisplay

Invoke-LabCommand -ActivityName 'Create link to TFS' -ComputerName $tfsServer -ScriptBlock {
    $shell = New-Object -ComObject WScript.Shell
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    $shortcut = $shell.CreateShortcut("$desktopPath\TFS.url")
    $shortcut.TargetPath = 'https://DSCTFS01:8080/AutomatedLab/PSConfEU2018'
    $shortcut.Save()
    
    $shortcut = $shell.CreateShortcut("$desktopPath\ProGet.url")
    $shortcut.TargetPath = 'http://DSCPull01/'
    $shortcut.Save()
}

Invoke-LabCommand -ActivityName 'Getting required modules and publishing them to ProGet' -ComputerName $tfsServer -ScriptBlock {
    $requiredModules = 'powershell-yaml' #, 'BuildHelpers', 'datum' , 'DscBuildHelpers', 'InvokeBuild', 'PackageManagement', 'Pester', 'PowerShellGet', 'ProtectedData', 'PSDepend', 'PSDeploy', 'PSScriptAnalyzer', 'xDSCResourceDesigner', 'xPSDesiredStateConfiguration'

    Install-PackageProvider -Name NuGet -Force
    mkdir -Path C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet -Force
    Invoke-WebRequest -Uri 'https://nuget.org/nuget.exe' -OutFile C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet\nuget.exe
    Install-Module -Name $requiredModules -Repository PSGallery -Force -AllowClobber -SkipPublisherCheck -WarningAction SilentlyContinue
    
    $path = "http://DSCPull01.contoso.com/nuget/PowerShell"
    if (-not (Get-PSRepository -Name Internal -ErrorAction SilentlyContinue)) {
        Register-PSRepository -Name Internal -SourceLocation $path -PublishLocation $path -InstallationPolicy Trusted
    }
    foreach ($requiredModule in $requiredModules) {
        $module = Get-Module $requiredModule -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
        if (-not (Find-Module -Name $requiredModule -Repository Internal -ErrorAction SilentlyContinue)) {
            Publish-Module -Name $requiredModule -RequiredVersion $module.Version -Repository Internal -NuGetApiKey 'Install@Contoso.com:Somepass1' -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
    
    foreach ($requiredModule in $requiredModules) {
        Write-Host "Publishing module '$requiredModule'"
        $module = Get-Module $requiredModule -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
        if (-not (Find-Module -Name $requiredModule -Repository Internal -ErrorAction SilentlyContinue)) {
            Publish-Module -Name $requiredModule -RequiredVersion $module.Version -Repository Internal -NuGetApiKey 'Install@Contoso.com:Somepass1' -Force #-ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
    }
    
    foreach ($requiredModule in $requiredModules) {
        Uninstall-Module -Name $requiredModule -ErrorAction SilentlyContinue
    }
    foreach ($requiredModule in $requiredModules) {
        Uninstall-Module -Name $requiredModule -ErrorAction SilentlyContinue
    }

    if (Get-PSRepository -Name Internal) {
        Unregister-PSRepository -Name Internal
    }
}

<# The Default PSGallery is not removed as the build process does not support an internal repository yet.
        Invoke-LabCommand -ActivityName 'Register ProGet Gallery' -ComputerName (Get-LabVM) -ScriptBlock {
        Unregister-PSRepository -Name PSGallery
        $path = "http://DSCPull01.contoso.com/nuget/PowerShell"
        Register-PSRepository -Name Internal -SourceLocation $path -PublishLocation $path -InstallationPolicy Trusted
        }
#>

Invoke-LabCommand -ActivityName 'Disable Git SSL Certificate Check' -ComputerName $tfsServer, $tfsWorker -ScriptBlock {
    [System.Environment]::SetEnvironmentVariable('GIT_SSL_NO_VERIFY', '1', 'Machine')
}

Restart-LabVM -ComputerName $tfsServer, $tfsWorker -Wait

Invoke-LabCommand -ActivityName 'Setting the worker service account to local system to be able to write to deployment path' -ComputerName $tfsWorker -ScriptBlock {
    $services = Get-CimInstance -ClassName Win32_Service -Filter 'Name like "vsts%"'
    foreach ($service in $services)
    {    
        $service | Invoke-CimMethod -MethodName Change -Arguments @{ StartName = 'LocalSystem' } | Out-Null
        $service | Restart-Service
    }
}

Write-Host "2. - Creating Snapshot 'AfterCustomizations'" -ForegroundColor Magenta
Checkpoint-LabVM -All -SnapshotName AfterCustomizations