<#
.SYNOPSIS
    Export Windows Firewall Profile Settings from GPO XML export.

.DESCRIPTION
    This script exports Windows Firewall profile settings (WindowsFirewall extension) from a GPO XML
    export and converts them to DSC-ready YAML format for use with the NetworkingDsc FirewallProfile resource.
    Supports both Get-GPOReport and RSOP XML formats.

.PARAMETER XmlPath
    Path to the GPO XML file to process.

.PARAMETER OutputPath
    Path where the YAML output file will be created. If not specified, uses the XML filename with
    '-FirewallProfiles.yml' suffix.

.PARAMETER Force
    Overwrite the output file if it already exists.

.INPUTS
    XmlPath: String - Path to GPO XML file to process
    OutputPath: String - Optional path for YAML output file
    Force: Switch - Overwrite existing output file

.OUTPUTS
    String path to created YAML file on success, nothing on failure

.EXAMPLE
    .\Export-GpoFirewallProfiles.ps1 -XmlPath ".\MyGPO.xml"

.EXAMPLE
    .\Export-GpoFirewallProfiles.ps1 -XmlPath ".\MyGPO.xml" -OutputPath ".\CustomOutput.yml" -Force

.NOTES
    Author: DSC Workshop GPO Migration Tool
    Version: 2.0
    Requires: PowerShell 5.1 or higher
#>

