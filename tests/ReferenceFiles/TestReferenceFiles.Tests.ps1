BeforeDiscovery {
    if ($global:Filter -and $global:Filter.ToString() -and -not $Filter.ToString())
    {
        $Filter = $global:Filter
    }

    $sourcePath = Join-Path -Path $ProjectPath -ChildPath $SourcePath
    $sourcePath = Join-Path -Path $sourcePath -ChildPath 'TestRsopReferences'

    $ReferenceRsopFiles = Get-ChildItem -Path $sourcePath -Filter *.yml -ErrorAction SilentlyContinue

    if (-not $ReferenceRsopFiles)
    {
        return
    }

    $RsopFiles = Get-ChildItem -Path "$OutputDirectory\RSOP" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -in $ReferenceRsopFiles.Name }

    $allRsopTests = @(
        @{
            ReferenceFiles = $ReferenceRsopFiles
            RsopFiles      = $RsopFiles
        }
    )
    $individualTests = foreach ($rrf in $ReferenceRsopFiles)
    {
        @{
            Name        = $rrf.Name
            File        = $rrf
            PartnerFile = $RsopFiles | Where-Object { $_.Name -eq $rrf.Name }
        }
    }
}

Describe 'Reference Files' -Tag ReferenceFiles {

    It 'All reference files have RSOP files in output folder' -Skip:([bool]$Filter) -TestCases $allRsopTests {

        Write-Verbose "Reference File Count $($ReferenceFiles.Count)"
        Write-Verbose "RSOP File Count $($RsopFiles.Count)"

        $ReferenceFiles.Count | Should -Be $RsopFiles.Count
    }

    It "Reference file '<Name>' should have same checksum as output\RSOP file" -Skip:([bool]$Filter) -TestCases $individualTests {
        $true | Should -Be true
        $FilehashRef = (Get-FileHash $File.Fullname).Hash
        $FileHashRSOP = (Get-FileHash $PartnerFile.Fullname).Hash
        $FilehashRef | Should -Be $FileHashRSOP
    }
}
