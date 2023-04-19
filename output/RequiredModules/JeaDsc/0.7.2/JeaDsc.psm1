<#
Actually this file is not required and serves as a dummy to work around this
issue with Pester: https://github.com/pester/Pester/issues/1456. If there is no
psm1 file references as RootModule, the JeaDsc module is considered a manifest
and not a script module.
#>

$script:localizedData = Get-LocalizedData -DefaultUICulture en-US

function Get-Dummy
{
    Write-Debug $script:localizedData.Dummy
}
