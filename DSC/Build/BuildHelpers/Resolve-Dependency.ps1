function Resolve-Dependency {
    [CmdletBinding()]
    param()

    Write-Host 'Downloading dependencies, this may take a while' -ForegroundColor Green
    if (-not (Get-PackageProvider -Name NuGet -ForceBootstrap)) {
        $providerBootstrapParams = @{
            Name           = 'nuget'
            Force          = $true
            ForceBootstrap = $true
        }
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            $providerBootstrapParams.Add('Verbose', $Verbose)
        }
        if ($GalleryProxy) {
            $providerBootstrapParams.Add('Proxy', $GalleryProxy)
        }
        $null = Install-PackageProvider @providerBootstrapParams
    }

    if (-not (Get-Module -Name "$buildModulesPath\PSDepend" -ListAvailable -ErrorAction SilentlyContinue)) {
        Write-Verbose -Message 'BootStrapping PSDepend'
        Write-Verbose -Message "Parameter $buildOutput"
        $installPSDependParams = @{
            Name    = 'PSDepend'
            Path    = $buildModulesPath
            Confirm = $false
        }
        if ($PSBoundParameters.ContainsKey('verbose')) {
            $installPSDependParams.Add('Verbose', $Verbose)
        }
        if ($Repository) {
            $installPSDependParams.Add('Repository', $Repository)
        }
        if ($GalleryProxy) {
            $installPSDependParams.Add('Proxy', $GalleryProxy)
        }
        if ($GalleryCredential) {
            $installPSDependParams.Add('ProxyCredential', $GalleryCredential)
        }

        try {
            Save-Module @installPSDependParams -ErrorAction Stop
        }
        catch {
            Save-Module @installPSDependParams
        }
    }

    $psDependParams = @{
        Force = $true
        Path  = "$ProjectPath\PSDepend.Build.psd1"
        #was removed in some private projects for unknown reason
        #Target = $buildModulesPath 
    }
    if ($PSBoundParameters.ContainsKey('Verbose')) {
        $psDependParams.Add('Verbose', $Verbose)
    }
    Import-Module -Name PSDepend
    Invoke-PSDependInternal -PSDependParameters $psDependParams -Repository $Repository
    Write-Verbose 'Project Bootstrapped, returning to Invoke-Build'
}
