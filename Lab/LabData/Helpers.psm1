function Update-LabDscNodes {
    $path = Join-Path (Get-LabLatestArtifactsPath) -ChildPath MOF
    $computerNames = dir -Path $path -Filter *.mof | Select-Object -ExpandProperty BaseName

    Update-DscConfiguration -ComputerName $computerNames -Wait -Verbose
}

function Set-LabDscLatestMetaMofs {
    $latestBuild = Get-LabLatestArtifactsPath
    $path = Join-Path -Path $latestBuild -ChildPath MetaMOF

    Set-DscLocalConfigurationManager -Path $path -Verbose -Force
}

function Update-LabDscNodes {
    $computers = Get-ADComputer -Filter { Name -like 'DSCWeb*' -or Name -like 'DSCFile*' } | Select-Object -ExpandProperty DNSHostName

    Update-DscConfiguration -ComputerName $computers -Verbose -Wait

    Start-DscConfiguration -UseExisting -Wait -Verbose -Force -ComputerName $computers
}

function Show-LabLatestArtifacts {
    $latestBuild = Get-LabLatestArtifactsPath
    start $latestBuild
}

function Get-LabLatestArtifactsPath {
    $latestBuild = dir -Path 'C:\Artifacts\DscWorkshop CI' | Sort-Object -Property { [int]$_.Name } -Descending | Select-Object -First 1
    $latestBuild.FullName
}

function Initialize-DscLocalConfigurationManager {

    $lcmConfigPath = Join-Path -Path $env:temp -ChildPath 'LCMConfiguration'
    if (-not (Test-Path -Path $lcmConfigPath)) {
        New-Item -Path $lcmConfigPath -ItemType Directory -Force | Out-Null
    }

    $lcmConfig = @'
Configuration LocalConfigurationManagerConfiguration
{
    LocalConfigurationManager
    {

    ConfigurationMode = 'ApplyOnly'

    }
}
'@

    Invoke-Command -ScriptBlock ([scriptblock]::Create($lcmConfig)) -NoNewScope

    LocalConfigurationManagerConfiguration -OutputPath $lcmConfigPath | Out-Null

    Set-DscLocalConfigurationManager -Path $lcmConfigPath -Force
    Remove-Item -LiteralPath $lcmConfigPath -Recurse -Force -Confirm:$false
}


function Reset-DscLocalConfigurationManager {

    Write-Verbose -Message 'Resetting the DSC LCM'

    Stop-DscConfiguration -WarningAction SilentlyContinue -Force
    Remove-DscConfigurationDocument -Stage Current -Force
    Remove-DscConfigurationDocument -Stage Pending -Force
    Remove-DscConfigurationDocument -Stage Previous -Force
}

function Get-LabDscBuildWorkers {
    $computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty DnsHostName

    Invoke-Command -ScriptBlock {
        if (Get-Service -Name vstsagent*) {
            $env:COMPUTERNAME
        }
    } -ComputerName $computers
}

function Clear-LabDscNodes {
    $path = Join-Path (Get-LabLatestArtifactsPath) -ChildPath MOF
    $computerNames = dir -Path $path -Filter *.mof | Select-Object -ExpandProperty BaseName

    Invoke-Command -ScriptBlock {
        Remove-Item HKLM:\SOFTWARE\DscLcmController -Recurse -Force
        Remove-DscConfigurationDocument -Stage Current, Pending, Previous
        Remove-Item -Path C:\ProgramData\Dsc -Force -Recurse
        Remove-Item C:\Windows\System32\Configuration\MetaConfig.mof -Force
        Get-ScheduledTask -TaskPath \DscController\ | Where-Object TaskName -like *dsc* | Unregister-ScheduledTask -Confirm:$false
    } -ComputerName $computerNames

    Clear-LabBuildWorkers

}

function Clear-LabBuildWorkers {
    $buildWorkers = Get-LabDscBuildWorkers

    Invoke-Command -ScriptBlock {
        dir C:\BuildWorkerSetupFiles\_work | Where-Object { $_.Name.Length -lt 3 } | Remove-Item -Recurse -Force
    } -ComputerName $buildWorkers
}

function Test-LabDscConfiguration {
    $computers = Get-ADComputer -Filter { Name -like 'DSCWeb*' -or Name -like 'DSCFile*' } | Select-Object -ExpandProperty DNSHostName

    Test-DscConfiguration -ComputerName $computers -Detailed -Verbose
}

function Start-LabDscConfiguration {
    $computers = Get-ADComputer -Filter { Name -like 'DSCWeb*' -or Name -like 'DSCFile*' } | Select-Object -ExpandProperty DNSHostName

    Start-DscConfiguration -ComputerName $computers -UseExisting -Wait -Verbose -Force

}
