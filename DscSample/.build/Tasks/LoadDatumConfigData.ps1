task LoadDatumConfigData {

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