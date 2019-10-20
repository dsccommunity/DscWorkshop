task LoadDatumConfigData {

    Import-Module -Name PowerShell-Yaml -Scope Global
    Import-Module -Name Datum -Scope Global

    $datumDefinitionFile = Join-Path -Resolve -Path $configDataPath -ChildPath 'Datum.yml'
    Write-Build Green "Loading Datum Definition from '$datumDefinitionFile'"
    $global:datum = New-DatumStructure -DefinitionFile $datumDefinitionFile
    if (-not ($datum.AllNodes)) {
        Write-Error 'No nodes found in the solution'
    }

    if ($RoleName) {
        Write-Build Green "Building Configdata for Role $RoleName"
        $Global:ConfigurationData = Get-FilteredRoleConfigurationData -RoleName $RoleName -Datum $Datum
    }
    else {
        Write-Build Green "Building Configdata for Environment $Environment"
        $Global:ConfigurationData = Get-FilteredConfigurationData -Environment $Environment -Datum $Datum
    }

}
