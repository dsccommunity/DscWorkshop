<#
.SYNOPSIS
    Compares two YAML files for duplicate and conflicting registry entries.

.DESCRIPTION
    Analyzes two YAML configuration files containing registry settings and identifies:
    - Duplicate entries (same key/value name with same data)
    - Conflicting entries (same key/value name with different data)

    Useful for identifying overlaps between different GPO extraction outputs.

.PARAMETER FilePath1
    Path to the first YAML file to compare.

.PARAMETER FilePath2
    Path to the second YAML file to compare.

.PARAMETER ShowDuplicates
    If specified, displays the list of duplicate entries.

.PARAMETER ShowConflicts
    If specified, displays detailed information about conflicting entries.

.EXAMPLE
    .\Compare-YamlFiles.ps1 -FilePath1 ".\File1.yml" -FilePath2 ".\File2.yml"
    Compares two YAML files and shows summary statistics.

.EXAMPLE
    .\Compare-YamlFiles.ps1 -FilePath1 ".\File1.yml" -FilePath2 ".\File2.yml" -ShowConflicts
    Compares files and shows detailed conflict information.

.NOTES
    This script searches for registry entries in the format:
    - Key: HKEY_...
      ValueName: ...
      ValueData: ...
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
    [string]$FilePath1,

    [Parameter(Mandatory = $true, Position = 1)]
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
    [string]$FilePath2,

    [Parameter(Mandatory = $false)]
    [switch]$ShowDuplicates,

    [Parameter(Mandatory = $false)]
    [switch]$ShowConflicts
)

function Get-RegistryEntries
{
    param([string]$Content)

    $pattern = '(?ms)^\s*-?\s*Key:\s*(HKEY_[^\r\n]+)\r?\n\s+ValueName:\s*[''"]?([^\r\n''"]+)[''"]?\r?\n\s+ValueData:\s*[''"]?([^\r\n''"]+)[''"]?'
    $matches = [regex]::Matches($Content, $pattern)

    $entries = @{}
    foreach ($match in $matches)
    {
        $key = $match.Groups[1].Value.Trim()
        $valueName = $match.Groups[2].Value.Trim()
        $valueData = $match.Groups[3].Value.Trim()
        $fullPath = "$key\$valueName"
        $entries[$fullPath] = $valueData
    }

    return $entries
}

try
{
    Write-Verbose 'Loading YAML files...'
    $content1 = Get-Content -Path $FilePath1 -Raw -ErrorAction Stop
    $content2 = Get-Content -Path $FilePath2 -Raw -ErrorAction Stop

    Write-Verbose 'Parsing registry entries...'
    $entries1 = Get-RegistryEntries -Content $content1
    $entries2 = Get-RegistryEntries -Content $content2

    if ($entries1.Count -eq 0 -or $entries2.Count -eq 0)
    {
        Write-Warning 'One or both files contain no registry entries.'
        exit 0
    }

    Write-Verbose 'Comparing entries...'
    $duplicates = [System.Collections.ArrayList]::new()
    $conflicts = [System.Collections.ArrayList]::new()

    foreach ($key in $entries1.Keys)
    {
        if ($entries2.ContainsKey($key))
        {
            if ($entries1[$key] -eq $entries2[$key])
            {
                [void]$duplicates.Add([PSCustomObject]@{
                        Path  = $key
                        Value = $entries1[$key]
                    })
            }
            else
            {
                [void]$conflicts.Add([PSCustomObject]@{
                        Path       = $key
                        File1Value = $entries1[$key]
                        File2Value = $entries2[$key]
                    })
            }
        }
    }

    # Display results
    Write-Output ''
    Write-Output '========================================='
    Write-Output 'YAML FILES COMPARISON'
    Write-Output '========================================='
    Write-Output "File 1: $(Split-Path -Leaf $FilePath1) ($($entries1.Count) entries)"
    Write-Output "File 2: $(Split-Path -Leaf $FilePath2) ($($entries2.Count) entries)"
    Write-Output ''
    Write-Output '----------------------------------------'
    Write-Output 'ANALYSIS RESULTS'
    Write-Output '----------------------------------------'
    Write-Output "Duplicate entries: $($duplicates.Count) (same key/value/data in both files)"
    Write-Output "Conflicting entries: $($conflicts.Count) (same key/value but different data)"
    Write-Output ''

    if ($duplicates.Count -gt 0)
    {
        Write-Output '----------------------------------------'
        Write-Output 'DUPLICATES'
        Write-Output '----------------------------------------'

        if ($ShowDuplicates)
        {
            $duplicates | Format-Table -Property Path, Value -Wrap
        }
        else
        {
            Write-Output "Found $($duplicates.Count) duplicate entries."
            Write-Output 'Use -ShowDuplicates to display them.'
        }
        Write-Output ''
    }

    if ($conflicts.Count -gt 0)
    {
        Write-Output '----------------------------------------'
        Write-Output 'CONFLICTS'
        Write-Output '----------------------------------------'

        if ($ShowConflicts)
        {
            $conflicts | Format-Table -Property Path, File1Value, File2Value -Wrap -AutoSize
        }
        else
        {
            Write-Output "Found $($conflicts.Count) conflicting entries."
            Write-Output 'Use -ShowConflicts to display them.'
        }
        Write-Output ''
        Write-Warning '⚠️  Conflicts detected! Manual review required.'
    }

    # Summary
    Write-Output '========================================='
    Write-Output 'SUMMARY'
    Write-Output '========================================='

    if ($duplicates.Count -gt 0 -and $conflicts.Count -eq 0)
    {
        Write-Output '✅ Duplicates found, but no conflicts.'
        Write-Output '   Consider consolidating duplicate entries.'
        exit 0
    }
    elseif ($conflicts.Count -gt 0)
    {
        Write-Output '❌ Conflicts detected!'
        Write-Output '   Review conflicting entries and resolve manually.'
        exit 1
    }
    else
    {
        Write-Output '✅ No duplicates or conflicts found!'
        exit 0
    }
}
catch
{
    Write-Error "Failed to compare YAML files: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
