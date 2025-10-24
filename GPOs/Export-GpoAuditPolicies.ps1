<#
.SYNOPSIS
    Export Audit Policy settings from GPO XML export.

.DESCRIPTION
    This script exports Advanced Audit Policy settings (AuditSetting elements) from a GPO XML
    export and converts them to DSC-ready YAML format. Note: This generates registry-based format,
    but using AuditPolicyDsc module is recommended for better management.
    Supports both Get-GPOReport and RSOP XML formats.

.PARAMETER XmlPath
    Path to the GPO XML file to process.

.PARAMETER OutputPath
    Path where the YAML output file will be created. If not specified, uses the XML filename with
    '-AuditPolicy.yml' suffix.

.PARAMETER Force
    Overwrite the output file if it already exists.

.EXAMPLE
    .\Export-GpoAuditPolicies.ps1 -XmlPath ".\MyGPO.xml"

.EXAMPLE
    .\Export-GpoAuditPolicies.ps1 -XmlPath ".\MyGPO.xml" -OutputPath ".\CustomOutput.yml" -Force

.NOTES
    Author: DSC Workshop GPO Migration Tool
    Version: 2.0
    Requires: PowerShell 5.1 or higher
    Recommendation: Use AuditPolicyDsc module instead of direct registry manipulation

.INPUTS
    XmlPath - Path to GPO XML file (Get-GPOReport or RSOP format).
    OutputPath - Path for YAML output file.
    Force - Switch to overwrite existing output file.

.OUTPUTS
    System.String - Path to the created YAML file containing registry-format audit policy settings.
    Note: The script writes audit policy content in registry format; using AuditPolicyDsc module is recommended for better audit policy management.
