param (
    [System.String]
    $RsopFolder = (property RsopFolder 'RSOP')
)

task CompileDatumRsop {
    if (![System.IO.Path]::IsPathRooted($rsopFolder)) {
        $rsopOutputPath = Join-Path -Path $BuildOutput -ChildPath $rsopFolder
    }
    else {
        $RsopOutputPath = $rsopFolder
    }

    if (-not (Test-Path -Path $rsopOutputPath)) {
        New-Item -Path $rsopOutputPath -ItemType Directory -Force | Out-Null
    }

    $rsopOutputPathVersion = Join-Path -Path $RsopOutputPath -ChildPath $BuildVersion
    if (-not (Test-Path -Path $rsopOutputPathVersion)) {
        New-Item -Path $rsopOutputPathVersion -ItemType Directory -Force | Out-Null
    }

    Write-Build Green "Generating RSOP output for $($configurationData.AllNodes.Count) nodes"
    $configurationData.AllNodes |
    Where-Object Name -ne * |
    ForEach-Object {
        $nodeRSOP = Get-DatumRsop -Datum $datum -AllNodes $_
        $nodeRSOP | Convertto-Yaml -OutFile (Join-Path -Path $rsopOutputPathVersion -ChildPath "$($_.Name).yml") -Force
    }
}