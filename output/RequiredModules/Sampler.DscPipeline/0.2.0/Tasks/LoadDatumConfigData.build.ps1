param
(
    # Project path
    [Parameter()]
    [System.String]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [Parameter()]
    [string]
    $DatumConfigDataDirectory = (property DatumConfigDataDirectory 'source'),

    [Parameter()]
    [scriptblock]
    $Filter = (property Filter {}),

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

task LoadDatumConfigData {

    $DatumConfigDataDirectory = Get-SamplerAbsolutePath -Path $DatumConfigDataDirectory -RelativeTo $ProjectPath
    if ($null -eq $Filter)
    {
        $Filter = {}
    }

    Import-Module -Name PowerShell-Yaml -Scope Global
    Import-Module -Name Datum -Scope Global

    # Fix Import issue of Datum.InvokeCommand from vscode integrated terminal
    if (-not (Get-Command -Name Import-PowerShellDataFile -ErrorAction SilentlyContinue))
    {
        Import-Module -Name Microsoft.PowerShell.Utility -RequiredVersion 3.1.0.0
    }

    $global:node = $null #very imporant, otherwise the 2nd build in the same session won't work
    $node = $null

    $datumDefinitionFile = Join-Path -Resolve -Path $DatumConfigDataDirectory -ChildPath 'Datum.yml'
    Write-Build Green "Loading Datum Definition from '$datumDefinitionFile'"
    $global:datum = New-DatumStructure -DefinitionFile $datumDefinitionFile

    if (-not ($datum.AllNodes))
    {
        Write-Error 'No nodes found in the solution'
    }

    $getFilteredConfigurationDataParams = @{
        CurrentJobNumber = $CurrentJobNumber
        TotalJobCount    = $TotalJobCount
        Filter           = $Filter
    }

    if ($message = (&git log -1) -and $message -match "--Added new node '(?<NodeName>(\w|\.|-)+)'")
    {
        $global:Filter = $Filter = [scriptblock]::Create('$_.NodeName -eq "{0}"' -f $Matches.NodeName)
        $global:SkipCompressedModulesBuild = $true

        $getFilteredConfigurationDataParams['Filter'] = $Filter
    }

    try
    {
        $global:configurationData = Get-FilteredConfigurationData @getFilteredConfigurationDataParams
    }
    catch
    {
        Write-Warning "'Get-FilteredConfigurationData' could not load any configuration data. Retrying..."
        Start-Sleep -Seconds 1
    }

    # When using PowerShell 7+, the first call to 'Get-FilteredConfigurationData' fails usually.
    $global:configurationData = Get-FilteredConfigurationData @getFilteredConfigurationDataParams

}
