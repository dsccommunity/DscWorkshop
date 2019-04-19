task TestAcceptance {
    
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
    
    $testResultsPath = Join-Path -Path $BuildOutput -ChildPath AcceptanceTestResults.xml

    $pesterParams = @{
        Script       = $testsPath
        OutputFile   = $testResultsPath
        OutputFormat = 'NUnitXml'
        Tag          = 'Acceptance'
        PassThru     = $true
    }
    if ($excludeTag) {
        $pesterParams.ExcludeTag = $excludeTag
    }
    $testResults = Invoke-Pester @pesterParams

    assert (-not $testResults.FailedCount)

}
