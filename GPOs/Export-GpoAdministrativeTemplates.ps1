<#
.SYNOPSIS
    Export Administrative Template registry settings from GPO XML export.

.DESCRIPTION
    This script exports Administrative Template policies (Policy elements) from a GPO XML
    export and converts them to DSC-ready YAML format for use with the xRegistry resource.
    Supports both Get-GPOReport and RSOP XML formats.

.PARAMETER XmlPath
    Path to the GPO XML file to process.

.PARAMETER OutputPath
    Path where the YAML output file will be created. If not specified, uses the XML filename with
    '-AdministrativeTemplates.yml' suffix.

.PARAMETER Force
    Overwrite the output file if it already exists.

.EXAMPLE
    .\Export-GpoAdministrativeTemplates.ps1 -XmlPath ".\MyGPO.xml"

.EXAMPLE
    .\Export-GpoAdministrativeTemplates.ps1 -XmlPath ".\MyGPO.xml" -OutputPath ".\CustomOutput.yml" -Force

.NOTES
    Author: DSC Workshop GPO Migration Tool
    Version: 2.0
    Requires: PowerShell 5.1 or higher
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({
            if (-not (Test-Path $_))
            {
                throw "XML file not found: $_"
            }
            if ($_ -notmatch '\.xml$')
            {
                throw "File must be an XML file: $_"
            }
            return $true
        })]
    [string]$XmlPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try
{
    # Resolve full paths
    $XmlPath = Resolve-Path $XmlPath -ErrorAction Stop

    # Set default output path if not specified
    if (-not $OutputPath)
    {
        $xmlBaseName = [System.IO.Path]::GetFileNameWithoutExtension($XmlPath)
        $OutputPath = Join-Path $PSScriptRoot "$xmlBaseName-AdministrativeTemplates.yml"
    }

    # Check if output file exists
    if ((Test-Path $OutputPath) -and -not $Force)
    {
        throw "Output file already exists: $OutputPath. Use -Force to overwrite."
    }

    Write-Verbose "Reading XML file: $XmlPath"
    [xml]$xml = Get-Content $XmlPath -Raw -ErrorAction Stop

    Write-Verbose 'Detecting XML format (GPO vs RSOP)...'
    # Support both GPO format (Get-GPOReport) and RSOP format
    $rootElement = if ($xml.GPO) {
        Write-Verbose 'Detected GPO format (Get-GPOReport)'
        $xml.GPO
    } elseif ($xml.Rsop) {
        Write-Verbose 'Detected RSOP format'
        $xml.Rsop
    } else {
        throw 'Unknown XML format. Expected GPO or Rsop root element.'
    }

    Write-Verbose 'Extracting Administrative Templates (Policy elements)...'
    # Use SelectNodes with local-name() to be namespace-agnostic
    $q8Policies = $rootElement.SelectNodes("//*[local-name()='Policy' and @*[local-name()='Category']]")

    if (-not $q8Policies)
    {
        throw 'No Administrative Template policies found in XML file.'
    }

    # Comprehensive registry mapping for Windows administrative templates
    $policyMap = @{
        'Prevent enabling lock screen camera'                                                                                                       = @('Software\Policies\Microsoft\Windows\Personalization', 'NoLockScreenCamera', 'Dword', 1, 0)
        'Prevent enabling lock screen slide show'                                                                                                   = @('Software\Policies\Microsoft\Windows\Personalization', 'NoLockScreenSlideshow', 'Dword', 1, 0)
        'Turn off multicast name resolution'                                                                                                        = @('Software\Policies\Microsoft\Windows NT\DNSClient', 'EnableMulticast', 'Dword', 0, 1)
        'Enable insecure guest logons'                                                                                                              = @('Software\Policies\Microsoft\Windows\LanmanWorkstation', 'AllowInsecureGuestAuth', 'Dword', 1, 0)
        'Prohibit use of Internet Connection Sharing on your DNS domain network'                                                                    = @('Software\Policies\Microsoft\Windows\Network Connections', 'NC_ShowSharedAccessUI', 'Dword', 0, 1)
        'Windows Firewall: Prohibit notifications'                                                                                                  = @('Software\Policies\Microsoft\WindowsFirewall\DomainProfile', 'DisableNotifications', 'Dword', 1, 0)
        'Windows Firewall: Protect all network connections'                                                                                         = @('Software\Policies\Microsoft\WindowsFirewall\DomainProfile', 'EnableFirewall', 'Dword', 1, 0)
        'Prohibit connection to non-domain networks when connected to domain authenticated network'                                                 = @('Software\Policies\Microsoft\Windows\WcmSvc\GroupPolicy', 'fBlockNonDomain', 'Dword', 1, 0)
        'Allow Windows to automatically connect to suggested open hotspots, to networks shared by contacts, and to hotspots offering paid services' = @('Software\Microsoft\WcmSvc\wifinetworkmanager\config', 'AutoConnectAllowedOEM', 'Dword', 0, 1)
        'Remote host allows delegation of non-exportable credentials'                                                                               = @('Software\Policies\Microsoft\Windows\CredentialsDelegation', 'AllowProtectedCreds', 'Dword', 1, 0)
        'Turn off downloading of print drivers over HTTP'                                                                                           = @('Software\Policies\Microsoft\Windows NT\Printers', 'DisableWebPnPDownload', 'Dword', 1, 0)
        'Turn off Internet download for Web publishing and online ordering wizards'                                                                 = @('Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', 'NoWebServices', 'Dword', 1, 0)
        'Enumerate local users on domain-joined computers'                                                                                          = @('Software\Policies\Microsoft\Windows\System', 'EnumerateLocalUsers', 'Dword', 0, 1)
        'Turn on convenience PIN sign-in'                                                                                                           = @('Software\Policies\Microsoft\Windows\System', 'AllowDomainPINLogon', 'Dword', 0, 1)
        'Require a password when a computer wakes (on battery)'                                                                                     = @('Software\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51', 'DCSettingIndex', 'Dword', 1, 0)
        'Require a password when a computer wakes (plugged in)'                                                                                     = @('Software\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51', 'ACSettingIndex', 'Dword', 1, 0)
        'Configure Solicited Remote Assistance'                                                                                                     = @('Software\Policies\Microsoft\Windows NT\Terminal Services', 'fAllowToGetHelp', 'Dword', 0, 1)
        'Restrict Unauthenticated RPC clients'                                                                                                      = @('Software\Policies\Microsoft\Windows NT\Rpc', 'RestrictRemoteClients', 'Dword', 1, 0)
        'Allow Microsoft accounts to be optional'                                                                                                   = @('Software\Microsoft\Windows\CurrentVersion\Policies\System', 'MSAOptional', 'Dword', 1, 0)
        'Disallow Autoplay for non-volume devices'                                                                                                  = @('Software\Policies\Microsoft\Windows\Explorer', 'NoAutoplayfornonVolume', 'Dword', 1, 0)
        'Set the default behavior for AutoRun'                                                                                                      = @('Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', 'NoAutorun', 'Dword', 1, 0)
        'Turn off Autoplay'                                                                                                                         = @('Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', 'NoDriveTypeAutoRun', 'Dword', 255, 0)
        'Configure enhanced anti-spoofing'                                                                                                          = @('Software\Policies\Microsoft\Biometrics\FacialFeatures', 'EnhancedAntiSpoofing', 'Dword', 1, 0)
        'Turn off Microsoft consumer experiences'                                                                                                   = @('Software\Policies\Microsoft\Windows\CloudContent', 'DisableWindowsConsumerFeatures', 'Dword', 1, 0)
        'Enumerate administrator accounts on elevation'                                                                                             = @('Software\Microsoft\Windows\CurrentVersion\Policies\CredUI', 'EnumerateAdministrators', 'Dword', 0, 1)
        'Prevent downloading of enclosures'                                                                                                         = @('Software\Policies\Microsoft\Internet Explorer\Feeds', 'DisableEnclosureDownload', 'Dword', 1, 0)
        'Allow indexing of encrypted files'                                                                                                         = @('Software\Policies\Microsoft\Windows\Windows Search', 'AllowIndexingEncryptedStoresOrItems', 'Dword', 0, 1)
        'Configure Windows Defender SmartScreen'                                                                                                    = @('Software\Policies\Microsoft\Windows\System', 'EnableSmartScreen', 'Dword', 1, 0)
        'Enables or disables Windows Game Recording and Broadcasting'                                                                               = @('Software\Policies\Microsoft\Windows\GameDVR', 'AllowGameDVR', 'Dword', 0, 1)
        'Allow Windows Ink Workspace'                                                                                                               = @('Software\Policies\Microsoft\WindowsInkWorkspace', 'AllowWindowsInkWorkspace', 'Dword', 1, 0)
        'Allow user control over installs'                                                                                                          = @('Software\Policies\Microsoft\Windows\Installer', 'EnableUserControl', 'Dword', 0, 1)
        'Always install with elevated privileges'                                                                                                   = @('Software\Policies\Microsoft\Windows\Installer', 'AlwaysInstallElevated', 'Dword', 0, 1)
        'Sign-in last interactive user automatically after a system-initiated restart'                                                              = @('Software\Microsoft\Windows\CurrentVersion\Policies\System', 'DisableAutomaticRestartSignOn', 'Dword', 1, 0)
        'Turn on PowerShell Script Block Logging'                                                                                                   = @('Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging', 'EnableScriptBlockLogging', 'Dword', 1, 0)
        'Allow Basic authentication'                                                                                                                = @('Software\Policies\Microsoft\Windows\WinRM\Client', 'AllowBasic', 'Dword', 0, 1)
        'Allow unencrypted traffic'                                                                                                                 = @('Software\Policies\Microsoft\Windows\WinRM\Client', 'AllowUnencryptedTraffic', 'Dword', 0, 1)
        'Disallow Digest authentication'                                                                                                            = @('Software\Policies\Microsoft\Windows\WinRM\Client', 'AllowDigest', 'Dword', 0, 1)
        'Disallow WinRM from storing RunAs credentials'                                                                                             = @('Software\Policies\Microsoft\Windows\WinRM\Service', 'DisableRunAs', 'Dword', 1, 0)
        'Do not allow passwords to be saved'                                                                                                        = @('Software\Policies\Microsoft\Windows NT\Terminal Services', 'DisablePasswordSaving', 'Dword', 1, 0)
        'Do not allow drive redirection'                                                                                                            = @('Software\Policies\Microsoft\Windows NT\Terminal Services', 'fDisableCdm', 'Dword', 1, 0)
        'Always prompt for password upon connection'                                                                                                = @('Software\Policies\Microsoft\Windows NT\Terminal Services', 'fPromptForPassword', 'Dword', 1, 0)
        'Require secure RPC communication'                                                                                                          = @('Software\Policies\Microsoft\Windows NT\Terminal Services', 'fEncryptRPCTraffic', 'Dword', 1, 0)
        'Set client connection encryption level'                                                                                                    = @('Software\Policies\Microsoft\Windows NT\Terminal Services', 'MinEncryptionLevel', 'Dword', 3, 0)
        'Windows Firewall: Allow logging'                                                                                                           = @('Software\Policies\Microsoft\WindowsFirewall\DomainProfile\Logging', 'LogFilePath', 'String', '%SystemRoot%\System32\LogFiles\Firewall\pfirewall.log', '')
        'Hardened UNC Paths'                                                                                                                        = @('Software\Policies\Microsoft\Windows\NetworkProvider\HardenedPaths', '\\*\NETLOGON', 'String', 'RequireMutualAuthentication=1,RequireIntegrity=1', '')
        'Boot-Start Driver Initialization Policy'                                                                                                   = @('System\CurrentControlSet\Policies\EarlyLaunch', 'DriverLoadPolicy', 'Dword', 3, 0)
        'Configure password backup directory'                                                                                                       = @('Software\Policies\Microsoft\Windows\LAPS', 'BackupDirectory', 'Dword', 2, 0)
        'Enable password backup for DSRM accounts'                                                                                                  = @('Software\Policies\Microsoft\Windows\LAPS', 'BackupDSRMPassword', 'Dword', 1, 0)
        'Enable password encryption'                                                                                                                = @('Software\Policies\Microsoft\Windows\LAPS', 'ADEncryptedPasswordHistorySize', 'Dword', 1, 0)
        'Specify the maximum log file size (KB)'                                                                                                    = @('Software\Policies\Microsoft\Windows\EventLog\Application', 'MaxSize', 'Dword', 32768, 0)
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Administrative Template Registry Settings (q8:RegistrySettings)')
    [void]$sb.AppendLine('# Extracted from: Win11-24H2-MSFT-BaselineTest on Win11-24H2-MSFT-BaselineTest.xml')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('RegistryValues:')
    [void]$sb.AppendLine('  Values:')

    $count = 0
    foreach ($policy in $q8Policies)
    {
        if (-not $policy.Name)
        {
            continue
        }

        $mapping = $policyMap[$policy.Name]
        if ($mapping)
        {
            $regPath = $mapping[0]
            $valueName = $mapping[1]
            $valueType = $mapping[2]
            $enabledValue = $mapping[3]
            $disabledValue = $mapping[4]

            $value = if ($policy.State -eq 'Enabled')
            {
                $enabledValue
            }
            else
            {
                $disabledValue
            }

            # Handle policies with additional settings (Numeric, DropDownList, etc.)
            if ($policy.Numeric)
            {
                $value = [int]$policy.Numeric.Value
            }
            elseif ($policy.DropDownList -and $policy.DropDownList.Value.Name)
            {
                # Map dropdown values to registry values
                $dropValue = $policy.DropDownList.Value.Name
                if ($policy.Name -eq 'Boot-Start Driver Initialization Policy')
                {
                    $value = switch ($dropValue)
                    {
                        'Good, unknown and bad but critical'
                        {
                            3
                        }
                        'Good and unknown'
                        {
                            1
                        }
                        'Good only'
                        {
                            8
                        }
                        default
                        {
                            3
                        }
                    }
                }
                elseif ($policy.Name -eq 'Set client connection encryption level')
                {
                    $value = switch ($dropValue)
                    {
                        'High Level'
                        {
                            3
                        }
                        'Client Compatible'
                        {
                            2
                        }
                        'Low'
                        {
                            1
                        }
                        default
                        {
                            3
                        }
                    }
                }
                elseif ($policy.Name -eq 'Allow Windows Ink Workspace')
                {
                    $value = switch ($dropValue)
                    {
                        'On, but disallow access above lock'
                        {
                            1
                        }
                        'Off'
                        {
                            0
                        }
                        default
                        {
                            1
                        }
                    }
                }
            }

            [void]$sb.AppendLine("    # $($policy.Name)")
            [void]$sb.AppendLine("    # Category: $($policy.Category)")
            [void]$sb.AppendLine("    # State: $($policy.State)")
            [void]$sb.AppendLine("    - Key: HKEY_LOCAL_MACHINE\$regPath")
            [void]$sb.AppendLine("      ValueName: $valueName")
            [void]$sb.AppendLine("      ValueData: $value")
            [void]$sb.AppendLine("      ValueType: $valueType")
            [void]$sb.AppendLine('      Ensure: Present')
            [void]$sb.AppendLine('      Force: true')
            $count++
        }
        else
        {
            Write-Verbose "WARNING: No mapping found for policy: $($policy.Name)"
        }
    }

    # Write output
    $content = $sb.ToString()
    $content | Out-File -FilePath $OutputPath -Encoding utf8 -NoNewline

    Write-Output ''
    Write-Output '✅ Administrative Templates exported successfully!'
    Write-Output "   Settings exported: $count"
    Write-Output "   Output: $OutputPath"
    Write-Output ''

    exit 0
}
catch
{
    Write-Error "Failed to export administrative templates: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
