task DownloadDscConfigurations {
    $PSDependConfigurationDefinition = "$ProjectPath\PSDepend.DscConfigurations.psd1"
    if (Test-Path $PSDependConfigurationDefinition) {
        Write-Build Green 'Pull dependencies from PSDepend.DscConfigurations.psd1'
        $psDependParams = @{
            Path    = $PSDependConfigurationDefinition
            Confirm = $false
            Target  = $configurationPath
        }
        Invoke-PSDependInternal -PSDependParameters $psDependParams -Repository $Repository
    }
}
