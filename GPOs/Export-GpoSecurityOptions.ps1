<#
.SYNOPSIS
    Export Security Options registry settings from GPO XML export.

.DESCRIPTION
    This script exports Security Options (SecurityOptions element) from a GPO XML export
    and converts them to DSC-ready YAML format for use with the xRegistry resource.
    Supports both Get-GPOReport and RSOP XML formats.

.PARAMETER XmlPath
    Path to the GPO XML file to process.

.PARAMETER OutputPath
    Path where the YAML output file will be created. If not specified, uses the XML filename with
    '-SecurityOptions.yml' suffix.

.PARAMETER Force
    Overwrite the output file if it already exists.

.EXAMPLE
    .\Export-GpoSecurityOptions.ps1 -XmlPath ".\MyGPO.xml"

.EXAMPLE
    .\Export-GpoSecurityOptions.ps1 -XmlPath ".\MyGPO.xml" -OutputPath ".\CustomOutput.yml" -Force

.NOTES
    Author: DSC Workshop GPO Migration Tool
    Version: 2.0
    Requires: PowerShell 5.1 or higher

.INPUTS
    XmlPath - Path to GPO XML file (Get-GPOReport or RSOP format).
    OutputPath - Path for YAML output file.
    Force - Switch to overwrite existing output file.

.OUTPUTS
    System.String - Path to the created YAML file containing registry-format security options settings in DSC-ready YAML format for use with the xRegistry resource.
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
        $OutputPath = Join-Path $PSScriptRoot "$xmlBaseName-SecurityOptions.yml"
    }

    Write-Verbose "Reading XML file: $XmlPath"
    [xml]$xml = Get-Content $XmlPath -Raw -ErrorAction Stop

    # Support both GPO format (Get-GPOReport) and RSOP format
    Write-Verbose 'Detecting XML format...'
    $extensionDataCollection = if ($xml.GPO)
    {
        Write-Verbose 'Detected GPO format (Get-GPOReport)'
        $xml.GPO.Computer.ExtensionData
    }
    elseif ($xml.Rsop)
    {
        Write-Verbose 'Detected RSOP format'
        $xml.Rsop.ComputerResults.ExtensionData
    }
    else
    {
        throw 'Unknown XML format. Expected GPO or Rsop root element.'
    }

    # Get Security extension data (namespace-agnostic)
    Write-Verbose 'Extracting Security Options (SecurityOptions element)...'
    # Handle both GPO format ($_.Name is string) and RSOP format ($_.Name.'#text')
    $securityExts = @(
        $extensionDataCollection | Where-Object {
            ($_.Name -eq 'Security') -or ($_.Name.'#text' -eq 'Security')
        }
    )

    if ($securityExts.Count -eq 0)
    {
        throw 'No Security extension found in XML file. Ensure the XML is a valid GPO RSOP export.'
    }

    Write-Verbose "Found $($securityExts.Count) Security extension(s)"

    # Use SelectNodes with local-name() to be namespace-agnostic
    # Aggregate SecurityOptions from all Security extensions
    $securityOptions = @()
    foreach ($ext in $securityExts)
    {
        $nodes = $ext.Extension.SelectNodes("*[local-name()='SecurityOptions']/*[local-name()='Display']/..")
        if ($nodes)
        {
            $securityOptions += @($nodes)
        }
    }

    if ($securityOptions.Count -eq 0)
    {
        throw 'No Security Options found in XML file.'
    }

    Write-Verbose "Found $($securityOptions.Count) Security Options across all Security extensions"

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('RegistryValues:')
    [void]$sb.AppendLine('  Values:')

    $count = 0
    foreach ($setting in $securityOptions)
    {
        # KeyName contains the full registry path (e.g., MACHINE\System\CurrentControlSet\Control\Lsa\MSV1_0\NTLMMinServerSec)
        $keyName = $setting.KeyName
        if (-not $keyName)
        {
            continue
        }

        # Remove MACHINE\ prefix
        $keyName = $keyName -replace '^MACHINE\\', ''

        # Split into registry path and value name
        $lastBackslash = $keyName.LastIndexOf('\')
        if ($lastBackslash -eq -1)
        {
            continue
        }

        $regPath = $keyName.Substring(0, $lastBackslash)
        $valueName = $keyName.Substring($lastBackslash + 1)

        # Get the display name
        $settingName = $setting.Display.Name
        if (-not $settingName)
        {
            $settingName = $valueName
        }

        # Get the value - could be SettingNumber or SettingString
        $valueData = $null
        $valueType = 'Dword'

        if ($setting.SettingNumber)
        {
            $valueData = [int]$setting.SettingNumber
            $valueType = 'Dword'
        }
        elseif ($setting.SettingString)
        {
            $valueData = $setting.SettingString
            $valueType = 'String'
        }
        elseif ($setting.SettingBoolean)
        {
            $valueData = if ($setting.SettingBoolean -eq 'true')
            {
                1
            }
            else
            {
                0
            }
            $valueType = 'Dword'
        }

        if ($null -eq $valueData)
        {
            continue
        }

        [void]$sb.AppendLine("    # $settingName")
        [void]$sb.AppendLine("    - Key: HKEY_LOCAL_MACHINE\$regPath")
        [void]$sb.AppendLine("      ValueName: $valueName")
        [void]$sb.AppendLine("      ValueData: $valueData")
        [void]$sb.AppendLine("      ValueType: $valueType")
        [void]$sb.AppendLine('      Ensure: Present')
        [void]$sb.AppendLine('      Force: true')

        $count++
    }

    Write-Verbose "Found $count security option settings"

    # Write output with ShouldProcess support
    $content = $sb.ToString()

    # Determine the action description for ShouldProcess
    $target = $OutputPath
    $action = if (Test-Path $OutputPath)
    {
        'Overwrite security options export file'
    }
    else
    {
        'Create security options export file'
    }

    # When -Force is specified, skip confirmation; otherwise use ShouldProcess
    if ($Force -or $PSCmdlet.ShouldProcess($target, $action))
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
        Write-Output '✅ Security Options exported successfully!'
        Write-Output "   Settings exported: $count"
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
    Write-Error -Message "Failed to export security options from GPO XML" `
                -Exception $_.Exception `
                -Category InvalidOperation `
                -ErrorId 'ExportGpoSecurityOptionsFailed' `
                -TargetObject $XmlPath
    return
}
