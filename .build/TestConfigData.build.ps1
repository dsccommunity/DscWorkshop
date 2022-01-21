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
    $ConfigDataPesterScript = (property ConfigDataPesterScript 'ConfigData'),

    [Parameter()]
    [string]
    $testResultsPath = (property TestResultsPath 'IntegrationTestResults.xml'),

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

task TestConfigData {
    $OutputDirectory = Get-SamplerAbsolutePath -Path $OutputDirectory -RelativeTo $ProjectPath
    $DatumConfigDataDirectory = Get-SamplerAbsolutePath -Path $DatumConfigDataDirectory -RelativeTo $ProjectPath
    $PesterScript = $PesterScript.Foreach( {
            Get-SamplerAbsolutePath -Path $_ -RelativeTo $ProjectPath
        })

    $ConfigDataPesterScript = $ConfigDataPesterScript.Foreach( {
            Get-SamplerAbsolutePath -Path $_ -RelativeTo $PesterScript[0]
        })

    Write-Build Green "Config Data Pester Scripts = [$($ConfigDataPesterScript -join ';')]"

    if (-not (Test-Path -Path $ConfigDataPesterScript))
    {
        Write-Build Yellow "Path for tests '$ConfigDataPesterScript' does not exist"
        return
    }

    $testResultsPath = Get-SamplerAbsolutePath -Path $testResultsPath -RelativeTo $OutputDirectory
    
    Write-Build DarkGray "testResultsPath is: $testResultsPath"
    Write-Build DarkGray "OutputDirectory is: $OutputDirectory"
    
    Import-Module -Name Pester
    $po = [PesterConfiguration]::new()
    $po.Run.PassThru = $true
    $po.Run.Path = [string[]]$ConfigDataPesterScript
    $po.Output.Verbosity = 'Detailed'
    $po.Filter.Tag = 'Integration'
    $po.TestResult.OutputFormat = 'NUnitXml'
    $po.TestResult.OutputPath = $testResultsPath
    $testResults = Invoke-Pester -Configuration $po

    assert ($testResults.FailedCount -eq 0)
}
