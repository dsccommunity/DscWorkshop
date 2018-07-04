param (
    [System.IO.DirectoryInfo]
    $ProjectPath = (property ProjectPath $ProjectPath),
    
    [String]
    $BuildOutput = (property BuildOutput 'BuildOutput'),
    
    [String]
    $ResourcesFolder = (property ResourcesFolder 'DSC_Resources'),
    
    [String]
    $ConfigurationsFolder = (property ConfigurationsFolder 'DSC_Configurations'),

    [ScriptBlock]
    $Filter = (property Filter {}),

    [switch]
    $RandomWait = (property RandomWait $false),

    [String]
    $Environment = (property Environment 'DEV'),

    [String]
    $ConfigDataFolder = (property ConfigDataFolder 'DSC_ConfigData'),

    [String]
    $BuildVersion = (property BuildVersion '0.0.0'),

    [String]
    $RsopFolder = (property RsopFolder 'RSOP'),

    [String[]]
    $ModuleToLeaveLoaded = (property ModuleToLeaveLoaded @('InvokeBuild', 'PSReadline', 'PackageManagement', 'ISESteroids') )
)

task PSModulePath_BuildModules {
    Write-Build Green "RandomWait: $($RandomWait.ToString())"
    if ($RandomWait)
    {
        $rnd = Get-Random -Minimum 0 -Maximum 10
        Write-Build Green "Waiting $rnd seconds to start the compilation job"
        Start-Sleep -Seconds $rnd
    }
    else
    {
        Write-Build Green "Not waiting, starting compilation job"
    }

    if (!([System.IO.Path]::IsPathRooted($BuildOutput)))
    {
        $BuildOutput = Join-Path -Path $ProjectPath -ChildPath $BuildOutput
    }

    $configurationPath = Join-Path -Path $ProjectPath -ChildPath $ConfigurationsFolder
    $resourcePath = Join-Path -Path $ProjectPath -ChildPath $ResourcesFolder
    $buildModulesPath = Join-Path -Path $BuildOutput -ChildPath Modules
        
    Set-PSModulePath -ModuleToLeaveLoaded $ModuleToLeaveLoaded -PathsToSet @($configurationPath, $resourcePath, $buildModulesPath)
}

task Load_Datum_ConfigData {
    if (![System.IO.Path]::IsPathRooted($BuildOutput))
    {
        $BuildOutput = Join-Path -Path $ProjectPath -ChildPath $BuildOutput
    }
    $configDataPath = Join-Path -Path $ProjectPath -ChildPath $ConfigDataFolder
    $configurationPath = Join-Path -Path $ProjectPath -ChildPath $ConfigurationsFolder
    $resourcePath = Join-Path -Path $ProjectPath -ChildPath $ResourcesFolder
    $buildModulesPath = Join-Path -Path $BuildOutput -ChildPath Modules
        
    Set-PSModulePath -ModuleToLeaveLoaded $ModuleToLeaveLoaded -PathsToSet @($configurationPath, $resourcePath, $buildModulesPath)

    Import-Module -Name ProtectedData -Scope Global
    Import-Module -Name PowerShell-Yaml -Scope Global
    Import-Module -Name Datum -Scope Global

    $datumDefinitionFile = Join-Path -Resolve -Path $configDataPath -ChildPath 'Datum.yml'
    Write-Build Green "Loading Datum Definition from '$datumDefinitionFile'"
    $global:datum = New-DatumStructure -DefinitionFile $datumDefinitionFile
    if (-not ($datum.AllNodes.$Environment))
    {
        Write-Error "No nodes found in the environment '$Environment'"
    }
    Write-Build Green "Node count: $(($datum.AllNodes.$Environment | Get-Member -MemberType ScriptProperty | Measure-Object).Count)"
    
    Write-Build Green "Filter: $($Filter.ToString())"
    $global:configurationData = Get-FilteredConfigurationData -Environment $Environment -Filter $Filter -Datum $datum
    Write-Build Green "Node count after applying filter: $($configurationData.AllNodes.Count)"
}

task Compile_Root_Configuration {
    try 
    {
        $mofs = . (Join-Path -Path $ProjectPath -ChildPath 'RootConfiguration.ps1')
        Write-Build Green "Successfully compiled $($mofs.Count) MOF files"
    }
    catch 
    {
        Write-Build Red "ERROR OCCURED DURING COMPILATION: $($_.Exception.Message)"
        $relevantErrors = $Error | Where-Object {
            $_.Exception -isnot [System.Management.Automation.ItemNotFoundException]
        }
        Write-Build Red ($relevantErrors[0..2] | Out-String)
    }
}

task Compile_Root_Meta_Mof {
    . (Join-Path -Path $ProjectPath -ChildPath 'RootMetaMof.ps1')
    $metaMofs = RootMetaMOF -ConfigurationData $configurationData -OutputPath (Join-Path -Path $BuildOutput -ChildPath 'MetaMof')
    Write-Build Green "Successfully compiled $($metaMofs.Count) MOF files"
}

task Create_Mof_Checksums {
    Import-Module -Name DscBuildHelpers -Scope Global
    New-DscChecksum -Path (Join-Path -Path $BuildOutput -ChildPath MOF) -Verbose:$false
}

task Compile_Datum_Rsop {
    if(![System.IO.Path]::IsPathRooted($rsopFolder)) {
        $rsopOutputPath = Join-Path -Path $BuildOutput -ChildPath $rsopFolder
    }
    else {
        $RsopOutputPath = $rsopFolder
    }

    if(!(Test-Path -Path $rsopOutputPath)) {
        mkdir -Path $rsopOutputPath -Force | Out-Null
    }

    $rsopOutputPathVersion = Join-Path -Path $RsopOutputPath -ChildPath $BuildVersion
    if(!(Test-Path -Path $rsopOutputPathVersion)) {
        mkdir -Path $rsopOutputPathVersion -Force | Out-Null
    }

    Write-Build Green "Generating RSOP output for $($configurationData.AllNodes.Count) nodes"
    $configurationData.AllNodes |
    Where-Object Name -ne * |
    ForEach-Object {
        $nodeRSOP = Get-DatumRsop -Datum $datum -AllNodes ([ordered]@{} + $_)
        $nodeRSOP | Convertto-Yaml -OutFile (Join-Path -Path $rsopOutputPathVersion -ChildPath "$($_.Name).yml") -Force
    }
}