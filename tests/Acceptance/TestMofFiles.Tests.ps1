BeforeDiscovery {
    $here = $PSScriptRoot
    if ($global:Filter -and $global:Filter.ToString() -and -not $Filter.ToString())
    {
        $Filter = $global:Filter
    }

    $datumDefinitionFile = Join-Path -Path $ProjectPath -ChildPath source\Datum.yml
    $nodeDefinitions = Get-ChildItem $ProjectPath\source\AllNodes -Recurse -Include *.yml
    $environments = (Get-ChildItem $ProjectPath\source\AllNodes -Directory -ErrorAction SilentlyContinue).BaseName
    $roleDefinitions = Get-ChildItem $ProjectPath\source\Roles -Recurse -Include *.yml -ErrorAction SilentlyContinue
    $datum = New-DatumStructure -DefinitionFile $datumDefinitionFile
    $configurationData = Get-FilteredConfigurationData -Filter $Filter -CurrentJobNumber $currentJobNumber -TotalJobCount $totalJobCount

    $nodeNames = [System.Collections.ArrayList]::new()
    $mofFiles = Get-ChildItem -Path "$OutputDirectory\MOF" -Filter *.mof -Recurse -ErrorAction SilentlyContinue
    $mofChecksumFiles = Get-ChildItem -Path "$OutputDirectory\MOF" -Filter *.mof.checksum -Recurse -ErrorAction SilentlyContinue
    $metaMofFiles = Get-ChildItem -Path "$OutputDirectory\MetaMOF" -Filter *.mof -Recurse -ErrorAction SilentlyContinue
    $nodes = $configurationData.AllNodes
    $allMofTests = @(
        @{
            MofFiles         = $mofFiles
            MofChecksumFiles = $mofChecksumFiles
            MetaMofFiles     = $metaMofFiles
            Nodes            = $nodes
        }
    )

    $individualTests = $nodes | ForEach-Object {
        @{
            NodeName         = $_.Name
            MofChecksumFiles = $mofChecksumFiles
            MofFiles         = $mofFiles
            MetaMofFiles     = $metaMofFiles
        }
    }
}

Describe 'MOF Files' -Tag BuildAcceptance {

    It 'All nodes have a MOF file' -TestCases $allMofTests {
        Write-Verbose "MOF File Count $($mofFiles.Count)"
        Write-Verbose "Node Count $($nodes.Count)"

        $mofFiles.Count | Should -Be $nodes.Count
    }

    It 'All nodes have a MOF Checksum file' -TestCases $allMofTests {
        Write-Verbose "MOF Checksum File Count $($mofFiles.Count)"
        Write-Verbose "Node Count $($nodes.Count)"

        $MofChecksumFiles.Count | Should -Be $nodes.Count
    }

    It "Node '<NodeName>' should have a MOF file" -TestCases $individualTests {
        $MofFiles | Where-Object BaseName -EQ $NodeName | Should -BeOfType System.IO.FileSystemInfo
    }

    It "Node '<NodeName>' should have a MOF Checksum file" -TestCases $individualTests {
        $MofChecksumFiles | Where-Object BaseName -EQ "$NodeName.mof" | Should -BeOfType System.IO.FileSystemInfo
    }

    It 'All nodes have a Meta MOF file' -TestCases $allMofTests {
        Write-Verbose "Meta MOF File Count $($metaMofFiles.Count)"
        Write-Verbose "Node Count $($nodes.Count)"

        $metaMofFiles.Count | Should -BeIn $nodes.Count
    }

    It "Node '<NodeName>' should have a Meta MOF file" -TestCases $individualTests {
        $metaMofFiles | Where-Object BaseName -EQ "$($NodeName).meta" | Should -BeOfType System.IO.FileSystemInfo
    }

}
