$here = $PSScriptRoot
Import-Module ProtectedData
Import-Module powershell-yaml
$m = Import-Module Datum -PassThru

$datumDefinitionFile = Join-Path -Path $here -ChildPath DscConfigData\Datum.yml
$nodeDefinitions = Get-ChildItem -Path $here\DscConfigData\AllNodes -Recurse -Include *.yml
$environments = (Get-ChildItem -Path $here\DscConfigData\AllNodes -Directory).BaseName
$roleDefinitions = Get-ChildItem -Path $here\DscConfigData\Roles -Recurse -Include *.yml

& $m { $script:FileProviderDataCache = $null }
$datum = New-DatumStructure -DefinitionFile $datumDefinitionFile
$h = $datum.AllNodes.ToHashTable()

$rsop = Get-DatumRsop -Datum $datum -AllNodes $datum.AllNodes.Dev
$rsop
