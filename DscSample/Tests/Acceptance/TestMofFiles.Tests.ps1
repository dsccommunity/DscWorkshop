$here = $PSScriptRoot

$datumDefinitionFile = Join-Path $here ..\..\DSC_ConfigData\Datum.yml
$nodeDefinitions = Get-ChildItem $here\..\..\DSC_ConfigData\AllNodes -Recurse -Include *.yml
$environments = (Get-ChildItem $here\..\..\DSC_ConfigData\AllNodes -Directory).BaseName
$roleDefinitions = Get-ChildItem $here\..\..\DSC_ConfigData\Roles -Recurse -Include *.yml
$datum = New-DatumStructure -DefinitionFile $datumDefinitionFile
$configurationData = Get-FilteredConfigurationData -Environment $environment -Datum $datum -Filter $filter
$buildStartTime = [datetime]$env:BHBuildStartTime

$nodeNames = [System.Collections.ArrayList]::new()

Describe 'Pull Server Deployment' -Tag Acceptance, PullServer {

    $environmentNodes = $configurationData.AllNodes | Where-Object Environment -eq $env:RELEASE_ENVIRONMENTNAME

    foreach ($node in $environmentNodes) {
        It "MOF file for node $($node.NodeName) was deployed to $($env:DscConfiguration)" {
        
            Get-ChildItem -Path $env:DscConfiguration -Filter "$($node.NodeName).mof" | Where-Object LastWriteTime -gt $buildStartTime | Should -Not -BeNullOrEmpty

        }
    }

}
