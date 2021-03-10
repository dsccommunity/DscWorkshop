task TestConfigData {

    if (-not (Test-Path -Path $testsPath)) {
        Write-Build Yellow "Path for tests '$testsPath' does not exist"
        return
    }
    
    if (-not ([System.IO.Path]::IsPathRooted($BuildOutput))) {
        $BuildOutput = Join-Path -Path $PSScriptRoot -ChildPath $BuildOutput
    }

    $testResultsPath = Join-Path -Path $BuildOutput -ChildPath IntegrationTestResults.xml
    Write-Host "testResultsPath is: $testResultsPath"
    Write-Host "testsPath is: $testsPath"
    Write-Host "BuildOutput is: $BuildOutput"
    
    $testResults = Invoke-Pester -Script "$testsPath\ConfigData" -PassThru -OutputFile $testResultsPath -OutputFormat NUnitXml -Tag Integration -Show Failed, Summary

    assert ($testResults.FailedCount -eq 0)

}
