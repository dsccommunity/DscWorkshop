function Get-DscErrorMessage {
    Param(
        [System.Exception]
        $Exception
    )

    switch ($Exception) {
        { $_ -is [System.Management.Automation.ItemNotFoundException] } {
            #can be ignored, very likely caused by Get-Item within the PSDesiredStateConfiguration module
            break
        }
        { $_.Message -match "Unable to find repository 'PSGallery" } {
            'Error in Package Management'
            break
        }
        
        { $_.Message -match 'A second CIM class definition'} {
            # This happens when several versions of same module are available. 
            # Mainly a problem when when $Env:PSModulePath is polluted or 
            # DscResources or DSC_Configuration are not clean
            'Multiple version of the same module exist'
            break
        }
        { $_ -is [System.Management.Automation.ParentContainsErrorRecordException]} {
            "Compilation Error: $_.Message"
            break
        }
        { $_.Message -match ([regex]::Escape("Cannot find path 'HKLM:\SOFTWARE\Microsoft\Powershell\3\DSC'")) } {
            if ($_.InvocationInfo.PositionMessage -match 'PSDscAllowDomainUser') {
                # This tend to be repeated for all nodes even if only 1 is affected
                'Domain user credentials are used and PSDscAllowDomainUser is not set'
                break
            }
            elseif ($_.InvocationInfo.PositionMessage -match 'PSDscAllowPlainTextPassword') {
                "It is not recommended to use plain text password. Use PSDscAllowPlainTextPassword = `$false"
                break
            }
            else {
                #can be ignored
                break
            }
        }
    }
}
