BeforeDiscovery {
    $here = $PSScriptRoot

    $configurationData = try
    {
        if ($filter)
        {
            Get-FilteredConfigurationData -Filter $filter
        }
        else
        {
            Get-FilteredConfigurationData
        }
    }
    catch
    {
        Write-Error "'Get-FilteredConfigurationData' did not return any data. Please check if all YAML files are valid and don't have syntax errors. $($_.Exception.Message)"
    }

    $definitionTests = @{
        datumDefinitionFile = Join-Path -Path $ProjectPath -ChildPath source\Datum.yml
        datumYamlContent    = Get-Content -Raw -Path (Join-Path -Path $ProjectPath -ChildPath source\Datum.yml) -ErrorAction SilentlyContinue
        configurationData   = $configurationData
    }
    $nodeDefinitions = Get-ChildItem $ProjectPath\source\AllNodes -Recurse -Include *.yml |
        Where-Object {
            $_.BaseName -in $configurationData.AllNodes.Name
        }
    $environments = (Get-ChildItem $ProjectPath\source\AllNodes -Directory -ErrorAction SilentlyContinue).BaseName
    $roleDefinitions = Get-ChildItem $ProjectPath\source\Roles -Recurse -Include *.yml -ErrorAction SilentlyContinue
    $datum = New-DatumStructure -DefinitionFile $definitionTests.datumDefinitionFile -ErrorAction SilentlyContinue
    [hashtable[]]$allDefinitions = Get-ChildItem $ProjectPath\source -Recurse -Include *.yml | ForEach-Object {
        @{
            FullName = $_.FullName
            Name     = $_.Name
        }
    }

    $nodeGroups = $configurationData.AllNodes | Group-Object { $_.Environment }
    [hashtable[]]$allNodeTestsDuplicate = $nodeGroups | ForEach-Object {
        @{
            ReferenceNodes  = $_.Group.NodeName | Where-Object { $_ -notlike '`[x=*' }
            DifferenceNodes = $_.Group.NodeName | Where-Object { $_ -notlike '`[x=*' } | Sort-Object -Unique
        }
    }

    $environments = Get-ChildItem $ProjectPath\source\Environments -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
    $locations = Get-ChildItem $ProjectPath\source\Locations -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
    $roles = Get-ChildItem $ProjectPath\source\Roles -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
    $baselines = Get-ChildItem $ProjectPath\source\Baselines -ErrorAction SilentlyContinue | Select-Object -ExpandProperty BaseName
    [hashtable[]]$allNodeTests = $nodeDefinitions | ForEach-Object {
        $content = Get-Content -Path $_ -Raw
        $n = $content | ConvertFrom-Yaml
        @{
            Content      = $content
            Node         = $n
            NodeName     = $n.NodeName
            Name         = $_.BaseName
            Location     = $n.Location
            Role         = $n.Role
            FullName     = $_.FullName
            Locations    = $locations
            Roles        = $roles
            Baselines    = $baselines
            Baseline     = $n.Baseline
            Environments = $environments
            Environment  = $n.Environment
        }
    }

    $nodes = if ($Environment)
    {
        $configurationData.AllNodes | Where-Object { $_.NodeName -ne '*' -and $_.Environment -eq $Environment }
    }
    else
    {
        $configurationData.AllNodes | Where-Object { $_.NodeName -ne '*' }
    }

    $nodeRoles = $nodes | ForEach-Object -MemberName Role
    $nodeRoleTests = foreach ($nodeRole in $nodeRoles)
    {
        $roleDefinitions | Where-Object FullName -Like "*$($nodeRole)*" | ForEach-Object {
            @{
                FullName = $_.FullName
            }
        }
    }

    $nodeTestsAllNodes = @(@{ConfigurationData = $configurationData })
    $nodeTestsSingleNode = $nodes | ForEach-Object {
        @{
            NodeName          = $_.Name
            Name              = $_.Name
            Node              = $_
            Datum             = $datum
            ConfigurationData = $configurationData
        }
    }
}

Describe 'Validate All Definition Files' -Tag Integration {

    It "'<Name>' is a valid yaml" -TestCases $allDefinitions {
        { Get-Content -Path $FullName -Raw | ConvertFrom-Yaml } | Should -Not -Throw
    }
}

Describe 'Datum Tree Definition' -Tag Integration {
    It 'Exists in source Folder' -TestCases $definitionTests {
        Test-Path $datumDefinitionFile | Should -Be $true
    }

    It 'Is Valid Yaml' -TestCases $definitionTests {
        { $datumYamlContent | ConvertFrom-Yaml } | Should -Not -Throw
    }

    It "'Get-FilteredConfigurationData' returned data" -TestCases $definitionTests {
        $configurationData | Should -Not -BeNullOrEmpty
    }

}

Describe 'Node Definition Files' -Tag Integration {

    Context 'Testing for conflicts / duplicate data' {
        It 'Should not have duplicate node names' -TestCases $allNodeTestsDuplicate {
            if ($ReferenceNodes -and $DifferenceNodes)
            {
                (Compare-Object -ReferenceObject $ReferenceNodes -DifferenceObject $DifferenceNodes).InputObject | Should -BeNullOrEmpty
            }
        }
    }

    It "'<Name>' has valid yaml" -TestCases $allNodeTests {
        { $content | ConvertFrom-Yaml } | Should -Not -Throw
    }

    It "'<Name>' is in the right environment" -TestCases $allNodeTests {
        if ($node.Environment -and $node.Environment -notlike '`[x=*')
        {
            $pathElements = $FullName.Split('\')
            $pathElements -contains $node.Environment | Should -BeTrue
        }
    }

    It "Location of '<Name>' is '<Location>' and does exist" -TestCases $allNodeTests {
        if ($node.Location)
        {
            $node.Location -in $Locations | Should -BeTrue
        }
    }

    if ($node.Environment -and $node.Environment -notlike '`[x=*')
    {
        It "Environment of '<Name>' is '<Environment>' and does exist" -TestCases $allNodeTests {
            $node.Environment -in $Environments | Should -BeTrue
        }
    }

    if ($node.Role)
    {
        It "Role of '<Name>' is '<Role>' and does exist" -TestCases $allNodeTests {
            $node.Role -in $Roles | Should -BeTrue
        }
    }

    if ($node.Baseline)
    {
        It "Baseline of '<Name>' is '<Baseline>' and does exist" -TestCases $allNodeTests {
            $node.Baseline -in $Baselines | Should -BeTrue
        }
    }


    Describe 'Roles Definition Files' -Tag Integration {
        It '<FullName> has valid yaml' -TestCases $nodeRoleTests {
            { $null = Get-Content -Raw -Path $FullName | ConvertFrom-Yaml } | Should -Not -Throw
        }
    }

    Describe 'Role Composition' -Tag Integration {

        It "<Name> has a valid Configurations Setting (!`$null)" -TestCases $nodeTestsSingleNode {
            { Resolve-Datum -PropertyPath Configurations -Node $node -DatumTree $datum } | Should -Not -Throw
        }

        It 'No duplicate IP addresses should be used' -TestCases $nodeTestsAllNodes {
            $allIps = $configurationData.AllNodes.NetworkIpConfiguration.Interfaces.IpAddress
            $selectedIps = $allIps | Select-Object -Unique

            if ($allIps -and $selectedIps)
            {
                Compare-Object -ReferenceObject $allIps -DifferenceObject $selectedIps | Should -BeNull
            }
        }
    }
}
