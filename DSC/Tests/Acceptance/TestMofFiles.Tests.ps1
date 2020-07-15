$here = $PSScriptRoot
if ($global:Filter -and $global:Filter.ToString() -and -not $Filter.ToString())
{
    $Filter = $global:Filter
}

$datumDefinitionFile = Join-Path $here ..\..\DscConfigData\Datum.yml
$nodeDefinitions = Get-ChildItem $here\..\..\DscConfigData\AllNodes -Recurse -Include *.yml
$environments = (Get-ChildItem $here\..\..\DscConfigData\AllNodes -Directory).BaseName
$roleDefinitions = Get-ChildItem $here\..\..\DscConfigData\Roles -Recurse -Include *.yml
$datum = New-DatumStructure -DefinitionFile $datumDefinitionFile
$configurationData = Get-FilteredConfigurationData -Filter $Filter -Environment $environment -Datum $datum -CurrentJobNumber $currentJobNumber -TotalJobCount $totalJobCount

$nodeNames = [System.Collections.ArrayList]::new()

Describe 'Pull Server Deployment' -Tag BuildAcceptance, PullServer {

    $environmentNodes = $configurationData.AllNodes | Where-Object Environment -eq $env:RELEASE_ENVIRONMENTNAME

    foreach ($node in $environmentNodes) {
        It "MOF file for node $($node.NodeName) was deployed to $($env:DscConfiguration)" {
        
            Get-ChildItem -Path $env:DscConfiguration -Filter "$($node.NodeName).mof" | Select-String -Pattern ">>$($env:BHBuildNumber)<<" | Should -Not -BeNullOrEmpty

        }
    }

}

Describe 'MOF Files' -Tag BuildAcceptance {
    BeforeAll {
        $mofFiles = Get-ChildItem -Path "$buildOutput\MOF" -Filter *.mof -ErrorAction SilentlyContinue
        $metaMofFiles = Get-ChildItem -Path "$buildOutput\MetaMOF" -Filter *.mof -ErrorAction SilentlyContinue
        $nodes = $configurationData.AllNodes
    }

    It 'All nodes have a MOF file' {
        Write-Verbose "MOF File Count $($mofFiles.Count)"
        Write-Verbose "Node Count $($nodes.Count)"

        $mofFiles.Count | Should -Be $nodes.Count
    }

    foreach ($node in $nodes) {
        It "Node '$($node.NodeName)' should have a MOF file" {
            $mofFiles | Where-Object BaseName -eq $node.NodeName | Should -BeOfType System.IO.FileSystemInfo 
        }
    }

    if ($metaMofFiles) {
        It 'All nodes have a Meta MOF file' {
            Write-Verbose "Meta MOF File Count $($metaMofFiles.Count)"
            Write-Verbose "Node Count $($nodes.Count)"
    
            $metaMofFiles.Count | Should -BeIn $nodes.Count
        }

        foreach ($node in $nodes) {
            It "Node '$($node.NodeName)' should have a Meta MOF file" {       
                $metaMofFiles | Where-Object BaseName -eq "$($node.NodeName).meta" | Should -BeOfType System.IO.FileSystemInfo 
            }
        }
    }
}