#>

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
        $OutputPath = Join-Path $PSScriptRoot "$xmlBaseName-AuditPolicy.yml"
    }

    # Check if output file exists
    if ((Test-Path $OutputPath) -and -not $Force)
    {
        throw "Output file already exists: $OutputPath. Use -Force to overwrite."
    }

    Write-Verbose "Reading XML file: $XmlPath"
    [xml]$xml = Get-Content $XmlPath -Raw -ErrorAction Stop

    # Support both GPO format (Get-GPOReport) and RSOP format
    Write-Verbose 'Detecting XML format...'
    $rootElement = if ($xml.GPO)
    {
        Write-Verbose 'Detected GPO format (Get-GPOReport)'
        $xml.GPO
    }
    elseif ($xml.Rsop)
    {
        Write-Verbose 'Detected RSOP format'
        $xml.Rsop
    }
    else
    {
        throw 'Unknown XML format. Expected GPO or Rsop root element.'
    }

    # Get all AuditSetting elements (namespace-agnostic)
    Write-Verbose 'Extracting Audit Policy settings...'
    $auditSettings = $rootElement.SelectNodes("//*[local-name()='AuditSetting']")

    if (-not $auditSettings -or $auditSettings.Count -eq 0)
    {
        throw 'No Audit Policy settings found in XML file.'
    }

    Write-Verbose "Found $($auditSettings.Count) audit settings"

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Advanced Audit Policy Settings (q3:AuditSettings)')
    [void]$sb.AppendLine('# Extracted from: Win11-24H2-MSFT-BaselineTest on Win11-24H2-MSFT-BaselineTest.xml')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# NOTE: Advanced Audit Policy settings are stored in the Security Event Log registry')
    [void]$sb.AppendLine('#       but are best managed through auditpol.exe or the AuditPolicyDsc resource.')
    [void]$sb.AppendLine('#       The registry path below is where Windows stores these settings.')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# SettingValue meanings:')
    [void]$sb.AppendLine('#   0 = No Auditing')
    [void]$sb.AppendLine('#   1 = Success')
    [void]$sb.AppendLine('#   2 = Failure')
    [void]$sb.AppendLine('#   3 = Success and Failure')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('RegistryValues:')
    [void]$sb.AppendLine('  Values:')

    $count = 0
    foreach ($setting in $auditSettings)
    {
        if (-not $setting.SubcategoryGuid)
        {
            continue
        }

        $subcategoryName = $setting.SubcategoryName
        $subcategoryGuid = $setting.SubcategoryGuid
        $settingValue = [int]$setting.SettingValue

        # Advanced Audit Policy settings are stored in the registry under the audit settings path
        # Reference: https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/advanced-security-auditing
        $regPath = 'System\CurrentControlSet\Control\Lsa\Audit'

        # The value name is the GUID without braces
        $guidClean = $subcategoryGuid -replace '[{}]', ''

        # Determine audit type based on value
        $auditType = switch ($settingValue)
        {
            0
            {
                'No Auditing'
            }
            1
            {
                'Success'
            }
            2
            {
                'Failure'
            }
            3
            {
                'Success and Failure'
            }
            default
            {
                "Unknown ($settingValue)"
            }
        }

        [void]$sb.AppendLine("    # $subcategoryName")
        [void]$sb.AppendLine("    # Subcategory GUID: $subcategoryGuid")
        [void]$sb.AppendLine("    # Audit Type: $auditType")
        [void]$sb.AppendLine("    - Key: HKEY_LOCAL_MACHINE\$regPath")
        [void]$sb.AppendLine("      ValueName: $guidClean")
        [void]$sb.AppendLine("      ValueData: $settingValue")
        [void]$sb.AppendLine('      ValueType: Dword')
        [void]$sb.AppendLine('      Ensure: Present')
        [void]$sb.AppendLine('      Force: true')
        $count++
    }

    # Add important notes
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('# ==============================================================================')
    [void]$sb.AppendLine('# IMPORTANT NOTES:')
    [void]$sb.AppendLine('# ==============================================================================')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# 1. RECOMMENDED APPROACH:')
    [void]$sb.AppendLine('#    Instead of managing these registry values directly, use the AuditPolicyDsc')
    [void]$sb.AppendLine('#    resource which provides a cleaner and more reliable interface:')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('#    Install-Module AuditPolicyDsc -Scope AllUsers')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('#    Example configuration:')
    [void]$sb.AppendLine('#    AuditPolicySubcategory SecuritySystemExtension')
    [void]$sb.AppendLine('#    {')
    [void]$sb.AppendLine("#        Name      = ''Security System Extension''")
    [void]$sb.AppendLine("#        AuditFlag = ''Success''")
    [void]$sb.AppendLine("#        Ensure    = ''Present''")
    [void]$sb.AppendLine('#    }')
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# 2. ALTERNATIVE: Use auditpol.exe commands')
    [void]$sb.AppendLine("#    auditpol /set /subcategory:''Security System Extension'' /success:enable")
    [void]$sb.AppendLine('#')
    [void]$sb.AppendLine('# 3. The registry values above are for reference and direct manipulation.')
    [void]$sb.AppendLine('#    Windows manages audit policy through a special mechanism that updates')
    [void]$sb.AppendLine('#    the registry but also maintains internal audit settings.')

    # Write output with ShouldProcess support
    $content = $sb.ToString()

    # Determine the action description for ShouldProcess
    $target = $OutputPath
    $action = if (Test-Path $OutputPath)
    {
        'Overwrite audit policy export file'
    }
    else
    {
        'Create audit policy export file'
    }

    # When -Force is specified, skip confirmation; otherwise use ShouldProcess
    if ($Force -or $PSCmdlet.ShouldProcess($target, $action))
    {
        $content | Out-File -FilePath $OutputPath -Encoding utf8 -NoNewline

        Write-Output ''
        Write-Output '✅ Audit Policy settings exported successfully!'
        Write-Output "   Settings exported: $count"
        Write-Output "   Output: $OutputPath"
        Write-Output ''
        Write-Output 'Audit policies exported:'
        $auditSettings | Where-Object { $_.SubcategoryGuid } | ForEach-Object {
            $val = switch ([int]$_.SettingValue)
            {
                0
                {
                    'No Audit'
                }
                1
                {
                    'Success'
                }
                2
                {
                    'Failure'
                }
                3
                {
                    'Success+Failure'
                }
            }
            Write-Output "  - $($_.SubcategoryName): $val"
        }
        Write-Output ''
    }
    else
    {
        Write-Verbose 'Operation cancelled by user.'
    }

    exit 0
}
catch
{
    Write-Error "Failed to export audit policies: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
