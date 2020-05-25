param (
    [string]
    $RsopFolder = (property RsopFolder 'RSOP')
)

task CompileDatumRsop {
    
    if (-not [System.IO.Path]::IsPathRooted($rsopFolder)) {
        $rsopOutputPath = Join-Path -Path $BuildOutput -ChildPath $rsopFolder
    }
    else {
        $RsopOutputPath = $rsopFolder
    }

    if (-not (Test-Path -Path $rsopOutputPath)) {
        mkdir -Path $rsopOutputPath -Force | Out-Null
    }

    $rsopOutputPathVersion = Join-Path -Path $RsopOutputPath -ChildPath $BuildVersion
    if (-not (Test-Path -Path $rsopOutputPathVersion)) {
        mkdir -Path $rsopOutputPathVersion -Force | Out-Null
    }

    if ($configurationData.AllNodes) {
        Write-Build Green "Generating RSOP output for $($configurationData.AllNodes.Count) nodes."
        $configurationData.AllNodes |
        Where-Object Name -ne * |
        ForEach-Object {
            $nodeRSOP = Get-DatumRsop -Datum $datum -AllNodes ([ordered]@{ } + $_)
            $nodeRSOP | ConvertTo-Json -Depth 40 | ConvertFrom-Json | Convertto-Yaml -OutFile (Join-Path -Path $rsopOutputPathVersion -ChildPath "$($_.Name).yml") -Force
        }
    }
    else {
        Write-Build Green "No data for generating RSOP output."
    }
}
