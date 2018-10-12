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
    $Environment = (property Environment ''),

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
    $tid = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    Start-Transcript -Path "$BuildOutput\Logs\PSModulePath_BuildModules$tid-Log.txt"
    
    Write-Host "RandomWait: $($RandomWait.ToString())"
    
    if ($RandomWait)
    {
        $m = [System.Threading.Mutex]::OpenExisting('DscBuildProcess')
        Write-Host "Mutex handle $($m.Handle.ToInt32())"
        $r = $m.WaitOne(300000) #timeout is 5 minutes
        if (-not $r)
        {
            Write-Error "Error getting the mutex 'DscBuildProcess' in 5 minutes"
        }
        Start-Sleep -Seconds 5
        Write-Host "Releasing mutex at $(Get-Date)"
        $m.ReleaseMutex()
    }
    else
    {
        Write-Host "Not waiting, starting compilation job"
    }

    if (!([System.IO.Path]::IsPathRooted($BuildOutput)))
    {
        $BuildOutput = Join-Path -Path $ProjectPath -ChildPath $BuildOutput
    }

    $configurationPath = Join-Path -Path $ProjectPath -ChildPath $ConfigurationsFolder
    $resourcePath = Join-Path -Path $ProjectPath -ChildPath $ResourcesFolder
    $buildModulesPath = Join-Path -Path $BuildOutput -ChildPath Modules
        
    Set-PSModulePath -ModuleToLeaveLoaded $ModuleToLeaveLoaded -PathsToSet @($configurationPath, $resourcePath, $buildModulesPath)
    Stop-Transcript
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
    if ($Environment) {
        if (-not ($datum.AllNodes.$Environment)) {
            Write-Error "No nodes found in the environment '$Environment'"
        }
    } else {
        if (-not ($datum.AllNodes)) {
            Write-Error 'No nodes found in the solution'
        }
    }
    
    $global:configurationData = Get-FilteredConfigurationData -Environment $Environment -Filter $Filter -Datum $datum
}

task Compile_Root_Configuration {
    $tid = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    Start-Transcript -Path "$BuildOutput\Logs\Compile_Root_Configuration$tid-Log.txt"

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

    Stop-Transcript
}

task Compile_Root_Meta_Mof {
    . (Join-Path -Path $ProjectPath -ChildPath 'RootMetaMof.ps1')
    $metaMofs = RootMetaMOF -ConfigurationData $configurationData -OutputPath (Join-Path -Path $BuildOutput -ChildPath 'MetaMof')
    Write-Build Green "Successfully compiled $($metaMofs.Count) MOF files"
}

task New_Mof_Checksums {
    $mofs = Get-ChildItem -Path (Join-Path -Path $BuildOutput -ChildPath MOF)
    foreach ($mof in $mofs)
    {
        if ($mof.BaseName -in $global:configurationData.AllNodes.NodeName)
        {
            New-DscChecksum -Path $mof.FullName -Verbose:$false -Force
        }
    }
}

task Compress_Modules_with_Checksum {
    if (-not (Test-Path -Path $BuildOutput\CompressedModules))
    {
        mkdir -Path $BuildOutput\CompressedModules | Out-Null
    }
    $modules = Get-ModuleFromFolder -ModuleFolder "$ProjectPath\DSC_Resources\"
    $modules | Publish-ModuleToPullServer -OutputFolderPath $BuildOutput\CompressedModules
}

task Compile_Datum_Rsop {
    if(![System.IO.Path]::IsPathRooted($rsopFolder)) {
        $rsopOutputPath = Join-Path -Path $BuildOutput -ChildPath $rsopFolder
    }
    else {
        $RsopOutputPath = $rsopFolder
    }

    if (-not (Test-Path -Path $rsopOutputPath)) {
        mkdir -Path $rsopOutputPath -Force | Out-Null
    }

    $rsopOutputPathVersion = Join-Path -Path $RsopOutputPath -ChildPath $BuildVersion
    if (-not (Test-Path -Path $rsopOutputPathVersion)) {
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
