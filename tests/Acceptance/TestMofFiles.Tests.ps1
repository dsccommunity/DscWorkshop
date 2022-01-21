BeforeDiscovery {
    $here = $PSScriptRoot
    if ($global:Filter -and $global:Filter.ToString() -and -not $Filter.ToString())
    {
        $Filter = $global:Filter
    }

    $datumDefinitionFile = Join-Path $here ..\..\source\Datum.yml
    $nodeDefinitions = Get-ChildItem $here\..\..\source\AllNodes -Recurse -Include *.yml
    $environments = (Get-ChildItem $here\..\..\source\AllNodes -Directory).BaseName
    $roleDefinitions = Get-ChildItem $here\..\..\source\Roles -Recurse -Include *.yml
    $datum = New-DatumStructure -DefinitionFile $datumDefinitionFile
    $configurationData = Get-FilteredConfigurationData -Filter $Filter -CurrentJobNumber $currentJobNumber -TotalJobCount $totalJobCount

    $nodeNames = [System.Collections.ArrayList]::new()
    $mofFiles = Get-ChildItem -Path "$OutputDirectory\MOF" -Filter *.mof -Recurse -ErrorAction SilentlyContinue
    $metaMofFiles = Get-ChildItem -Path "$OutputDirectory\MetaMOF" -Filter *.mof -Recurse -ErrorAction SilentlyContinue
    $nodes = $configurationData.AllNodes
    $allMofTests = @(
        @{
            MofFiles     = $mofFiles
            MetaMofFiles = $metaMofFiles
            Nodes        = $nodes
        }
    )

    $individualTests = $nodes | Foreach-Object { @{NodeName = $_.Name; MofFiles = $mofFiles; MetaMofFiles = $metaMofFiles } }
}

Describe 'MOF Files' -Tag BuildAcceptance {
    It 'All nodes have a MOF file' -TestCases $allMofTests {
        Write-Verbose "MOF File Count $($mofFiles.Count)"
        Write-Verbose "Node Count $($nodes.Count)"

        $mofFiles.Count | Should -Be $nodes.Count
    }

    It "Node '<NodeName>' should have a MOF file" -TestCases $individualTests {
        $MofFiles | Where-Object BaseName -eq $NodeName | Should -BeOfType System.IO.FileSystemInfo
    }

    It 'All nodes have a Meta MOF file' -TestCases $allMofTests {
        Write-Verbose "Meta MOF File Count $($metaMofFiles.Count)"
        Write-Verbose "Node Count $($nodes.Count)"

        $metaMofFiles.Count | Should -BeIn $nodes.Count
    }
    It "Node '<NodeName>' should have a Meta MOF file" -TestCases $individualTests {
        $metaMofFiles | Where-Object BaseName -eq "$($NodeName).meta" | Should -BeOfType System.IO.FileSystemInfo
    }
}
