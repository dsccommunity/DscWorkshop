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

Describe 'MOF Files' -Tag BuildAcceptance {
    BeforeAll {
        $mofFiles = Get-ChildItem -Path "$OutputDirectory\MOF" -Filter *.mof -ErrorAction SilentlyContinue
        $metaMofFiles = Get-ChildItem -Path "$OutputDirectory\MetaMOF" -Filter *.mof -ErrorAction SilentlyContinue
        $nodes = $configurationData.AllNodes
    }

    It 'All nodes have a MOF file' {
        Write-Verbose "MOF File Count $($mofFiles.Count)"
        Write-Verbose "Node Count $($nodes.Count)"

        $mofFiles.Count | Should -Be $nodes.Count
    }

    foreach ($node in $nodes)
    {
        It "Node '$($node.NodeName)' should have a MOF file" {
            $mofFiles | Where-Object BaseName -eq $node.NodeName | Should -BeOfType System.IO.FileSystemInfo 
        }
    }

    if ($metaMofFiles)
    {
        It 'All nodes have a Meta MOF file' {
            Write-Verbose "Meta MOF File Count $($metaMofFiles.Count)"
            Write-Verbose "Node Count $($nodes.Count)"
    
            $metaMofFiles.Count | Should -BeIn $nodes.Count
        }

        foreach ($node in $nodes)
        {
            It "Node '$($node.NodeName)' should have a Meta MOF file" {       
                $metaMofFiles | Where-Object BaseName -eq "$($node.NodeName).meta" | Should -BeOfType System.IO.FileSystemInfo 
            }
        }
    }
}
