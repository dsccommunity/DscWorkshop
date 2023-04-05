param
(
    [Parameter()]
    # Base directory of all output (default to 'output')
    [System.String]
    $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

    [Parameter()]
    [System.Object[]]
    $PesterScript = (property PesterScript 'tests'),

    [Parameter()]
    [System.Object[]]
    $ReferencePesterScript = (property ReferencePesterScript 'ReferenceFiles'),

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

task TestReferenceRsop -if ((Get-FilteredConfigurationData -Datum $datum -Filter { $_.Name -like 'ReferenceConfiguration*' } -ErrorAction SilentlyContinue).AllNodes) {

    $PesterOutputFolder = Get-SamplerAbsolutePath -Path $PesterOutputFolder -RelativeTo $OutputDirectory
    "`tPester Output Folder    = '$PesterOutputFolder"
    if (-not (Test-Path -Path $PesterOutputFolder))
    {
        Write-Build -Color 'Yellow' -Text "Creating folder $PesterOutputFolder"

        $null = New-Item -Path $PesterOutputFolder -ItemType 'Directory' -Force -ErrorAction 'Stop'
    }

    $ReferencePesterScript = $ReferencePesterScript.Foreach({
            Get-SamplerAbsolutePath -Path $_ -RelativeTo $PesterScript[0]
        })

    Write-Build Green "ReferenceRsop Data Pester Scripts = [$($ReferencePesterScript -join ';')]"

    if (-not (Test-Path -Path $ReferencePesterScript))
    {
        Write-Build Yellow "Path for tests '$ReferencePesterScript' does not exist"
        return
    }

    $testResultsPath = Get-SamplerAbsolutePath -Path ReferenceTestResults.xml -RelativeTo $PesterOutputFolder

    Write-Build DarkGray "TestResultsPath is: $testResultsPath"
    Write-Build DarkGray "BuildOutput is: $OutputDirectory"

    Import-Module -Name Pester
    $po = New-PesterConfiguration
    $po.Run.PassThru = $true
    $po.Run.Path = [string[]]$ReferencePesterScript
    $po.Output.Verbosity = 'Detailed'
    if ($excludeTag)
    {
        $po.Filter.ExcludeTag = $excludeTag
    }
    $po.Filter.Tag = 'ReferenceFiles'
    $po.TestResult.Enabled = $true
    $po.TestResult.OutputFormat = 'NUnitXml'
    $po.TestResult.OutputPath = $testResultsPath
    $testResults = Invoke-Pester -Configuration $po

    assert ($testResults.FailedCount -eq 0 -and $testResults.FailedBlocksCount -eq 0 -and $testResults.FailedContainersCount -eq 0)

}