[OutputType([System.String])]
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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
        $OutputPath = Join-Path $PSScriptRoot "$xmlBaseName-FirewallProfiles.yml"
    }

    Write-Verbose "Reading XML file: $XmlPath"
    [xml]$xml = Get-Content $XmlPath -Raw -ErrorAction Stop

    # Support both GPO format (Get-GPOReport) and RSOP format
    Write-Verbose 'Detecting XML format...'
    $extensionDataCollection = if ($xml.GPO) {
        Write-Verbose 'Detected GPO format (Get-GPOReport)'
        $xml.GPO.Computer.ExtensionData
    } elseif ($xml.Rsop) {
        Write-Verbose 'Detected RSOP format'
        $xml.Rsop.ComputerResults.ExtensionData
    } else {
        throw 'Unknown XML format. Expected GPO or Rsop root element.'
    }

    # Get the Windows Firewall extension
    Write-Verbose 'Locating Windows Firewall extension data...'
    # Handle both GPO format ($_.Name is string) and RSOP format ($_.Name.'#text')
    $firewallExt = $extensionDataCollection | Where-Object {
        ($_.Name -eq 'Windows Firewall') -or ($_.Name.'#text' -eq 'Windows Firewall')
    }

    if (-not $firewallExt)
    {
        throw 'No Windows Firewall settings found in XML file. Ensure the XML is a valid GPO RSOP export.'
    }

    # Generate source filename for header
    $sourceFilename = if ($XmlPath)
    {
        Split-Path -Leaf $XmlPath
    }
    else
    {
        'Unknown source'
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Windows Firewall Profile Settings')
    [void]$sb.AppendLine("# Exported from: $sourceFilename")
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# This configuration uses the NetworkingDsc FirewallProfile resource')
    [void]$sb.AppendLine('# to manage Windows Firewall profile settings.')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('FirewallProfiles:')
    [void]$sb.AppendLine('  Profiles:')

    <#
    .SYNOPSIS
        Extracts the text value from a firewall profile setting XML node.

    .DESCRIPTION
        Helper function that navigates into a firewall profile setting XML node and extracts
        the text content from the nested Value element using namespace-agnostic XPath.
        Returns $null if the node is null or does not contain a Value element.

    .PARAMETER node
        The XML node (System.Xml.XmlElement) representing a firewall profile setting element.
        This is typically a node like EnableFirewall, DefaultInboundAction, etc., which contains
        a nested Value element with the actual setting value.
    #>
    function Get-FirewallValue
    {
        param($node)
        if ($node)
        {
            $valueNode = $node.SelectSingleNode('./*[local-name()="Value"]')
            if ($valueNode)
            {
                return $valueNode.'#text'
            }
        }
        return $null
    }

    # Process each profile
    $profiles = @(
        @{XmlName = 'DomainProfile'; FriendlyName = 'Domain' },
        @{XmlName = 'PublicProfile'; FriendlyName = 'Public' },
        @{XmlName = 'PrivateProfile'; FriendlyName = 'Private' }
    )

    foreach ($prof in $profiles)
    {
        $profile = $firewallExt.Extension.SelectSingleNode(".//*[local-name()='$($prof.XmlName)']")
        if (-not $profile)
        {
            continue
        }

        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("    # $($prof.FriendlyName) Profile")
        [void]$sb.AppendLine("    - Name: $($prof.FriendlyName)")

        # EnableFirewall
        $enableFirewall = Get-FirewallValue $profile.SelectSingleNode("./*[local-name()='EnableFirewall']")
        if ($enableFirewall)
        {
            $enabled = if ($enableFirewall -eq 'true')
            {
                'true'
            }
            else
            {
                'false'
            }
            [void]$sb.AppendLine("      Enabled: $enabled")
        }

        # DefaultInboundAction (true=Block, false=Allow)
        $inbound = Get-FirewallValue $profile.SelectSingleNode("./*[local-name()='DefaultInboundAction']")
        if ($inbound)
        {
            $action = if ($inbound -eq 'true')
            {
                'Block'
            }
            else
            {
                'Allow'
            }
            [void]$sb.AppendLine("      DefaultInboundAction: $action")
        }

        # DefaultOutboundAction (true=Block, false=Allow)
        $outbound = Get-FirewallValue $profile.SelectSingleNode("./*[local-name()='DefaultOutboundAction']")
        if ($outbound)
        {
            $action = if ($outbound -eq 'true')
            {
                'Block'
            }
            else
            {
                'Allow'
            }
            [void]$sb.AppendLine("      DefaultOutboundAction: $action")
        }

        # DisableNotifications (inverse for NotifyOnListen)
        $disableNotify = Get-FirewallValue $profile.SelectSingleNode("./*[local-name()='DisableNotifications']")
        if ($disableNotify)
        {
            $notifyOnListen = if ($disableNotify -eq 'true')
            {
                'false'
            }
            else
            {
                'true'
            }
            [void]$sb.AppendLine("      NotifyOnListen: $notifyOnListen  # Inverse of DisableNotifications")
        }

        # AllowLocalPolicyMerge
        $allowLocal = Get-FirewallValue $profile.SelectSingleNode("./*[local-name()='AllowLocalPolicyMerge']")
        if ($allowLocal)
        {
            $value = if ($allowLocal -eq 'true')
            {
                'true'
            }
            else
            {
                'false'
            }
            [void]$sb.AppendLine("      AllowLocalFirewallRules: $value")
        }

        # AllowLocalIPsecPolicyMerge
        $allowIPsec = Get-FirewallValue $profile.SelectSingleNode("./*[local-name()='AllowLocalIPsecPolicyMerge']")
        if ($allowIPsec)
        {
            $value = if ($allowIPsec -eq 'true')
            {
                'true'
            }
            else
            {
                'false'
            }
            [void]$sb.AppendLine("      AllowLocalIPsecRules: $value")
        }

        # LogFileSize
        $logSize = Get-FirewallValue $profile.SelectSingleNode("./*[local-name()='LogFileSize']")
        if ($logSize)
        {
            [void]$sb.AppendLine("      LogMaxSizeKilobytes: $logSize")
        }

        # LogDroppedPackets
        $logDropped = Get-FirewallValue $profile.SelectSingleNode("./*[local-name()='LogDroppedPackets']")
        if ($logDropped)
        {
            $value = if ($logDropped -eq 'true')
            {
                'true'
            }
            else
            {
                'false'
            }
            [void]$sb.AppendLine("      LogBlocked: $value")
        }

        # LogSuccessfulConnections
        $logSuccess = Get-FirewallValue $profile.SelectSingleNode("./*[local-name()='LogSuccessfulConnections']")
        if ($logSuccess)
        {
            $value = if ($logSuccess -eq 'true')
            {
                'true'
            }
            else
            {
                'false'
            }
            [void]$sb.AppendLine("      LogAllowed: $value")
        }
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('# ==============================================================================')
    [void]$sb.AppendLine('# NOTES:')
    [void]$sb.AppendLine('# ==============================================================================')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# This configuration uses the FirewallProfiles composite resource which wraps')
    [void]$sb.AppendLine('# the FirewallProfile resource from the NetworkingDsc module.')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# The Name property must be one of: Domain, Public, or Private')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# Property Mappings:')
    [void]$sb.AppendLine('#   - Enabled: True/False - Enable or disable the firewall for this profile')
    [void]$sb.AppendLine('#   - DefaultInboundAction: Block/Allow/NotConfigured')
    [void]$sb.AppendLine('#   - DefaultOutboundAction: Block/Allow/NotConfigured')
    [void]$sb.AppendLine('#   - NotifyOnListen: True/False - Show notification when app is blocked')
    [void]$sb.AppendLine('#   - AllowLocalFirewallRules: True/False - Allow local admins to create rules')
    [void]$sb.AppendLine('#   - AllowLocalIPsecRules: True/False - Allow local IPsec policy merge')
    [void]$sb.AppendLine('#   - LogMaxSizeKilobytes: Maximum size of firewall log file')
    [void]$sb.AppendLine('#   - LogBlocked: True/False - Log dropped packets')
    [void]$sb.AppendLine('#   - LogAllowed: True/False - Log successful connections')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# All 3 firewall profiles from the Windows 11 24H2 Microsoft Baseline')
    [void]$sb.AppendLine('# are included in this configuration.')

    # Prepare content and ensure it ends with a newline
    $content = $sb.ToString()
    if (-not $content.EndsWith([Environment]::NewLine))
    {
        $content += [Environment]::NewLine
    }

    # Implement Force pattern before ShouldProcess
    if ($Force.IsPresent -and -not $Confirm)
    {
        $ConfirmPreference = 'None'
    }

    # Prepare ShouldProcess messages
    $profileCount = $profiles.Count
    $descriptionMessage = "Export $profileCount Windows Firewall profile settings to '$OutputPath'."
    $confirmationMessage = "Export firewall profiles to '$OutputPath'?"
    $captionMessage = 'Export Firewall Profile Settings'

    if ($PSCmdlet.ShouldProcess($descriptionMessage, $confirmationMessage, $captionMessage))
    {
        $outFileParams = @{
            FilePath = $OutputPath
            Encoding = 'utf8'
        }

        if ($Force)
        {
            $outFileParams['Force'] = $true
        }

        $content | Out-File @outFileParams

        Write-Output ''
        Write-Output '✅ Firewall profile settings exported successfully!'
        Write-Output "   Profiles exported: $profileCount"
        Write-Output "   Output: $OutputPath"
        Write-Output ''
    }
    else
    {
        Write-Verbose 'Operation cancelled by user.'
    }

    return
}
catch
{
    Write-Error -Message "Failed to export firewall profile settings from GPO XML" `
                -Exception $_.Exception `
                -Category InvalidOperation `
                -ErrorId 'ExportGpoFirewallProfilesFailed' `
                -TargetObject $XmlPath
    return
}
