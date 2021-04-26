param (
    [Parameter()]
    $JeaModuleName = 'DSC',

    [Parameter()]
    $EndpointName = 'DscData',

    [Parameter()]
    $AllowedPrincipals = ("$($env:USERDOMAIN)\Domain Users", "$($env:USERDOMAIN)\Domain Computers")
)

function Send-DscTaggingData {
    param(
        [Parameter(Mandatory)]
        [string]$AgentId,

        [Parameter(Mandatory)]
        [pscustomObject]$Data
    )

    function Invoke-SqlQuery
    {
        param(
            [Parameter(Mandatory)]
            [string]$Database,

            [Parameter(Mandatory)]
            [string]$Query,

            [Parameter(Mandatory)]
            [string]$Server,

            [switch]$NonQuery
        )

        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = "Server=$Server;Database=$Database;Trusted_Connection=True;"
        $connection.Open()

        $cmd = New-Object System.Data.SqlClient.SqlCommand
        $cmd.CommandText = $Query
        $cmd.Connection = $connection
    
        if ($NonQuery) {
            [void]$cmd.ExecuteNonQuery()
        }
        else {
            $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
            $sqlAdapter.SelectCommand = $cmd

            $dataSet = New-Object System.Data.DataSet
            [void]$sqlAdapter.Fill($dataSet)
    
            $dataSet.Tables[0]
        }

        $connection.Close()
    }

    function Get-DscSqlServerName
    {
        $pattern = 'Data Source=(?<DataSource>[\w-_]+)|Server=tcp:(?<Server>[\w-_]+)'
        $webConfigPath = 'C:\inetpub\PSDSCPullServer\web.config'

        $dscConfig = [xml](Get-Content -Path $webConfigPath)
        $dbconnectionstr = ($dscConfig.configuration.appSettings.add | Where-Object key -eq dbconnectionstr).value

        if (-not ($dbconnectionstr -match $pattern))
        {
            Write-Error "Could not read SQL server name from '$webConfigPath'"
            return
        }

        if ($Matches.DataSource) {
            $Matches.DataSource
        }
        else {
            $Matches.Server
        }
    }
    
    $path = Join-Path -Path ([System.Environment]::GetFolderPath('CommonApplicationData')) -ChildPath 'Dsc\LcmController'
    if (-not (Test-Path -Path $path)) {
        mkdir -Path $path
    }

    $sqlServerName = Get-DscSqlServerName
    $update = $false
    Write-Host "DscDataEndpoint uses SQL Server '$sqlServerName'."

    $Data.psobject.Properties.Remove('RunspaceId')
    $Data.psobject.Properties.Add([System.Management.Automation.PSNoteProperty]::new('Timestamp', [string](Get-Date)))
    $Data.psobject.Properties.Add([System.Management.Automation.PSNoteProperty]::new('AgentId', $agentId))

    $cmd = "SELECT AgentId FROM dbo.TaggingData WHERE AgentID = '$($Data.AgentId)'"
    $existingRecord = Invoke-SqlQuery -Database DSC -Query $cmd -Server $sqlServerName

    if ($existingRecord) {
        $cmd = 'UPDATE dbo.TaggingData SET '
        foreach ($property in $Data.psobject.Properties | Where-Object Name -NotLike PS*) {
            $cmd += "$($property.Name) = '$($property.Value)', "
        }
        $cmd = $cmd.Substring(0, $cmd.Length - 2)
        $cmd += "WHERE AgentId = '$($Data.AgentId)'"
        $update = $true
    }
    else {
        $cmd = 'INSERT INTO dbo.TaggingData ('

        $cmd += ($Data.psobject.Properties | Where-Object Name -NotLike PS*).Name -join ', '
        $cmd += ') VALUES ('
        $cmd += "'" + (($Data.psobject.Properties | Where-Object Name -NotLike PS*).Value -join "', '") + "'"
        $cmd += ')'
    }

    Invoke-SqlQuery -Database DSC -Query $cmd -Server $sqlServerName -NonQuery

    $logItem = [pscustomobject]@{
        CurrentTime  = Get-Date
        AgentId      = $AgentId
        ConnectdUser = $PSSenderInfo.ConnectedUser
        BuildNumber  = $Data.BuildNumber
        Environment  = $Data.Environment
        GitCommitId  = $Data.GitCommitId
        UpdateRecord = $update
    } | Export-Csv -Path "$path\SendDscTaggingData.txt" -Append -Force
}

function DscTaggingRole
{
    $roleName = $MyInvocation.MyCommand.Name
    New-PSRoleCapabilityFile -Path C:\$roleName.psrc `
    -ModulesToImport Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility `
    -VisibleProviders FileSystem `
    -VisibleCmdlets Get-Command, Get-Help `
    -VisibleFunctions Send-DscTaggingData `
    -FunctionDefinitions `
    @{ Name = 'Send-DscTaggingData'; ScriptBlock = (Get-Command -Name Send-DscTaggingData).ScriptBlock }

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
        "$($env:USERDOMAIN)\Domain Users" = @{ RoleCapabilities = 'DscTaggingRole' }
        "$($env:USERDOMAIN)\Domain Computers" = @{ RoleCapabilities = 'DscTaggingRole' }
    }

    if (Get-PSSessionConfiguration -Name $EndpointName -ErrorAction SilentlyContinue)
    {
        Unregister-PSSessionConfiguration -Name $EndpointName
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

$modulePath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\$JeaModuleName"
Remove-Item -Path $modulePath -Recurse -Force -ErrorAction SilentlyContinue

DscTaggingRole

$trigger = New-JobTrigger -At (Get-Date).AddMinutes(1) -Once
Register-ScheduledJob -Name StartWinRmService  -ScriptBlock {
    Start-Service -Name WinRM
} -Trigger $trigger -ErrorAction SilentlyContinue

Register-CustomPSSessionConfiguration -EndpointName $EndpointName -AllowedPrincipals $AllowedPrincipals

Unregister-ScheduledJob -Name StartWinRmService
