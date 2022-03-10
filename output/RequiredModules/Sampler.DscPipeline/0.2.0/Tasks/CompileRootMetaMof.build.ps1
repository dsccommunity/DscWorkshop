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
    $DatumConfigDataDirectory = (property DatumConfigDataDirectory 'source'),

    [Parameter()]
    [string]
    $MetaMofOutputFolder = (property MetaMofOutputFolder 'MetaMOF'),

    # Build Configuration object
    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ })
)

task CompileRootMetaMof {
    . Set-SamplerTaskVariable -AsNewBuild

    $MetaMofOutputFolder = Get-SamplerAbsolutePath -Path $MetaMofOutputFolder -RelativeTo $OutputDirectory

    $rsopCache = Get-DatumRsopCache

    $cd = @{}
    foreach ($node in $rsopCache.GetEnumerator())
    {
        $cd.AllNodes += @([hashtable]$node.Value)
    }

    $originalPSModulePath = $env:PSModulePath
    try
    {
        $env:PSModulePath = ($env:PSModulePath -split [System.IO.Path]::PathSeparator).Where({
                $_ -notmatch ([regex]::Escape('powershell\7\Modules')) -and
                $_ -notmatch ([regex]::Escape('Program Files\WindowsPowerShell\Modules')) -and
                $_ -notmatch ([regex]::Escape('Documents\PowerShell\Modules'))
            }) -join [System.IO.Path]::PathSeparator

        if (-not (Test-Path -Path $MetaMofOutputFolder))
        {
            $null = New-Item -ItemType Directory -Path $MetaMofOutputFolder
        }

        if ($cd.AllNodes)
        {
            Write-Build Green ''
            if (Test-Path -Path (Join-Path -Path $SourcePath -ChildPath RootMetaMof.ps1))
            {
                Write-Build Green "Found and using 'RootMetaMof.ps1' in '$SourcePath'"
                $rootMetaMofPath = Join-Path -Path $SourcePath -ChildPath RootMetaMof.ps1
            }
            else
            {
                Write-Build Green "Did not find 'RootMetaMof.ps1' in '$SourcePath', using 'RootMetaMof.ps1' the one in module 'Sampler.DscPipeline'"
                $rootMetaMofPath = Split-Path -Path $PSScriptRoot -Parent
                $rootMetaMofPath = Join-Path -Path $rootMetaMofPath -ChildPath Scripts
                $rootMetaMofPath = Join-Path -Path $rootMetaMofPath -ChildPath RootMetaMof.ps1
            }
            . $rootMetaMofPath

            $metaMofs = RootMetaMOF -ConfigurationData $cd -OutputPath $MetaMofOutputFolder
            Write-Build Green "Successfully compiled $($metaMofs.Count) Meta MOF files."
            if ($cd.AllNodes.Count -ne $metaMofs.Count)
            {
                Write-Warning -Message 'Compiled Meta MOF file count <> node count'
            }

            Write-Build Green "Successfully compiled $($metaMofs.Count) Meta MOF files."
        }
        else
        {
            Write-Build Green 'No data to compile Meta MOF files'
        }
    }
    finally
    {
        $env:PSModulePath = $originalPSModulePath
    }
}
