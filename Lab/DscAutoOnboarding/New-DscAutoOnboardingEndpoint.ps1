param (
    [Parameter()]
    $JeaModuleName = 'DSC',

    [Parameter()]
    $EndpointName = 'DSC',

    [Parameter()]
    $AllowedPrincipals = ("$($env:USERDOMAIN)\Domain Users", "$($env:USERDOMAIN)\Domain Computers")
)

function Add-NodeToAdGroup
{
    param(
        [Parameter(Mandatory)]
        [string]$Identity
    )

    $groupName = 'DscNodes'

    try
    {
        $g = Get-ADGroup -Identity $groupName
    }
    catch
    {
        Write-Error "Could not read group '$groupName'. The error was '$($_.Exception.Message)'."
    }

    $g | Add-ADGroupMember -Members $Identity
}

function Add-DscNode
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$NodeName,

        [Parameter()]
        [byte[]]$Certificate,

        [Parameter(Mandatory)]
        [string]$Environment,

        [Parameter(Mandatory)]
        [string]$Role,

        [Parameter(Mandatory)]
        [string]$Location,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter(Mandatory)]
        [ipaddress]$Ipaddress,

        [switch]$SkipPush
    )
    
    $temp = "C:\$([System.Guid]::NewGuid())"
    mkdir -Path $temp | Out-Null
    git clone https://contoso\install:Somepass1@dscdo01:8080/AutomatedLab/DscWorkshop/_git/DscWorkshop $temp 2>&1 | Out-Null

    $nodePath = "$temp\DSC\DscConfigData\AllNodes\$Environment"
    if (-not (Test-Path -Path $nodePath))
    {
        mkdir -Path $nodePath -Force
    }
    $certificatePath = 'C:\DscNodeCertificates'

    if (-not (Test-Path -Path $certificatePath))
    {
        New-Item -Path $certificatePath -ItemType Directory | Out-Null
    }

    $node = [ordered]@{
        NodeName = $NodeName
        Environment = $Environment
        Role = $Role
        Description = $Description
        Location = $Location

        NetworkIpConfiguration = @{
            IpAddress = $Ipaddress.IPAddressToString
        }

        PSDscAllowPlainTextPassword = $true
        PSDscAllowDomainUser = $true

        LcmConfig = @{
            ConfigurationRepositoryWeb = @{
                Server = @{
                    ConfigurationNames = $NodeName
                }
            }
        }
    }

    $yaml = $node | ConvertTo-Yaml

    if (Test-Path -Path "$nodePath\$NodeName.yml")
    {
        Write-Error "The node '$NodeName' does already exist"
        return
    }
    $yaml | Out-File -FilePath "$nodePath\$NodeName.yml"

    if (-not $SkipPush)
    {
        Push-Location -Path $nodePath
        git add .
        git commit -m "--Added new node '$NodeName'" | Out-Null
        $result = git push 2>&1
        Pop-Location
    }

    Remove-Item -Path $temp -Recurse -Force

    $nodeCertPath = Join-Path -Path $certificatePath -ChildPath "$NodeName.cer"
    [System.IO.File]::WriteAllBytes($nodeCertPath, $Certificate)

    return $yaml
}

function Get-DscMetaMofFile
{
    param (
        [Parameter(Mandatory)]
        [string]$NodeName,

        [Parameter()]
        [datetime]$After
    )

    $mofFile = dir -Path 'C:\Artifacts\DscWorkshop CI' -Filter "$NodeName.meta.mof" -Recurse | Where-Object CreationTime -gt $After | Sort-Object -Property CreationTime -Descending
    if (-not $mofFile)
    {
        Write-Error "Could not find a Meta MOF file for node '$NodeName' created after '$After'."
        return
    }
    $mofFile = $mofFile[0]

    @{
        FullName = $mofFile.FullName
        Content = $mofFile | Get-Content
        CreationTime = $mofFile.CreationTime
    }
}

