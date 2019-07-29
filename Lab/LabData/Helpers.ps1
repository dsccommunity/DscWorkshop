function Update-Nodes {
    $computers = Get-ADComputer -Filter { Name -like 'DSCWeb*' -or Name -like 'DSCFile*' } | Select-Object -ExpandProperty DNSHostName

    Update-DscConfiguration -ComputerName $computers -Verbose -Wait
    
    Start-DscConfiguration -UseExisting -Wait -Verbose -Force -ComputerName $computers
}

function Show-LatestArtifacts {
    $latestBuild = dir -Path C:\Artifacts\DscWorkshopBuild | Sort-Object -Property { [int]$_.Name } -Descending | Select-Object -First 1

    start "$($latestBuild.FullName)\DscWorkshop"
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
