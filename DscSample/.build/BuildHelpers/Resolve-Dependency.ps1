function Resolve-Dependency
{
    [CmdletBinding()]
    param()

    Write-Host "Downloading dependencies, this may take a while" -ForegroundColor Green
    if (!(Get-PackageProvider -Name NuGet -ForceBootstrap))
    {
        $providerBootstrapParams = @{
            Name           = 'nuget'
            force          = $true
            ForceBootstrap = $true
        }
        if ($PSBoundParameters.ContainsKey('Verbose'))
        {
            $providerBootstrapParams.Add('Verbose', $Verbose)
        }
        if ($GalleryProxy)
        {
            $providerBootstrapParams.Add('Proxy', $GalleryProxy)
        }
        $null = Install-PackageProvider @providerBootstrapParams
        #Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
        
    Write-Verbose -Message 'BootStrapping PSDepend'
    Write-Verbose -Message "Parameter $buildOutput"
    $installPSDependParams = @{
        Name    = 'PSDepend'
        Path    = $buildModulesPath
        Confirm = $false
    }
    if ($PSBoundParameters.ContainsKey('verbose'))
    {
        $installPSDependParams.Add('Verbose', $Verbose)
    }
    if ($GalleryRepository)
    {
        $installPSDependParams.Add('Repository', $GalleryRepository)
    }
    if ($GalleryProxy)
    {
        $installPSDependParams.Add('Proxy', $GalleryProxy)
    }
    if ($GalleryCredential)
    {
        $installPSDependParams.Add('ProxyCredential', $GalleryCredential)
    }
    Save-Module @installPSDependParams

    $PSDependParams = @{
        Force = $true
        Path  = "$ProjectPath\PSDepend.Build.psd1"
    }
    if ($PSBoundParameters.ContainsKey('Verbose'))
    {
        $PSDependParams.add('Verbose', $Verbose)
    }
    Invoke-PSDepend @PSDependParams
    Write-Verbose 'Project Bootstrapped, returning to Invoke-Build'
}