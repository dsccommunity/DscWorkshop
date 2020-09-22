task ConnectAz {

    if ([string]::IsNullOrWhitespace($AzureTenantId) -and $null -eq [string]::IsNullOrWhitespace($env:AzureTenantId))
    {
        Write-Verbose -Message "Neither parameter AzureTenantId nor env variable AzureTenantId present."
        return
    }

    if ($null -eq $AzureServicePrincipal -or ([string]::IsNullOrWhitespace($env:ServicePrincipalAppId) -or [string]::IsNullOrWhitespace($env:ServicePrincipalKey)))
    {
        Write-Verbose -Message "Neither parameter AzureServicePrincipal nor env variables ServicePrincipalAppId,ServicePrincipalKey present."
        return
    }

    if ($null -eq $AzureServicePrincipal)
    {
        $AzureServicePrincipal = [pscredential]::new($env:ServicePrincipalAppId, ($env:ServicePrincipalKey | ConvertTo-SecureString -AsPlainText -Force))
    }

    $tenant = if (-not [string]::IsNullOrWhitespace($AzureTenantId))
    {
        $AzureTenantId
    }
    else
    {
        $env:AzureTenantId
    }

    Connect-AzAccount -Credential $AzureServicePrincipal -Tenant $tenant -ServicePrincipal -Force
}
