param (
    [string]
    $RsopFolder = (property RsopFolder 'RSOP')
)

task CompileDatumRsop {
 
    Start-Transcript -Path "$BuildOutput\Logs\CompileDatumRsop.log"

    try {
        $rsopOutputPath = if (-not [System.IO.Path]::IsPathRooted($RsopFolder)) {
            Join-Path -Path $BuildOutput -ChildPath $RsopFolder
        }
        else {
            $RsopFolder
        }
        if (-not (Test-Path -Path $rsopOutputPath)) {
            mkdir -Path $rsopOutputPath -Force | Out-Null
        }

        if ($configurationData.AllNodes) {
            Write-Build Green "Generating RSOP output for $($configurationData.AllNodes.Count) nodes..."
            $configurationData.AllNodes |
            Where-Object Name -ne * |
            ForEach-Object {
                Write-Build Green "`t$($_.Name)"
                $nodeRsop = Get-DatumRsop -Datum $datum -AllNodes ([ordered]@{ } + $_)
                $nodeRsop | ConvertTo-Json -Depth 40 | ConvertFrom-Json | Convertto-Yaml -OutFile (Join-Path -Path $rsopOutputPath -ChildPath "$($_.Name).yml") -Force
            }
        }
        else {
            Write-Build Green "No data for generating RSOP output."
        }
    }
    finally {
        Stop-Transcript
    }
}
