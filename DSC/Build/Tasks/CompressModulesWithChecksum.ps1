task CompressModulesWithChecksum {

    if (-not (Test-Path -Path $BuildOutput\CompressedModules)) {
        mkdir -Path $BuildOutput\CompressedModules | Out-Null
    }

    if ($configurationData.AllNodes -and $CurrentJobNumber -eq 1) {
        
        $modules = Get-ModuleFromFolder -ModuleFolder "$ProjectPath\DscResources\"
        $compressedModulesPath = "$BuildOutput\CompressedModules"

        foreach ($module in $modules) {
            $destinationPath = Join-Path -Path $compressedModulesPath -ChildPath "$($module.Name)_$($module.Version).zip"
            Compress-Archive -Path "$($module.ModuleBase)\*" -DestinationPath $destinationPath
            $hash = (Get-FileHash -Path $destinationPath).Hash
        
            try {
                $stream = New-Object -TypeName System.IO.StreamWriter("$destinationPath.checksum", $false)
                [void] $stream.Write($hash)
            }
            finally {
                if ($stream) {
                    $stream.Close()
                }
            }
        }
    }
    else {
        Write-Build Green "No data in 'ConfigurationData.AllNodes', skipping task 'CompressModulesWithChecksum'."
    }
}
