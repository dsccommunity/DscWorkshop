$here = $PSScriptRoot

$datumDefinitionFile = Join-Path $here ..\..\DscConfigData\Datum.yml
$nodeDefinitions = Get-ChildItem $here\..\..\DscConfigData\AllNodes -Recurse -Include *.yml
$environments = (Get-ChildItem $here\..\..\DscConfigData\AllNodes -Directory).BaseName
$roleDefinitions = Get-ChildItem $here\..\..\DscConfigData\Roles -Recurse -Include *.yml
$datum = New-DatumStructure -DefinitionFile $datumDefinitionFile
$configurationData = Get-FilteredConfigurationData -Datum $datum -Filter $filter

$nodeNames = [System.Collections.ArrayList]::new()

Describe 'Datum Tree Definition' -Tag Integration {
    It 'Exists in DscConfigData Folder' {
        Test-Path $datumDefinitionFile | Should -Be $true
    }

    $datumYamlContent = Get-Content $datumDefinitionFile -Raw
    It 'is Valid Yaml' {
        { $datumYamlContent | ConvertFrom-Yaml } | Should -Not -Throw
    }

}

Describe 'Node Definition Files' -Tag Integration {
    $environments = dir .\DscConfigData\Environment\ | Select-Object -ExpandProperty BaseName
    $locations = dir .\DscConfigData\Locations\ | Select-Object -ExpandProperty BaseName

    $nodeDefinitions.ForEach{
        # A Node cannot be empty
        $content = Get-Content -Path $_ -Raw
        $node = $content | ConvertFrom-Yaml
        $nodeName = $node.NodeName
        
        if ($_.BaseName -ne 'AllNodes') {
            It "'$($_.FullName)' should not be duplicated" {
                $nodeNames -contains $_.BaseName | Should -Be $false
            }
        }

        $nodeNames.Add($_.BaseName) | Out-Null

        It "'$nodeName' has valid yaml" {
            { $content | ConvertFrom-Yaml } | Should -Not -Throw
        }

        It "'$nodeName' is in the right environment" {
            $pathElements = $_.FullName.Split('\')
            $pathElements -contains $node.Environment | Should Be $true
        }

        It "Location of '$nodeName' is '$($node.Location)' and does exist" {
            $node = $content | ConvertFrom-Yaml
            $node.Location -in $locations | Should Be $true
        }

        It "Environment of '$nodeName' is '$($node.Environment)' and does exist" {
            $node = $content | ConvertFrom-Yaml
            $node.Environment -in $environments | Should Be $true
        }
    }
}

Describe 'Roles Definition Files' -Tag Integration {
    $nodes = if ($Environment) {
        $configurationData.AllNodes | Where-Object { $_.NodeName -ne '*' -and $_.Environment -eq $Environment }
    }
    else {
        $configurationData.AllNodes | Where-Object { $_.NodeName -ne '*' }
    }

    $nodeRoles = $nodes | ForEach-Object -MemberName Role
    $usedRolesDefinitions = foreach ($nodeRole in $nodeRoles) {
        $roleDefinitions.Where( { $_.FullName -like "*$($nodeRole)*" })
    }

    $usedRolesDefinitions = $usedRolesDefinitions | Group-Object -Property FullName | ForEach-Object { $_.Group[0] }
    
    $usedRolesDefinitions.Foreach{
        # A role can be Empty

        $content = Get-Content -Path $_ -Raw
        if ($content) {
            It "$($_.FullName) has valid yaml" {
                { $null = $content | ConvertFrom-Yaml } | Should -Not -Throw
            }
        }
    }
}

Describe 'Role Composition' -Tag Integration {
    foreach ($environment in $environments) {
        Context "Nodes for environment $environment" {
            
            $nodes = if ($Environment) {
                $configurationData.AllNodes | Where-Object { $_.NodeName -ne '*' -and $_.Environment -eq $Environment }
            }
            else {
                $configurationData.AllNodes | Where-Object { $_.NodeName -ne '*' }
            }

            foreach ($node in $nodes) {
                It "$($node.Name) has a valid Configurations Setting (!`$null)" {
                    { Lookup Configurations -Node $node -DatumTree $datum } | Should -Not -Throw
                }
            }
        }
    }
}
