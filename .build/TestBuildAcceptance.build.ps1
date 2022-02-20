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
    $AcceptancePesterScript = (property AcceptancePesterScript 'Acceptance'),

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
    $PesterOutputFolder = Get-SamplerAbsolutePath -Path $PesterOutputFolder -RelativeTo $OutputDirectory
    "`tPester Output Folder    = '$PesterOutputFolder"
    if (-not (Test-Path -Path $PesterOutputFolder))
    {
        Write-Build -Color 'Yellow' -Text "Creating folder $PesterOutputFolder"

        $null = New-Item -Path $PesterOutputFolder -ItemType 'Directory' -Force -ErrorAction 'Stop'
    }

    $DatumConfigDataDirectory = Get-SamplerAbsolutePath -Path $DatumConfigDataDirectory -RelativeTo $ProjectPath
    $PesterScript = $PesterScript.Foreach({
            Get-SamplerAbsolutePath -Path $_ -RelativeTo $ProjectPath
        })

    $AcceptancePesterScript = $AcceptancePesterScript.Foreach({
            Get-SamplerAbsolutePath -Path $_ -RelativeTo $PesterScript[0]
        })

    Write-Build Green "Acceptance Data Pester Scripts = [$($AcceptancePesterScript -join ';')]"

    if (-not (Test-Path -Path $AcceptancePesterScript))
    {
        Write-Build Yellow "Path for tests '$AcceptancePesterScript' does not exist"
        return
    }

    $testResultsPath = Get-SamplerAbsolutePath -Path AcceptanceTestResults.xml -RelativeTo $PesterOutputFolder

    Write-Build DarkGray "TestResultsPath is: $testResultsPath"
    Write-Build DarkGray "BuildOutput is: $OutputDirectory"

    Import-Module -Name Pester
    $po = $po = New-PesterConfiguration
    $po.Run.PassThru = $true
    $po.Run.Path = [string[]]$AcceptancePesterScript
    $po.Output.Verbosity = 'Detailed'
    if ($excludeTag)
    {
        $po.Filter.ExcludeTag = $excludeTag
    }
    $po.Filter.Tag = 'BuildAcceptance'
    $po.TestResult.Enabled = $true
    $po.TestResult.OutputFormat = 'NUnitXml'
    $po.TestResult.OutputPath = $testResultsPath
    $testResults = Invoke-Pester -Configuration $po

    assert ($testResults.FailedCount -eq 0 -and $testResults.FailedBlocksCount -eq 0 -and $testResults.FailedContainersCount -eq 0)
}
