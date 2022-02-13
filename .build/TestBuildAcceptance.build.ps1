param
(
    # Project path
    [Parameter()]
    [System.String]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [Parameter()]
    # Base directory of all output (default to 'output')
    [System.String]
    $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

    [Parameter()]
    [string]
    $DatumConfigDataDirectory = (property DatumConfigDataDirectory 'source'),

    [Parameter()]
    [System.Object[]]
    $PesterScript = (property PesterScript 'tests'),

    [Parameter()]
    [System.Object[]]
    $AcceptanceTestDirectory = (property AcceptanceTestDirectory 'Acceptance'),

    [Parameter()]
    [string]
    $BuildAcceptanceTestResults = (property BuildAcceptanceTestResults 'BuildAcceptanceTestResults.xml'),

    [Parameter()]
    [string[]]
    $excludeTag = (property excludeTag @()),

    [Parameter()]
    [int]
    $CurrentJobNumber = (property CurrentJobNumber 1),

    [Parameter()]
    [int]
    $TotalJobCount = (property TotalJobCount 1),

    # Build Configuration object
    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ })
)

task TestBuildAcceptance {
    $OutputDirectory = Get-SamplerAbsolutePath -Path $OutputDirectory -RelativeTo $ProjectPath
    $DatumConfigDataDirectory = Get-SamplerAbsolutePath -Path $DatumConfigDataDirectory -RelativeTo $ProjectPath
    $PesterScript = $PesterScript.Foreach({
            Get-SamplerAbsolutePath -Path $_ -RelativeTo $ProjectPath
        })

    $AcceptanceTestDirectory = $AcceptanceTestDirectory.Foreach({
            Get-SamplerAbsolutePath -Path $_ -RelativeTo $PesterScript[0]
        })

    if (-not (Test-Path -Path $AcceptanceTestDirectory))
    {
        Write-Build Yellow "Path for tests '$AcceptanceTestDirectory' does not exist"
        return
    }

    if (-not ([System.IO.Path]::IsPathRooted($BuildOutput)))
    {
        $BuildOutput = Join-Path -Path $PSScriptRoot -ChildPath $BuildOutput
    }

    if ($env:BHBuildSystem -in 'AppVeyor', 'Unknown')
    {
        #AppVoyor build are  not deploying to a pull server yet.
        $excludeTag = 'PullServer'
    }

    $testResultsPath = Get-SamplerAbsolutePath -Path $testResultsPath -RelativeTo $OutputDirectory

    Write-Build DarkGray "testResultsPath is: $testResultsPath"
    Write-Build DarkGray "AcceptanceTestDirectory is: $AcceptanceTestDirectory"
    Write-Build DarkGray "BuildOutput is: $BuildOutput"

    Import-Module -Name Pester
    $po = [PesterConfiguration]::new()
    $po.Run.PassThru = $true
    $po.Run.Path = [string[]]$AcceptanceTestDirectory
    $po.Output.Verbosity = 'Detailed'
    if ($excludeTag)
    {
        $po.Filter.ExcludeTag = $excludeTag
    }
    $po.Filter.Tag = 'BuildAcceptance'
    $po.TestResult.OutputFormat = 'NUnitXml'
    $po.TestResult.OutputPath = $testResultsPath
    $testResults = Invoke-Pester -Configuration $po

    assert ($testResults.FailedCount -eq 0 -and $testResults.FailedBlocksCount -eq 0 -and $testResults.FailedContainersCount -eq 0)
}
