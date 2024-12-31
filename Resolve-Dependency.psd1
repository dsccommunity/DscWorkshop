@{
    Gallery         = 'PSGallery'

    AllowPrerelease = $false
    WithYAML        = $true # Will also bootstrap PowerShell-Yaml to read other config files
    UsePSResourceGet = $true
    PSResourceGetVersion = '1.0.1'

    # PowerShellGet compatibility module only works when using PSResourceGet or ModuleFast.
    UsePowerShellGetCompatibilityModule = $true
    UsePowerShellGetCompatibilityModuleVersion = '3.0.23-beta23'
}
