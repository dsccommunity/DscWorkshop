<#
.SYNOPSIS
    Exports System Services configuration from a GPO XML export.

.DESCRIPTION
    Parses SystemServices elements from a Group Policy Object XML export and generates
    a YAML configuration file for DSC Service resource.
    Supports both Get-GPOReport and RSOP XML formats.

    System Services settings control the startup mode and security of Windows services.

.PARAMETER XmlPath
    Path to the GPO XML export file to process.

.PARAMETER OutputPath
    Path where the YAML file will be created. If not specified, generates a name based on
    the input filename with '-SystemServices.yml' suffix.

.PARAMETER Force
    Overwrites the output file if it already exists.

.EXAMPLE
    .\Export-GpoSystemServices.ps1 -XmlPath ".\MyGPO.xml"
    Exports system services and creates MyGPO-SystemServices.yml

.EXAMPLE
    .\Export-GpoSystemServices.ps1 -XmlPath ".\MyGPO.xml" -OutputPath ".\CustomOutput.yml" -Force
    Exports to a custom output file, overwriting if it exists.

.INPUTS
    None

.OUTPUTS
    String
    Path to created YAML configuration file describing exported System Services settings

.NOTES
    System Services are managed via Service Control Manager (SCM).
    Use PSDscResources Service resource or similar.
#>

[OutputType([System.String])]
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
        $OutputPath = Join-Path -Path $directory -ChildPath "$baseName-SystemServices.yml"
        Write-Verbose "Generated output path: $OutputPath"
    }

    # Check if output file exists
    if ((Test-Path $OutputPath) -and -not $Force)
    {
        Write-Error -Message "Output file already exists: $OutputPath. Use -Force to overwrite." `
                    -Category ResourceExists `
                    -ErrorId 'OutputFileExists' `
                    -TargetObject $OutputPath
        return
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

    # Find Security extension(s)
    Write-Verbose 'Searching for Security extension data'
    # Handle both GPO format ($_.Name is string) and RSOP format ($_.Name.'#text')
    $securityExtensions = @(
        $extensionDataCollection | Where-Object {
            ($_.Name -eq 'Security') -or ($_.Name.'#text' -eq 'Security')
        }
    )

    if ($securityExtensions.Count -eq 0)
    {
        Write-Error -Message 'No Security extension found in XML file' -Category InvalidData
        return 1
    }

    Write-Verbose "Found $($securityExtensions.Count) Security extension(s)"

    # Get SystemServices elements (namespace-agnostic) from all Security extensions
    $services = @()
    foreach ($ext in $securityExtensions)
    {
        $nodes = $ext.Extension.SelectNodes("*[local-name()='SystemServices']")
        if ($nodes)
        {
            $services += @($nodes)
        }
    }

    Write-Verbose "Found $($services.Count) SystemServices entries across all Security extensions"

    if ($services.Count -eq 0)
    {
        Write-Warning 'No system services found in GPO'
        return
    }

    # Build YAML
    $yaml = [System.Text.StringBuilder]::new()
    [void]$yaml.AppendLine('# System Services configuration extracted from GPO')
    [void]$yaml.AppendLine("# Source: $([System.IO.Path]::GetFileName($XmlPath))")
    [void]$yaml.AppendLine("# Exported: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$yaml.AppendLine("# Total services: $($services.Count)")
    [void]$yaml.AppendLine()
    [void]$yaml.AppendLine('Services:')

    $count = 0
    foreach ($service in $services)
    {
        $serviceName = $service.Name
        $startupMode = $service.StartupMode

        # Skip if no service name
        if (-not $serviceName)
        {
            continue
        }

        $count++

        # Map startup mode to DSC values
        $startType = switch ($startupMode)
        {
            'Automatic'
            {
                'Automatic'
            }
            'Manual'
            {
                'Manual'
            }
            'Disabled'
            {
                'Disabled'
            }
            default
            {
                $startupMode
            }
        }

        [void]$yaml.AppendLine("  ${serviceName}:")
        [void]$yaml.AppendLine("    Name: $serviceName")
        [void]$yaml.AppendLine("    StartupType: $startType")
        [void]$yaml.AppendLine('    State: Ignore  # GPO only sets startup type, not running state')

        # Include SDDL if present
        $sddl = $service.SecurityDescriptor.SDDL.'#text'
        if ($sddl)
        {
            [void]$yaml.AppendLine("    # Security Descriptor: $sddl")
        }

        [void]$yaml.AppendLine()
    }

    # Write output file
    $yaml.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8 -ErrorAction Stop

    Write-Output "`n✅ System Services exported successfully!"
    Write-Output "   Services exported: $count"
    Write-Output "   Output: $OutputPath"

    # Display summary
    Write-Output "`nExported Services:"
    foreach ($service in $services)
    {
        Write-Output "  - $($service.Name): $($service.StartupMode)"
    }

    return $OutputPath
}
catch
{
    Write-Error -Message "Failed to export system services from GPO XML" `
                -Exception $_.Exception `
                -Category InvalidOperation `
                -ErrorId 'ExportGpoSystemServicesFailed' `
                -TargetObject $XmlPath
    return
}
