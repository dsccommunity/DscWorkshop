task TestConfigData {
    if (-not (Test-Path -Path $testsPath)) {
        Write-Build Yellow "Path for tests '$testsPath' does not exist"
        return
    }
    if (-not ([System.IO.Path]::IsPathRooted($BuildOutput))) {
        $BuildOutput = Join-Path -Path $PSScriptRoot -ChildPath $BuildOutput
    }
    $testResultsPath = Join-Path -Path $BuildOutput -ChildPath TestResults.xml
    $testResults = Invoke-Pester -Script $testsPath -PassThru -OutputFile $testResultsPath -OutputFormat NUnitXml

    assert ($testResults.FailedCount -eq 0)
}