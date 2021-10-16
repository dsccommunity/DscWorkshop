[CmdletBinding()]
param (
    [string]
    $BuildOutput = 'BuildOutput',

    [string]
    $ResourcesFolder = 'DscResources',

    [string]
    $ConfigDataFolder = 'DscConfigData',

    [string]
    $ConfigurationsFolder = 'DscConfigurations',

    [Parameter(Position = 0)]
    $Tasks,

    [string]
    $ProjectPath,

    [ScriptBlock]
    $TaskHeader = {
        Param($Path)
        ''
        '=' * 79
        Write-Build Cyan "`t`t`t$($Task.Name.Replace('_',' ').ToUpper())"
        Write-Build DarkGray "$(Get-BuildSynopsis $Task)"
        '-' * 79
        Write-Build DarkGray "  $Path"
        Write-Build DarkGray "  $($Task.InvocationInfo.ScriptName):$($Task.InvocationInfo.ScriptLineNumber)"
        ''
    }
)

#cannot be a default parameter value due to https://github.com/PowerShell/PowerShell/issues/4688
if (-not $ProjectPath) {
    $ProjectPath = $PSScriptRoot
}

if (-not ([System.IO.Path]::IsPathRooted($BuildOutput))) {
    $BuildOutput = Join-Path -Path $ProjectPath -ChildPath $BuildOutput
}

$configurationPath = Join-Path -Path $ProjectPath -ChildPath $ConfigurationsFolder
$resourcePath = Join-Path -Path $ProjectPath -ChildPath $ResourcesFolder
$configDataPath = Join-Path -Path $ProjectPath -ChildPath $ConfigDataFolder
$testsPath = Join-Path -Path $ProjectPath -ChildPath $TestFolder

#importing all resources from 'Build' directory
Get-ChildItem -Path "$PSScriptRoot/Build/" -Recurse -Include *.ps1 |
    ForEach-Object {
    Write-Verbose "Importing file $($_.BaseName)"
    try {
        . $_.FullName
    }
    catch { }
}

task . NewMofChecksums,
CompressModulesWithChecksum,
Deploy,
TestBuildAcceptance
