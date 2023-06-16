configuration ConfigurationBase {
    param (
        [Parameter()]
        [ValidateSet('Baseline', 'WebServer', 'FileServer')]
        [string]$SystemType
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xRegistry EnableRdp
    {
        Key       = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server'
        ValueName = 'fDenyTSConnection'
        ValueData = 0
        ValueType = 'Dword'
        Ensure    = 'Present'
    }
}
