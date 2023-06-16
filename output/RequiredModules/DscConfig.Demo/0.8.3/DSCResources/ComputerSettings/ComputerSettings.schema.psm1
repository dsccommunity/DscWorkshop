configuration ComputerSettings {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Description,

        [Parameter()]
        [string]
        $DomainName,

        [Parameter()]
        [string]
        $WorkGroupName,

        [Parameter()]
        [string]
        $JoinOU,

        [Parameter()]
        [pscredential]
        $Credential,

        [Parameter()]
        [string]
        $TimeZone,

        [Parameter()]
        [bool]$AllowRemoteDesktop,

        [Parameter()]
        [ValidateSet('Secure', 'NonSecure')]
        [string]$RemoteDesktopUserAuthentication
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc

    $timeZoneParamList = 'IsSingleInstance', 'TimeZone', 'PsDscRunAsCredential'
    $computerParamList = 'Name', 'Credential', 'Description', 'DomainName', 'JoinOU', 'PsDscRunAsCredential', 'Server', 'UnjoinCredential', 'WorkGroupName'

    $params = @{ }
    foreach ($item in ($PSBoundParameters.GetEnumerator() | Where-Object Key -In $computerParamList))
    {
        $params.Add($item.Key, $item.Value)
    }
    (Get-DscSplattedResource -ResourceName Computer -ExecutionName "Computer$($params.Name)" -Properties $params -NoInvoke).Invoke($params)

    if ($TimeZone)
    {
        $params = @{ }
        foreach ($item in ($PSBoundParameters.GetEnumerator() | Where-Object Key -In $timeZoneParamList))
        {
            $params.Add($item.Key, $item.Value)
        }
        $params.Add('IsSingleInstance', 'Yes')
        (Get-DscSplattedResource -ResourceName TimeZone -ExecutionName "TimeZone$($params.Name)" -Properties $params -NoInvoke).Invoke($params)
    }

    if ($RemoteDesktopUserAuthentication)
    {
        $params = @{ }
        $params.IsSingleInstance = 'Yes'
        $params.UserAuthentication = $RemoteDesktopUserAuthentication
        if ($AllowRemoteDesktop)
        {
            $params.Ensure = 'Present'
        }
        else
        {
            $params.Ensure = 'Absent'
        }
        (Get-DscSplattedResource -ResourceName RemoteDesktopAdmin -ExecutionName "RemoteDesktopAdmin$($params.Name)" -Properties $params -NoInvoke).Invoke($params)
    }
}
