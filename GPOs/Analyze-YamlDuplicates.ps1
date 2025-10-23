<#
.SYNOPSIS
    Analyzes a YAML file for duplicate registry entries.

.DESCRIPTION
    Scans a YAML configuration file containing registry settings and identifies
    duplicate entries based on registry key path and value name combinations.
    Useful for quality assurance of GPO extraction output.

.PARAMETER YamlFilePath
    Path to the YAML file to analyze.

.PARAMETER ShowDetails
    If specified, displays detailed information about each duplicate entry.

.EXAMPLE
    .\Analyze-YamlDuplicates.ps1 -YamlFilePath ".\MySettings.yml"
    Analyzes the specified YAML file for duplicate registry entries.

.EXAMPLE
    .\Analyze-YamlDuplicates.ps1 -YamlFilePath ".\MySettings.yml" -ShowDetails
    Analyzes and shows detailed information about duplicates.

.NOTES
    This script searches for patterns in the format:
    - Key: HKEY_...
      ValueName: ...
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({
            if (-not (Test-Path $_))
            {
                throw "File not found: $_"
            }
            if ($_ -notmatch '\.(yml|yaml)$')
            {
                throw "File must have .yml or .yaml extension: $_"
            }
            $true
        })]
    [string]$YamlFilePath,

    [Parameter(Mandatory = $false)]
    [switch]$ShowDetails
)

try
{
    Write-Verbose "Loading YAML file: $YamlFilePath"
    $content = Get-Content -Path $YamlFilePath -Raw -ErrorAction Stop

    # Pattern to match registry entries: Key and ValueName
    $pattern = '(?ms)^\s*-?\s*Key:\s*(HKEY_[^\r\n]+)\r?\n\s+ValueName:\s*[''"]?([^\r\n''"]+)[''"]?'
    $matches = [regex]::Matches($content, $pattern)

    if ($matches.Count -eq 0)
    {
        Write-Warning 'No registry entries found in the file.'
        exit 0
    }

    Write-Verbose "Found $($matches.Count) registry entries"

    # Track entries and duplicates
    $entries = @{}
    $duplicates = [System.Collections.ArrayList]::new()

    foreach ($match in $matches)
    {
        $key = $match.Groups[1].Value.Trim()
        $valueName = $match.Groups[2].Value.Trim()
        $fullPath = "$key\$valueName"

        if ($entries.ContainsKey($fullPath))
        {
            $entries[$fullPath]++
            [void]$duplicates.Add([PSCustomObject]@{
                    RegistryKey = $key
                    ValueName   = $valueName
                    FullPath    = $fullPath
                })
        }
        else
        {
            $entries[$fullPath] = 1
        }
    }

    # Display results
    Write-Output ''
    Write-Output '========================================='
    Write-Output 'YAML DUPLICATE ANALYSIS'
    Write-Output '========================================='
    Write-Output "File: $(Split-Path -Leaf $YamlFilePath)"
    Write-Output ''
    Write-Output "Total entries found: $($matches.Count)"
    Write-Output "Unique entries: $($entries.Count)"
    Write-Output "Duplicate entries: $($duplicates.Count)"
    Write-Output ''

    if ($duplicates.Count -gt 0)
    {
        Write-Output '----------------------------------------'
        Write-Output 'DUPLICATES DETECTED'
        Write-Output '----------------------------------------'

        if ($ShowDetails)
        {
            $duplicates | Format-Table -Property RegistryKey, ValueName -Wrap
        }
        else
        {
            $grouped = $duplicates | Group-Object FullPath | Sort-Object Count -Descending
            foreach ($group in $grouped)
            {
                Write-Output "  - $($group.Name) (appears $($group.Count + 1) times)"
            }
        }

        Write-Output ''
        Write-Warning '⚠️  Duplicates found! Consider removing duplicate entries.'
        exit 1
    }
    else
    {
        Write-Output '✅ No duplicates found!'
        Write-Output ''
        exit 0
    }
}
catch
{
    Write-Error "Failed to analyze YAML file: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
