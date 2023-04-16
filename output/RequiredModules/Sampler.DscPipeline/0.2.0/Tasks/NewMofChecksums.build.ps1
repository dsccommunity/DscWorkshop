param
(
    # Project path
    [Parameter()]
    [System.String]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [Parameter()]
    # Base directory of all output (default to 'output')
    [System.String]
    $OutputDirectory = (property OutputDirectory (Join-Path -Path $BuildRoot -ChildPath output)),

    [Parameter()]
    [string]
    $MofOutputFolder = (property MofOutputFolder 'MOF'),

    # Build Configuration object
    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ })
)

task NewMofChecksums {
    . Set-SamplerTaskVariable -AsNewBuild

    $MofOutputFolder = Get-SamplerAbsolutePath -Path $MofOutputFolder -RelativeTo $OutputDirectory

    $mofs = Get-ChildItem -Path $MofOutputFolder -Recurse -ErrorAction SilentlyContinue
    foreach ($mof in $mofs)
    {
        if (($mof.BaseName -in $global:configurationData.AllNodes.Name) -or 
            ($mof.BaseName -in $global:configurationData.AllNodes.NodeName))
        {
            New-DscChecksum -Path $mof.FullName -Verbose:$false -Force
        }
    }
}
