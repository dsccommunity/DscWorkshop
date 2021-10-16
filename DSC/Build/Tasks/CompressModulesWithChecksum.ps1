task CompressModulesWithChecksum {

    if ($SkipCompressedModulesBuild)
    {
        Write-Host 'Skipping preparation of Compressed Modules as $SkipCompressedModulesBuild is set'
        return
    }

    Start-Transcript -Path "$BuildOutput\Logs\CompressModulesWithChecksum.log"

    try {

        if (-not (Test-Path -Path $BuildOutput\CompressedModules)) {
            mkdir -Path $BuildOutput\CompressedModules | Out-Null
        }

        if ($SkipCompressedModulesBuild)
        {
            Write-Host "Skipping preparation of Compressed Modules as '`$SkipCompressedModulesBuild' is set"
            return
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
    finally {
        Stop-Transcript
    } 
}
