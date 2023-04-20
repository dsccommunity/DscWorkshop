Configuration UserAmyPresent {
    Import-DSCResource -ModuleName 'xPSDesiredStateConfiguration'

    $cred = New-Object System.Management.Automation.PSCredential('amy', (ConvertTo-SecureString -String 'Somepass1' -AsPlainText -Force))

    Node UserAmyPresent
    {
        xUser 'UserAmyPresent'
        {
            Ensure   = 'Present'
            UserName = 'amy'
            Disabled = $true
            Password = $cred
        }
    }
}
