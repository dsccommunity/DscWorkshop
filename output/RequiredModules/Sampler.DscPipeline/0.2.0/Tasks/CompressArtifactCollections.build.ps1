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
    $MofOutputFolder = (property MofOutputFolder 'MOF'),

    [Parameter()]
    [string]
    $RsopFolder = (property RsopFolder 'RSOP'),

    [Parameter()]
    [string]
    $MetaMofOutputFolder = (property MetaMofOutputFolder 'MetaMOF'),

    [Parameter()]
    [string]
    $CompressedModulesFolder = (property CompressedModulesFolder 'CompressedModules'),

    [Parameter()]
    [string]
    $CompressedArtifactsFolder = (property CompressedArtifactsFolder 'CompressedArtifacts'),

    [Parameter()]
    [string]
    $ModuleVersion = (property ModuleVersion ''),

    # Build Configuration object
    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ })
)

Task Compress_Artifact_Collections {
    . Set-SamplerTaskVariable -AsNewBuild

    $RsopFolder = Get-SamplerAbsolutePath -Path $RsopFolder -RelativeTo $OutputDirectory
    $MofOutputFolder = Get-SamplerAbsolutePath -Path $MofOutputFolder -RelativeTo $OutputDirectory
    $MetaMofOutputFolder = Get-SamplerAbsolutePath -Path $MetaMofOutputFolder -RelativeTo $OutputDirectory
    $CompressedArtifactsFolder = Get-SamplerAbsolutePath -Path $CompressedArtifactsFolder -RelativeTo $OutputDirectory
    $CompressedModulesFolder = Get-SamplerAbsolutePath -Path $CompressedModulesFolder -RelativeTo $OutputDirectory

        "`tRsopFolder                 = $RsopFolder"
        "`tMofOutputFolder            = $MofOutputFolder"
        "`tMetaMofOutputFolder        = $MetaMofOutputFolder"
        "`tCompressedArtifactsFolder  = $CompressedArtifactsFolder"
        "`tCompressedModulesFolder    = $CompressedModulesFolder"

    if (-not (Test-Path -Path $CompressedArtifactsFolder))
    {
        $null = New-Item -ItemType Directory $CompressedArtifactsFolder
    }

    Write-Build White "Starting deployment with files from '$OutputDirectory'"

    $MOFZip = Join-Path -Path $CompressedArtifactsFolder -ChildPath 'MOF.zip'
    $MetaMOFZip = Join-Path -Path $CompressedArtifactsFolder -ChildPath 'MetaMOF.zip'
    $RSOPZip = Join-Path -Path $CompressedArtifactsFolder -ChildPath 'RSOP.zip'
    $CompressedModulesZip = Join-Path -Path $CompressedArtifactsFolder -ChildPath 'CompressedModules.zip'

    Compress-Archive -Path $MofOutputFolder -DestinationPath $MOFZip -Force
    Compress-Archive -Path $MetaMofOutputFolder -DestinationPath $MetaMOFZip -Force
    Compress-Archive -Path $RsopFolder -DestinationPath $RSOPZip -Force
    Compress-Archive -Path $CompressedModulesFolder -DestinationPath $CompressedModulesZip -Force
}
