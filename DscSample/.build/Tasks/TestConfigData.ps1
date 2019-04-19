task TestConfigData {
    if (-not (Test-Path -Path $testsPath)) {
        Write-Build Yellow "Path for tests '$testsPath' does not exist"
        return
    }
    
    $buildOutput = $env:BHBuildOutput

    $testResultsPath = Join-Path -Path $buildOutput -ChildPath IntegrationTestResults.xml
    $testsPath = Join-Path -Path $testsPath -ChildPath ConfigData
    $testResults = Invoke-Pester -Script $testsPath -PassThru -OutputFile $testResultsPath -OutputFormat NUnitXml -Tag Integration

    assert ($testResults.FailedCount -eq 0)
}
