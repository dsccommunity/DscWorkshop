task DownloadDscConfigurations {
    $PSDependConfigurationDefinition = "$ProjectPath\PSDepend.DSC_Configurations.psd1"
    if (Test-Path $PSDependConfigurationDefinition) {
        Write-Build Green 'Pull dependencies from PSDepend.DSC_Configurations.psd1'
        $psDependParams = @{
            Path    = $PSDependConfigurationDefinition
            Confirm = $false
            Target  = $configurationPath
        }
        Invoke-PSDependInternal -PSDependParameters $psDependParams -Reporitory $GalleryRepository
    }
}
