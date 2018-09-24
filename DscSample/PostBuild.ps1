[CmdletBinding()]
param (
    [String]
    $BuildOutput = 'BuildOutput',

    [String]
    $ResourcesFolder = 'DSC_Resources',

    [String]
    $ConfigDataFolder = 'DSC_ConfigData',

    [String]
    $ConfigurationsFolder = 'DSC_Configurations',

    $Environment = $(
        $branch = $env:BranchName
        $branch = if ($branch -eq 'master') {
            'Prod'
        }
        else {
            'Dev'
        }
        if (Test-Path -Path ".\$ConfigDataFolder\AllNodes\$branch") {
            $branch
        }
        else {
            'Dev'
        }
    ),
    
    $BuildVersion = $(
        if ($gitshortid = (& git rev-parse --short HEAD)) {
            $gitshortid
        }
        else {
            '0.0.0'
        }
    ),

    [Parameter(Position = 0)]
    $Tasks,

    [String]
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
#rmo -Name InvokeBuild
Get-ChildItem -Path "$PSScriptRoot/.build/" -Recurse -Include *.ps1 |
    ForEach-Object {
    Write-Verbose "Importing file $($_.BaseName)"
    try {
        . $_.FullName
    }
    catch { }
}

task . New_Mof_Checksums