function DscRegistration
{
    $roleName = $MyInvocation.MyCommand.Name
    New-PSRoleCapabilityFile -Path C:\$roleName.psrc `
    -ModulesToImport Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility, ActiveDirectory, powershell-yaml `
    -VisibleProviders FileSystem `
    -VisibleCmdlets Get-Command, Get-Help `
    -FunctionDefinitions `
    @{ Name = 'Add-NodeToAdGroup'; ScriptBlock = (Get-Command -Name Add-NodeToAdGroup).ScriptBlock },
    @{ Name = 'Add-DscNode'; ScriptBlock = (Get-Command -Name Add-DscNode).ScriptBlock },
    @{ Name = 'Get-DscMetaMofFile'; ScriptBlock = (Get-Command -Name Get-DscMetaMofFile).ScriptBlock }

    # Create the RoleCapabilities folder and copy in the PSRC file
    $modulePath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\$JeaModuleName"
    $rcFolder = Join-Path -Path $modulePath -ChildPath "RoleCapabilities"
    if (-not (Test-Path -Path $rcFolder))
    {
        mkdir -Path $rcFolder -Force | Out-Null
    }
    Copy-Item -Path C:\$roleName.psrc -Destination $rcFolder
}

function Register-CustomPSSessionConfiguration
{
    param(
        [string[]]$AllowedPrincipals,
        
        [Parameter(Mandatory)]
        [string]$EndpointName
    )
    
    if (-not (Test-Path -Path C:\PowerShellTranscripts))
    {
        mkdir -Path C:\PowerShellTranscripts | Out-Null
    }

    New-PSSessionConfigurationFile -Path c:\$EndpointName.pssc `
    -SessionType RestrictedRemoteServer `
    -LanguageMode RestrictedLanguage `
    -RunAsVirtualAccount `
    -ExecutionPolicy Unrestricted `
    -TranscriptDirectory "C:\PowerShellTranscripts\$EndpointName" `
    -RoleDefinitions @{
        "$($env:USERDOMAIN)\Domain Users" = @{ RoleCapabilities = 'DscRegistration' }
        "$($env:USERDOMAIN)\Domain Computers" = @{ RoleCapabilities = 'DscRegistration' }
    }

    Register-PSSessionConfiguration -Name $EndpointName -Path C:\$EndpointName.pssc

    $pssc = Get-PSSessionConfiguration -Name $EndpointName
    $psscSd = New-Object System.Security.AccessControl.CommonSecurityDescriptor($false, $false, $pssc.SecurityDescriptorSddl)

    foreach ($allowedPrincipal in $AllowedPrincipals)
    {
        $account = New-Object System.Security.Principal.NTAccount($allowedPrincipal)
        $accessType = "Allow"
        $accessMask = 268435456
        $inheritanceFlags = "None"
        $propagationFlags = "None"
        $psscSd.DiscretionaryAcl.AddAccess($accessType,$account.Translate([System.Security.Principal.SecurityIdentifier]),$accessMask,$inheritanceFlags,$propagationFlags)
    }

    Set-PSSessionConfiguration -Name $EndpointName -SecurityDescriptorSddl $psscSd.GetSddlForm("All")
    
    # Create a folder for the module
    $modulePath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\$JeaModuleName"
    if (-not (Test-Path -Path $modulePath))
    {
        mkdir -Path $modulePath | Out-Null
    }

    # Create an empty script module and module manifest. At least one file in the module folder must have the same name as the folder itself.
    $path = Join-Path -Path $modulePath -ChildPath "$JeaModuleName.psm1"
    if (-not (Test-Path -Path $path))
    {
        New-Item -ItemType File -Path $path | Out-Null
    }
    
    $path = Join-Path -Path $modulePath -ChildPath "$JeaModuleName.psd1"
    if (-not (Test-Path -Path $path))
    {
        New-ModuleManifest -Path $path -RootModule "$JeaModuleName.psm1"
    }    
}

Install-WindowsFeature -Name RSAT-Role-Tools
Install-Module powershell-yaml -Repository powershell

$modulePath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\$JeaModuleName"
Remove-Item -Path $modulePath -Recurse -Force -ErrorAction SilentlyContinue

DscRegistration

Register-CustomPSSessionConfiguration -EndpointName $EndpointName -AllowedPrincipals $AllowedPrincipals
