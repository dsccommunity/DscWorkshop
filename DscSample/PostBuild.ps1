[CmdletBinding()]
param (
    [string]
    $BuildOutput = 'BuildOutput',

    [string]
    $ResourcesFolder = 'DSC_Resources',

    [string]
    $ConfigDataFolder = 'DSC_ConfigData',

    [string]
    $ConfigurationsFolder = 'DSC_Configurations',

    [string]
    $Environment,

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

Get-ChildItem -Path "$PSScriptRoot/.build/" -Recurse -Include *.ps1 |
    ForEach-Object {
    Write-Verbose "Importing file $($_.BaseName)"
    try {
        . $_.FullName
    }
    catch { }
}

task . NewMofChecksums,
CompressModulesWithChecksum,
Deploy