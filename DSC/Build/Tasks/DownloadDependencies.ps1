task DownloadDependencies -if ($DownloadResourcesAndConfigurations -or $Tasks -contains 'DownloadDependencies') DownloadDscConfigurations, DownloadDscResources -Before SetPsModulePath

task DownloadDscResources {
    $PSDependResourceDefinition = "$ProjectPath\PSDepend.DscResources.psd1"
    if (Test-Path $PSDependResourceDefinition) {
        $psDependParams = @{
            Path    = $PSDependResourceDefinition
            Confirm = $false
            Target  = $resourcePath
        }
        Invoke-PSDependInternal -PSDependParameters $psDependParams -Repository $Repository
    }
}
