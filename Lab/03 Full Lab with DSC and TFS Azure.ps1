#the lab name is not static here as it has to be globally unique 
$labName = "psconf$((1..6 | ForEach-Object { [char[]](97..122) | Get-Random }) -join '')"
$azureContext = 'YOUR Azure JSON context here - Use Save-AzureRmContext after having selected your subscription!'
$azureLocation = 'West Europe' # Please use West Europe for the conference

#region Lab setup
#--------------------------------------------------------------------------------------------------------------------
#----------------------- CHANGING ANYTHING BEYOND THIS LINE SHOULD NOT BE REQUIRED ----------------------------------
#----------------------- + EXCEPT FOR THE LINES STARTING WITH: REMOVE THE COMMENT TO --------------------------------
#----------------------- + EXCEPT FOR THE LINES CONTAINING A PATH TO AN ISO OR APP   --------------------------------
#--------------------------------------------------------------------------------------------------------------------

#create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -DefaultVirtualizationEngine Azure
Add-LabAzureSubscription -Path $azureContext -DefaultLocationName $azureLocation

#make the network definition
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 192.168.111.0/24

#and the domain definition with the domain admin account
Add-LabDomainDefinition -Name contoso.com -AdminUser Install -AdminPassword Somepass1

#these credentials are used for connecting to the machines. As this is a lab we use clear-text passwords
Set-LabInstallationCredential -Username Install -Password Somepass1

# Add the reference to our necessary ISO files
Add-LabIsoImageDefinition -Name Tfs2018 -Path $labsources\ISOs\tfsserver2018.2_rc1.iso

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network'         = $labName
    'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
    'Add-LabMachineDefinition:DomainName'      = 'contoso.com'
    'Add-LabMachineDefinition:DnsServer1'      = '192.168.111.10'
    'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2016 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:AzureProperties' =  @{RoleSize = 'Standard_A2_v2'}
}

#The PostInstallationActivity is just creating some users
$postInstallActivity = @()
$postInstallActivity += Get-LabPostInstallationActivity -ScriptFileName 'New-ADLabAccounts 2.0.ps1' -DependencyFolder $labSources\PostInstallationActivities\PrepareFirstChildDomain
$postInstallActivity += Get-LabPostInstallationActivity -ScriptFileName PrepareRootDomain.ps1 -DependencyFolder $labSources\PostInstallationActivities\PrepareRootDomain
Add-LabMachineDefinition -Name DSCDC01 -Memory 512MB -Roles RootDC -IpAddress 192.168.111.10 -PostInstallationActivity $postInstallActivity

# The good, the bad and the ugly
Add-LabMachineDefinition -Name DSCCASQL01 -Memory 4GB -Roles CaRoot, SQLServer2017

# DSC Pull Server with SQL server backing, TFS Build Worker
$roles = @(
    Get-LabMachineRoleDefinition -Role DSCPullServer -Properties @{ DoNotPushLocalModules = 'true'; DatabaseEngine = 'mdb' }
    Get-LabMachineRoleDefinition -Role TfsBuildWorker
    Get-LabMachineRoleDefinition -Role WebServer
)
$proGetRole = Get-LabPostInstallationActivity -CustomRole ProGet5 -Properties @{
    ProGetDownloadLink = 'https://s3.amazonaws.com/cdn.inedo.com/downloads/proget/ProGetSetup5.0.10.exe'
    SqlServer          = 'DSCCASQL01'
}

Add-LabMachineDefinition -Name DSCPULL01 -Memory 2GB -Roles $roles -PostInstallationActivity $proGetRole

# Build Server
Add-LabMachineDefinition -Name DSCTFS01 -Memory 1GB -Roles Tfs2018

# DSC target nodes - our legacy VMs with an existing configuration

# Your run-of-the-mill file server in Dev
Add-LabMachineDefinition -Name "DSCFile01" -Memory 1GB -OperatingSystem 'Windows Server 2016 Datacenter' -Roles FileServer
# and Prod
Add-LabMachineDefinition -Name "DSCFile02" -Memory 1GB -OperatingSystem 'Windows Server 2016 Datacenter' -Roles FileServer

# The ubiquitous web server in Dev
Add-LabMachineDefinition -Name "DSCWeb01" -Memory 1GB -OperatingSystem 'Windows Server 2016 Datacenter' -Roles WebServer
# and Prod
Add-LabMachineDefinition -Name "DSCWeb02" -Memory 1GB -OperatingSystem 'Windows Server 2016 Datacenter' -Roles WebServer


Install-Lab

