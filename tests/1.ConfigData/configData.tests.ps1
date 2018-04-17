$here = $PSScriptRoot

$DatumDefinitionFile = Join-Path $here ..\..\DSC_ConfigData\Datum.yml
$NodeDefinitions = Get-ChildItem $here\..\..\DSC_ConfigData\AllNodes -Recurse -Include *.yml
$Environments = (Get-ChildItem $here\..\..\DSC_ConfigData\AllNodes -Directory).BaseName
$RoleDefinitions = Get-ChildItem $here\..\..\DSC_ConfigData\Roles -Recurse -Include *.yml
$Datum = New-DatumStructure -DefinitionFile $DatumDefinitionFile
$ConfigurationData = Get-FilteredConfigurationData -Environment $Environment -Datum $Datum

$NodeNames = [System.Collections.ArrayList]::new()

Describe 'Datum Tree Definition' {
    It 'Exists in DSC_ConfigData Folder' {
        Test-Path $DatumDefinitionFile | Should -Be $true
    }

    $DatumYamlContent = Get-Content $DatumDefinitionFile -Raw
    It 'is Valid Yaml' {
        {$DatumYamlContent | ConvertFrom-Yaml } | Should -Not -Throw
    }

}

Describe 'Node Definition Files' {
    $NodeDefinitions.ForEach{
        # A Node cannot be empty
        $Content = Get-Content -raw $_
        
        if($_.BaseName -ne 'AllNodes') {
            It "$($_.BaseName) Should not be duplicated" {
                $NodeNames -contains $_.BaseName | Should -Be $false
            }
        }
        
        $Null = $NodeNames.Add($_.BaseName)
        
        It "$($_.BaseName) is not Empty" {
            $Content | Should -Not -BeNullOrEmpty
        }

        It "$($_.Name) has valid yaml" {
                { $Object = $Content | ConvertFrom-Yaml } | Should -Not -Throw
        }
    }
}


Describe 'Roles Definition Files' {
    $RoleDefinitions.Foreach{
        # A role can be Empty

        $Content = Get-Content -raw $_
        if($Content) {
            It "$($_.BaseName) has valid yaml" {
                { $null = $Content | ConvertFrom-Yaml } | Should -Not -Throw
            }
        }
    }
}

Describe 'Role Composition' {
    Foreach($Environment in $Environments) {
        Context "Nodes for environment $Environment" {
            
            Foreach ($Node in $ConfigurationData.AllNodes) {
                It "$($Node.Name) has a valid Configurations Setting (!`$null)" {
                    {Lookup Configurations -Node $Node -DatumTree $Datum } | Should -Not -Throw
                }
            }
        }
    }
} 