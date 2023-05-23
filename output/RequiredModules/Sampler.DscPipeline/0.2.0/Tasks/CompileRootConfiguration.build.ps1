param
(
    # Project path
    [Parameter()]
    [System.String]
    $ProjectPath = (property ProjectPath $BuildRoot),

    # Source path
    [Parameter()]
    [System.String]
    $SourcePath = (property SourcePath 'source'),

    [Parameter()]
    # Base directory of all output (default to 'output')
    [System.String]
    $OutputDirectory = (property OutputDirectory (Join-Path -Path $BuildRoot -ChildPath output)),

    [Parameter()]
    [string]
    $RequiredModulesDirectory = (property RequiredModulesDirectory 'RequiredModules'),

    [Parameter()]
    [string]
    $DatumConfigDataDirectory = (property DatumConfigDataDirectory 'source'),

    [Parameter()]
    [string]
    $MofOutputFolder = (property MofOutputFolder 'MOF'),

    [Parameter()]
    [int]
    $CurrentJobNumber = (property CurrentJobNumber 1),

    [Parameter()]
    [int]
    $TotalJobCount = (property TotalJobCount 1),

    # Build Configuration object
    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ })
)

task CompileRootConfiguration {
    . Set-SamplerTaskVariable -AsNewBuild

    $RequiredModulesDirectory = Get-SamplerAbsolutePath -Path $RequiredModulesDirectory -RelativeTo $OutputDirectory

    Write-Build DarkGray 'Reading DSC Resource metadata for supporting CIM based DSC parameters...'
    Initialize-DscResourceMetaInfo -ModulePath $RequiredModulesDirectory
    Write-Build DarkGray 'Done'

    $MofOutputFolder = Get-SamplerAbsolutePath -Path $MofOutputFolder -RelativeTo $OutputDirectory

    if (-not (Test-Path -Path $MofOutputFolder))
    {
        $null = New-Item -ItemType Directory -Path $MofOutputFolder -Force
    }

    Start-Transcript -Path "$BuildOutput\Logs\CompileRootConfiguration.log"
    try
    {
        Write-Build Green ''
        if ((Test-Path -Path (Join-Path -Path $SourcePath -ChildPath RootConfiguration.ps1)) -and
        (Test-Path -Path (Join-Path -Path $SourcePath -ChildPath CompileRootConfiguration.ps1)))
        {
            Write-Build Green "Found 'RootConfiguration.ps1' and 'CompileRootConfiguration.ps1' in '$SourcePath' and using these files"
            $rootConfigurationPath = Join-Path -Path $SourcePath -ChildPath CompileRootConfiguration.ps1
        }
        else
        {
            Write-Build Green "Did not find 'RootConfiguration.ps1' and 'CompileRootConfiguration.ps1' in '$SourcePath', using the ones in 'Sampler.DscPipeline'"
            $rootConfigurationPath = Split-Path -Path $PSScriptRoot -Parent
            $rootConfigurationPath = Join-Path -Path $rootConfigurationPath -ChildPath Scripts
            $rootConfigurationPath = Join-Path -Path $rootConfigurationPath -ChildPath CompileRootConfiguration.ps1
        }

        $mofs = . $rootConfigurationPath
        if ($ConfigurationData.AllNodes.Count -ne $mofs.Count)
        {
            Write-Warning -Message "Compiled MOF file count <> node count. Node count: $($ConfigurationData.AllNodes.Count), MOF file count: $($($mofs.Count))."
        }

        Write-Build Green "Successfully compiled $($mofs.Count) MOF files"
    }
    catch
    {
        Write-Build Red 'Error(s) occured during the compilation. Details will be shown below'

        $relevantErrors = $Error | Where-Object -FilterScript {
            $_.Exception -isnot [System.Management.Automation.ItemNotFoundException]
        }

        foreach ($relevantError in ($relevantErrors | Select-Object -First 3))
        {
            Write-Error -ErrorRecord $relevantError
        }
    }
    finally
    {
        Stop-Transcript
    }

}
