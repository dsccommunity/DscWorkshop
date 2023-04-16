param
(
    # Project path
    [Parameter()]
    [System.String]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [Parameter()]
    # Base directory of all output (default to 'output')
    [System.String]
    $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

    [Parameter()]
    [string]
    $DatumConfigDataDirectory = (property DatumConfigDataDirectory 'source'),

    [Parameter()]
    [int]
    $CurrentJobNumber = (property CurrentJobNumber 1),

    [Parameter()]
    [int]
    $TotalJobCount = (property TotalJobCount 1),

    # Build Configuration object
    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ }),

    [Parameter()]
    [string]
    $RsopFolder = (property RsopFolder 'RSOP'),

    [Parameter()]
    [string]
    $RsopWithSourceFolder = (property RsopFolderWithSource 'RsopWithSource'),

    [Parameter()]
    [string]
    $ModuleVersion = (property ModuleVersion ''),

    [Parameter()]
    [switch]
    $UseEnvironment = (property UseEnvironment $false)
)

task CompileDatumRsop {

    Clear-DatumRsopCache #otherwise this task will not generate new RSOP data

    # Get the vales for task variables, see https://github.com/gaelcolas/Sampler#task-variables.
    . Set-SamplerTaskVariable -AsNewBuild

    $DatumConfigDataDirectory = Get-SamplerAbsolutePath -Path $DatumConfigDataDirectory -RelativeTo $ProjectPath
    $RsopFolder = Get-SamplerAbsolutePath -Path $RsopFolder -RelativeTo $OutputDirectory
    $RsopWithSourceFolder = Get-SamplerAbsolutePath -Path $RsopWithSourceFolder -RelativeTo $OutputDirectory

    if (-not (Test-Path -Path $RsopFolder))
    {
        $null = New-Item -ItemType Directory -Path $RsopFolder -Force
    }
    if (-not (Test-Path -Path $RsopWithSourceFolder))
    {
        $null = New-Item -ItemType Directory -Path $RsopWithSourceFolder -Force
    }

    $rsopOutputPathVersion = Join-Path -Path $RsopFolder -ChildPath $ModuleVersion
    if (-not (Test-Path -Path $rsopOutputPathVersion))
    {
        $null = New-Item -ItemType Directory -Path $rsopOutputPathVersion -Force
    }
    $rsopWithSourceOutputPathVersion = Join-Path -Path $RsopWithSourceFolder -ChildPath $ModuleVersion
    if (-not (Test-Path -Path $rsopWithSourceOutputPathVersion))
    {
        $null = New-Item -ItemType Directory -Path $rsopWithSourceOutputPathVersion -Force
    }

    if ($configurationData.AllNodes)
    {
        Write-Build Green "Generating RSOP output for $($configurationData.AllNodes.Count) nodes."
        $configurationData.AllNodes.Where({ $_['Name'] -ne '*' }) | ForEach-Object -Process {
            Write-Build Green "`tBuilding RSOP for $($_['Name'])..."
            $outPath = $rsopOutputPathVersion

            $nodeRsop = Get-DatumRsop -Datum $datum -AllNodes ([ordered]@{ } + $_) -RemoveSource
            $nodeRsopWithSource = Get-DatumRsop -Datum $datum -AllNodes ([ordered]@{ } + $_) -IncludeSource

            if ($UseEnvironment.IsPresent)
            {
                $finalRsopOutputPathVersion = Join-Path -Path $rsopOutputPathVersion -ChildPath $nodeRsop.Environment
                $finalRsopWithSourceOutputPathVersion = Join-Path -Path $rsopWithSourceOutputPathVersion -ChildPath $nodeRsop.Environment
                $null = New-Item -ItemType Directory -Path $finalRsopOutputPathVersion, $finalRsopWithSourceOutputPathVersion -Force
            }
            else
            {
                $finalRsopOutputPathVersion = $rsopOutputPathVersion
                $finalRsopWithSourceOutputPathVersion = $rsopWithSourceOutputPathVersion
            }

            $nodeRsop | ConvertTo-Json -Depth 40 | ConvertFrom-Json | ConvertTo-Yaml -OutFile (Join-Path -Path $finalRsopOutputPathVersion -ChildPath "$($nodeRsop.NodeName).yml") -Force
            $nodeRsopWithSource | ConvertTo-Json -Depth 40 | ConvertFrom-Json | ConvertTo-Yaml -OutFile (Join-Path -Path $finalRsopWithSourceOutputPathVersion -ChildPath "$($nodeRsop.NodeName).yml") -Force
        }
    }
    else
    {
        Write-Build Green 'No data for generating RSOP output.'
    }
}
