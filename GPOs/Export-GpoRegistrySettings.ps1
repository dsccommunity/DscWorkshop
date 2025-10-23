<#
.SYNOPSIS
    Exports registry settings from a GPO XML export (RegistrySetting elements).

.DESCRIPTION
    Parses RegistrySetting elements from a Group Policy Object XML export and generates
    a YAML configuration file with registry keys and values for DSC xRegistry resource.
    Supports both Get-GPOReport and RSOP XML formats.

    RegistrySetting entries are direct registry operations (not ADMX-based policies).
    They include both registry keys (Ensure = Present) and registry values.

.PARAMETER XmlPath
    Path to the GPO XML export file to process.

.PARAMETER OutputPath
    Path where the YAML file will be created. If not specified, generates a name based on
    the input filename with '-RegistrySettings.yml' suffix.

.PARAMETER Force
    Overwrites the output file if it already exists.

.EXAMPLE
    .\Export-GpoRegistrySettings.ps1 -XmlPath ".\MyGPO.xml"
    Exports registry settings and creates MyGPO-RegistrySettings.yml

.EXAMPLE
    .\Export-GpoRegistrySettings.ps1 -XmlPath ".\MyGPO.xml" -OutputPath ".\CustomOutput.yml" -Force
    Exports to a custom output file, overwriting if it exists.

.NOTES
    This script exports RegistrySetting elements which are different from Policy elements
    (Administrative Templates). These are direct registry writes vs. ADMX-based policies.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({
            if (-not (Test-Path $_))
            {
                throw "XML file not found: $_"
            }
            if ($_ -notmatch '\.xml$')
            {
                throw "File must have .xml extension: $_"
            }
            $true
        })]
    [string]$XmlPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

try
{
    Write-Verbose "Loading XML file: $XmlPath"
    [xml]$xml = Get-Content -Path $XmlPath -Raw -ErrorAction Stop

    # Generate output path if not specified
    if (-not $OutputPath)
    {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($XmlPath)
        $directory = [System.IO.Path]::GetDirectoryName($XmlPath)
        $OutputPath = Join-Path -Path $directory -ChildPath "$baseName-RegistrySettings.yml"
        Write-Verbose "Generated output path: $OutputPath"
    }

    # Check if output file exists
    if ((Test-Path $OutputPath) -and -not $Force)
    {
        Write-Error "Output file already exists: $OutputPath. Use -Force to overwrite."
        exit 1
    }

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

    # Find Registry extension
    Write-Verbose 'Searching for Registry extension data'
    # Handle both GPO format ($_.Name is string) and RSOP format ($_.Name.'#text')
    $registryExtension = $extensionDataCollection |
        Where-Object { ($_.Name -eq 'Registry') -or ($_.Name.'#text' -eq 'Registry') }

    if (-not $registryExtension)
    {
        Write-Error 'No Registry extension found in XML file'
        exit 1
    }

    # Get RegistrySetting elements (namespace-agnostic)
    $registrySettings = $registryExtension.Extension.SelectNodes("*[local-name()='RegistrySetting']")
    Write-Verbose "Found $($registrySettings.Count) RegistrySetting entries"

    # Build YAML
    $yaml = [System.Text.StringBuilder]::new()
    [void]$yaml.AppendLine('# Registry Settings extracted from GPO')
    [void]$yaml.AppendLine("# Source: $([System.IO.Path]::GetFileName($XmlPath))")
    [void]$yaml.AppendLine("# Exported: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$yaml.AppendLine("# Total settings: $($registrySettings.Count)")
    [void]$yaml.AppendLine()
    [void]$yaml.AppendLine('RegistryValues:')

    $count = 0
    foreach ($setting in $registrySettings)
    {
        $keyPath = $setting.KeyPath

        # Skip if no key path
        if (-not $keyPath)
        {
            continue
        }

        # Determine registry hive
        $hive = if ($keyPath -match '^Software\\')
        {
            'HKLM'
        }
        elseif ($keyPath -match '^MACHINE\\')
        {
            'HKLM'
            $keyPath = $keyPath -replace '^MACHINE\\', ''
        }
        else
        {
            'HKLM'
        }

        # Check if this is a key-only entry (no Value element) or a value entry
        if (-not $setting.Value)
        {
            # Key-only entry - ensure the key exists
            $count++
            $safeName = "RegistryKey_$($count.ToString('000'))"

            [void]$yaml.AppendLine("  ${safeName}:")
            [void]$yaml.AppendLine("    Key: '$hive\$keyPath'")
            [void]$yaml.AppendLine('    Ensure: Present')
            [void]$yaml.AppendLine("    ValueName: ''")
            [void]$yaml.AppendLine()
        }
        else
        {
            # Value entry - has Name and data
            $valueName = $setting.Value.Name

            # Determine value data and type
            $valueData = $null
            $valueType = 'String'

            if ($setting.Value.Number)
            {
                $valueData = $setting.Value.Number
                $valueType = 'Dword'
            }
            elseif ($setting.Value.String)
            {
                $valueData = $setting.Value.String
                $valueType = 'String'
            }
            elseif ($setting.Value.Delete)
            {
                # This is a delete operation
                $count++
                $safeName = "RegistryValue_Delete_$($count.ToString('000'))"

                [void]$yaml.AppendLine("  ${safeName}:")
                [void]$yaml.AppendLine("    Key: '$hive\$keyPath'")
                [void]$yaml.AppendLine("    ValueName: '$valueName'")
                [void]$yaml.AppendLine('    Ensure: Absent')
                [void]$yaml.AppendLine()
                continue
            }

            if ($null -ne $valueData)
            {
                $count++
                $safeName = "RegistryValue_$($count.ToString('000'))"

                [void]$yaml.AppendLine("  ${safeName}:")
                [void]$yaml.AppendLine("    Key: '$hive\$keyPath'")
                [void]$yaml.AppendLine("    ValueName: '$valueName'")

                if ($valueType -eq 'Dword')
                {
                    [void]$yaml.AppendLine("    ValueData: $valueData")
                }
                else
                {
                    [void]$yaml.AppendLine("    ValueData: '$valueData'")
                }

                [void]$yaml.AppendLine("    ValueType: $valueType")
                [void]$yaml.AppendLine('    Ensure: Present')
                [void]$yaml.AppendLine()
            }
        }
    }

    # Write output file
    $yaml.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8 -ErrorAction Stop

    Write-Output "`n✅ Registry Settings exported successfully!"
    Write-Output "   Settings exported: $count"
    Write-Output "   Output: $OutputPath"
    exit 0
}
catch
{
    Write-Error "Error during export: $_"
    exit 1
}