Enable-LabCertificateAutoenrollment -Computer -User
Install-LabWindowsFeature -ComputerName (Get-LabVM -Role DSCPullServer, FileServer, WebServer, Tfs2018) -FeatureName RSAT-AD-Tools
Install-LabSoftwarePackage -Path $labsources\SoftwarePackages\Notepad++.exe -CommandLine /S -ComputerName (Get-LabVM)
#endregion

#region Lab customizations

# Web server
$deployUserName = (Get-LabVm -Role WebServer).GetCredential((Get-Lab)).UserName
$deployUserPassword = (Get-LabVm  -Role WebServer).GetCredential((Get-Lab)).GetNetworkCredential().Password

Copy-LabFileItem -Path "$PSScriptRoot\LabData\LabSite.zip" -ComputerName (Get-LabVm -Role WebServer)

Invoke-LabCommand -ComputerName (Get-LabVm  -Role WebServer) -ScriptBlock {

    New-Item -ItemType Directory -Path C:\PSConfSite
    Expand-Archive -Path C:\LabSite.zip -DestinationPath C:\PSConfSite -Force
    
    $pool = New-WebAppPool -Name PSConfSite
    $pool.processModel.identityType = 3 
    $pool.processModel.userName = $deployUserName 
    $pool.processModel.password = $deployUserPassword 
    $pool | Set-Item

    Remove-WebSite -Name 'DefaultWebSite' -ErrorAction SilentlyContinue
    New-Website -name "PSConfSite" -PhysicalPath C:\PsConfSite -ApplicationPool "PSConfSite"  
} -Variable (Get-Variable deployUserName, deployUserPassword)

# File server
Install-LabWindowsFeature -ComputerName (Get-LabVm -Role FileServer) -FeatureName RSAT-AD-Tools

Invoke-LabCommand -ComputerName (Get-LabVm -Role FileServer) -ScriptBlock {
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
    $shortcut.TargetPath = 'http://dscpull01:8624/'
    $shortcut.Save()
}

Invoke-LabCommand -ActivityName 'Getting required modules and publishing them to ProGet' -ComputerName $tfsServer -ScriptBlock {
    $requiredModules = 'BuildHelpers', 'datum', 'DscBuildHelpers', 'InvokeBuild', 'PackageManagement', 'Pester', 'powershell-yaml', 'PowerShellGet', 'ProtectedData', 'PSDepend', 'PSDeploy', 'PSScriptAnalyzer', 'xDSCResourceDesigner', 'xPSDesiredStateConfiguration'

    Install-PackageProvider -Name NuGet -Force
    mkdir -Path C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet -Force
    Invoke-WebRequest -Uri 'https://nuget.org/nuget.exe' -OutFile C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet\nuget.exe
    Install-Module -Name $requiredModules -Repository PSGallery -Force -AllowClobber -SkipPublisherCheck -WarningAction SilentlyContinue
    
    $path = "http://DSCPull01.contoso.com:8624/nuget/Internal"
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
    $path = "http://DSCPull01.contoso.com:8624/nuget/Internal"
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

# Create a new release pipeline
$buildSteps = @(
    @{
        "enabled"         = $true
        "continueOnError" = $false
        "alwaysRun"       = $false
        "displayName"     = "Execute Build.ps1"
        "task"            = @{
            "id"          = "e213ff0f-5d5c-4791-802d-52ea3e7be1f1" # We need to refer to a valid ID - refer to Get-LabBuildStep for all available steps
            "versionSpec" = "*"
        }
        "inputs"          = @{
            scriptType          = "filePath"
            scriptName          = ".Build.ps1"
            arguments           = "-resolveDependency"
            failOnStandardError = $false
        }
    }
    @{
        enabled         = $True
        continueOnError = $False
        alwaysRun       = $False
        displayName     = 'Publish test results' # e.g. Publish Test Results $(testResultsFiles) or Publish Test Results
        task            = @{
            id          = '0b0f01ed-7dde-43ff-9cbb-e48954daf9b1'
            versionSpec = '*'
        }
        inputs          = @{
            testRunner       = 'NUnit' # Type: pickList, Default: JUnit, Mandatory: True
            testResultsFiles = '**/testresults.xml' # Type: filePath, Default: **/TEST-*.xml, Mandatory: True

        }
    }
)

# Which will make use of TFS, clone the stuff, add the necessary build step, publish the test results and so on
Write-ScreenInfo 'Creating TFS project and cloning from GitHub...' -NoNewLine
New-LabReleasePipeline -ProjectName 'PSConfEU2018' -SourceRepository https://github.com/AutomatedLab/DscWorkshop -BuildSteps $buildSteps
cd "$labSources\GitRepositories\DscWorkshop"
git checkout master
git pull origin master
git -c http.sslverify=false push tfs 
Write-ScreenInfo done

Show-LabDeploymentSummary -Detailed