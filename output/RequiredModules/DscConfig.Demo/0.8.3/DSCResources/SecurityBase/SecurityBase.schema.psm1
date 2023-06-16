configuration SecurityBase {
    param (
        [Parameter()]
        [ValidateSet('Baseline', 'WebServer', 'FileServer')]
        [string]
        $Role
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName SecurityPolicyDsc

    #Baseline
    xWindowsFeature DisableSmbV1
    {
        Name   = 'FS-SMB1'
        Ensure = 'Absent'
    }

    PowerShellExecutionPolicy ExecutionPolicyAllSigned
    {
        ExecutionPolicyScope = 'LocalMachine'
        ExecutionPolicy      = 'RemoteSigned'
    }

    UserRightsAssignment DenyLogonLocallyForAdministrator
    {
        Policy   = 'Deny_log_on_locally'
        Identity = 'contoso\Administrator'
    }

    UserRightsAssignment AllowLogonLocally
    {
        Policy   = 'Allow_log_on_locally'
        Identity = 'Administrators', 'Backup Operators'
    }

    #FileServer
    if ($Role -eq 'FileServer')
    {
        SecurityOption SecOptionsFileServer
        {
            Name                                                           = 'Web Server Secutiry options'
            Interactive_logon_Message_title_for_users_attempting_to_log_on = 'Secure File Server'
            Interactive_logon_Message_text_for_users_attempting_to_log_on  = 'Your are logging on to a secure file server'
            Accounts_Rename_administrator_account                          = 'a'
        }
    }

    #Web Server
    if ($Role -eq 'WebServer')
    {
        SecurityOption SecOptionsWebServer
        {
            Name                                                                         = 'Web Server Secutiry options'
            Interactive_logon_Message_title_for_users_attempting_to_log_on               = 'Secure Web Server'
            Interactive_logon_Message_text_for_users_attempting_to_log_on                = 'Your are logging on to a secure web server'
            Accounts_Rename_administrator_account                                        = 'a'
            Network_security_LAN_Manager_authentication_level                            = 'Send NTLMv2 responses only. Refuse LM & NTLM'
            Network_security_Do_not_store_LAN_Manager_hash_value_on_next_password_change = 'Enabled'
        }
    }
}
