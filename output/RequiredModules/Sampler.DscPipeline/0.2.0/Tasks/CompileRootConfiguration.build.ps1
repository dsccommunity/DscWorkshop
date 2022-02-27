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
    $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

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

    $MofOutputFolder = Get-SamplerAbsolutePath -Path $MofOutputFolder -RelativeTo $OutputDirectory

    if (-not (Test-Path -Path $MofOutputFolder))
    {
        $null = New-Item -ItemType Directory -Path $MofOutputFolder -Force
    }

    Start-Transcript -Path "$BuildOutput\Logs\CompileRootConfiguration.log"
    try
    {
        $originalPSModulePath = $env:PSModulePath
        $env:PSModulePath = ($env:PSModulePath -split [io.path]::PathSeparator).Where({
                $_ -notmatch ([regex]::Escape('powershell\7\Modules')) -and
                $_ -notmatch ([regex]::Escape('Program Files\WindowsPowerShell\Modules')) -and
                $_ -notmatch ([regex]::Escape('Documents\PowerShell\Modules'))
            }) -join [io.path]::PathSeparator

        Write-Build Green ''
        if (Test-Path -Path (Join-Path -Path $SourcePath -ChildPath RootConfiguration.ps1))
        {
            Write-Build Green "Found and using 'RootConfiguration.ps1' in '$SourcePath'"
            $rootConfigurationPath = Join-Path -Path $SourcePath -ChildPath RootConfiguration.ps1
        }
        else
        {
            Write-Build Green "Did not find 'RootConfiguration.ps1' in '$SourcePath', using 'CompileRootConfiguration.ps1' the one in 'Sampler.DscPipeline'"
            $rootConfigurationPath = Split-Path -Path $PSScriptRoot -Parent
            $rootConfigurationPath = Join-Path -Path $rootConfigurationPath -ChildPath Scripts
            $rootConfigurationPath = Join-Path -Path $rootConfigurationPath -ChildPath CompileRootConfiguration.ps1
        }

        $mofs = . $rootConfigurationPath
        if ($ConfigurationData.AllNodes.Count -ne $mofs.Count)
        {
            Write-Warning "Compiled MOF file count <> node count. Node count: $($ConfigurationData.AllNodes.Count), MOF file count: $($($mofs.Count))."
        }

        Write-Build Green "Successfully compiled $($mofs.Count) MOF files"
    }
    catch
    {
        Write-Build Red "ERROR OCCURED DURING COMPILATION: $($_.Exception.Message)"
        $relevantErrors = $Error | Where-Object -FilterScript {
            $_.Exception -isnot [System.Management.Automation.ItemNotFoundException]
        }

        $relevantErrors[0..2] | Out-String | ForEach-Object { Write-Warning $_ }
    }
    finally
    {
        $env:PSModulePath = $originalPSModulePath
        Stop-Transcript
    }

}
