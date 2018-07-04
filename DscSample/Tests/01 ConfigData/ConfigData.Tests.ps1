$here = $PSScriptRoot

$datumDefinitionFile = Join-Path $here ..\..\DSC_ConfigData\Datum.yml
$nodeDefinitions = Get-ChildItem $here\..\..\DSC_ConfigData\AllNodes -Recurse -Include *.yml
$environments = (Get-ChildItem $here\..\..\DSC_ConfigData\AllNodes -Directory).BaseName
$roleDefinitions = Get-ChildItem $here\..\..\DSC_ConfigData\Roles -Recurse -Include *.yml
$datum = New-DatumStructure -DefinitionFile $datumDefinitionFile
$configurationData = Get-FilteredConfigurationData -Environment $environment -Datum $datum

$nodeNames = [System.Collections.ArrayList]::new()

Describe 'Datum Tree Definition' {
    It 'Exists in DSC_ConfigData Folder' {
        Test-Path $datumDefinitionFile | Should -Be $true
    }

    $datumYamlContent = Get-Content $datumDefinitionFile -Raw
    It 'is Valid Yaml' {
        { $datumYamlContent | ConvertFrom-Yaml } | Should -Not -Throw
    }

}

Describe 'Node Definition Files' {
    $nodeDefinitions.ForEach{
        # A Node cannot be empty
        $content = Get-Content -Path $_ -Raw
        
        if($_.BaseName -ne 'AllNodes') {
            It "$($_.BaseName) Should not be duplicated" {
                $nodeNames -contains $_.BaseName | Should -Be $false
            }
        }
        
        $null = $nodeNames.Add($_.BaseName)
        
        It "$($_.BaseName) is not Empty" {
            $content | Should -Not -BeNullOrEmpty
        }

        It "$($_.Name) has valid yaml" {
            { $object = $content | ConvertFrom-Yaml } | Should -Not -Throw
        }
    }
}


Describe 'Roles Definition Files' {
    $roleDefinitions.Foreach{
        # A role can be Empty

        $content = Get-Content -Path $_ -Raw
        if($content) {
            It "$($_.BaseName) has valid yaml" {
                { $null = $content | ConvertFrom-Yaml } | Should -Not -Throw
            }
        }
    }
}

Describe 'Role Composition' {
    Foreach($environment in $environments) {
        Context "Nodes for environment $environment" {
            
            Foreach ($node in ($configurationData.AllNodes | Where-Object NodeName -ne *)) {
                It "$($node.Name) has a valid Configurations Setting (!`$null)" {
                    {Lookup Configurations -Node $node -DatumTree $datum } | Should -Not -Throw
                }
            }
        }
    }
}