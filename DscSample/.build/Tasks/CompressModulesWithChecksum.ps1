task CompressModulesWithChecksum {
    if (-not (Test-Path -Path $BuildOutput\CompressedModules))
    {
        mkdir -Path $BuildOutput\CompressedModules | Out-Null
    }
    $modules = Get-ModuleFromFolder -ModuleFolder "$ProjectPath\DSC_Resources\"
    $modules | Publish-ModuleToPullServer -OutputFolderPath $BuildOutput\CompressedModules
}