<#
.SYNOPSIS
    Exports User Rights Assignments from a GPO XML export.

.DESCRIPTION
    Parses UserRightsAssignment elements from a Group Policy Object XML export and generates
    a YAML configuration file for DSC UserRightsAssignment resource from SecurityPolicyDsc.
    Supports both Get-GPOReport and RSOP XML formats.

    User Rights Assignments control which users/groups have specific system privileges.

.PARAMETER XmlPath
    Path to the GPO XML export file to process.

.PARAMETER OutputPath
    Path where the YAML file will be created. If not specified, generates a name based on
    the input filename with '-UserRightsAssignments.yml' suffix.

.PARAMETER Force
    Overwrites the output file if it already exists.

.EXAMPLE
    .\Export-GpoUserRightsAssignments.ps1 -XmlPath ".\MyGPO.xml"
    Exports user rights and creates MyGPO-UserRightsAssignments.yml

.EXAMPLE
    .\Export-GpoUserRightsAssignments.ps1 -XmlPath ".\MyGPO.xml" -OutputPath ".\CustomOutput.yml" -Force
    Exports to a custom output file, overwriting if it exists.

.NOTES
    User Rights Assignments are NOT stored in the registry. They are managed by the
    Local Security Authority (LSA) database. Use SecurityPolicyDsc module.
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
        $OutputPath = Join-Path -Path $directory -ChildPath "$baseName-UserRightsAssignments.yml"
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

    # Find Security extension
    Write-Verbose 'Searching for Security extension data'
    # Handle both GPO format ($_.Name is string) and RSOP format ($_.Name.'#text')
    $securityExtension = $extensionDataCollection |
        Where-Object { ($_.Name -eq 'Security') -or ($_.Name.'#text' -eq 'Security') }

    if (-not $securityExtension)
    {
        Write-Error 'No Security extension found in XML file'
        exit 1
    }

    # Get UserRightsAssignment elements (namespace-agnostic)
    $userRights = $securityExtension.Extension.SelectNodes("*[local-name()='UserRightsAssignment']")
    Write-Verbose "Found $($userRights.Count) UserRightsAssignment entries"

    # Build YAML
    $yaml = [System.Text.StringBuilder]::new()
    [void]$yaml.AppendLine('# User Rights Assignments extracted from GPO')
    [void]$yaml.AppendLine("# Source: $([System.IO.Path]::GetFileName($XmlPath))")
    [void]$yaml.AppendLine("# Exported: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$yaml.AppendLine("# Total rights: $($userRights.Count)")
    [void]$yaml.AppendLine()
    [void]$yaml.AppendLine('UserRightsAssignments:')

    $count = 0
    foreach ($right in $userRights)
    {
        $policyName = $right.Name

        # Skip if no policy name
        if (-not $policyName)
        {
            continue
        }

        $count++

        # Create safe YAML key from policy name
        $safeName = $policyName -replace '^Se', '' -replace 'Privilege$', '' -replace 'Right$', ''

        [void]$yaml.AppendLine("  ${safeName}:")
        [void]$yaml.AppendLine("    Policy: $policyName")

        # Extract members
        $members = @()
        foreach ($member in $right.Member)
        {
            $memberName = $member.Name.'#text'
            if ($memberName)
            {
                $members += $memberName
            }
        }

        if ($members.Count -gt 0)
        {
            [void]$yaml.AppendLine('    Identity:')
            foreach ($member in $members)
            {
                [void]$yaml.AppendLine("      - '$member'")
            }
        }
        else
        {
            # Empty assignment
            [void]$yaml.AppendLine('    Identity: []')
        }

        [void]$yaml.AppendLine()
    }

    # Write output file
    $yaml.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8 -ErrorAction Stop

    Write-Output "`n✅ User Rights Assignments exported successfully!"
    Write-Output "   Rights exported: $count"
    Write-Output "   Output: $OutputPath"

    # Display summary
    Write-Output "`nExported User Rights:"
    foreach ($right in $userRights)
    {
        Write-Output "  - $($right.Name)"
    }

    exit 0
}
catch
{
    Write-Error "Error during export: $_"
    exit 1
}
