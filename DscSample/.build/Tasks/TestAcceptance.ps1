task TestBuildAcceptance {
    
    if (-not (Test-Path -Path $testsPath)) {
        Write-Build Yellow "Path for tests '$testsPath' does not exist"
        return
    }

    if (-not ([System.IO.Path]::IsPathRooted($BuildOutput))) {
        $BuildOutput = Join-Path -Path $PSScriptRoot -ChildPath $BuildOutput
    }

    if ($env:BHBuildSystem -in 'AppVeyor', 'Unknown') {
        #AppVoyor build are  not deploying to a pull server yet.
        $excludeTag = 'PullServer'
    }
    
    $testResultsPath = Join-Path -Path $BuildOutput -ChildPath BuildAcceptanceTestResults.xml
    Write-Host "testResultsPath is: $testResultsPath"
    Write-Host "testsPath is: $testsPath"
    Write-Host "BuildOutput is: $BuildOutput"

    $pesterParams = @{
        Script       = $testsPath
        OutputFile   = $testResultsPath
        OutputFormat = 'NUnitXml'
        Tag          = 'BuildAcceptance'
        PassThru     = $true
        Show         = 'Failed', 'Summary'
    }
    if ($excludeTag) {
        $pesterParams.ExcludeTag = $excludeTag
    }
    $testResults = Invoke-Pester @pesterParams

    assert (-not $testResults.FailedCount)

}
