<#
.SYNOPSIS
    Orchestrates all GPO export scripts to process a GPO XML export.

.DESCRIPTION
    This master script runs all 7 export scripts in sequence to fully export
    settings from a Group Policy Object XML export. It processes:
    - Security Options (Export-GpoSecurityOptions.ps1)
    - Administrative Templates (Export-GpoAdministrativeTemplates.ps1)
    - Audit Policies (Export-GpoAuditPolicies.ps1)
    - Firewall Profiles (Export-GpoFirewallProfiles.ps1)
    - Registry Settings (Export-GpoRegistrySettings.ps1)
    - User Rights Assignments (Export-GpoUserRightsAssignments.ps1)
    - System Services (Export-GpoSystemServices.ps1)

.PARAMETER XmlPath
    Path to the GPO XML export file to process.

.PARAMETER OutputDirectory
    Directory where all YAML files will be created. If not specified, uses the same
    directory as the input XML file.

.PARAMETER Force
    Overwrites existing output files without prompting.

.PARAMETER Verbose
    Displays detailed progress information.

.EXAMPLE
    .\Export-GpoAllSettings.ps1 -XmlPath ".\MyGPO.xml"
    Exports all settings from MyGPO.xml to the same directory.

.EXAMPLE
    .\Export-GpoAllSettings.ps1 -XmlPath ".\MyGPO.xml" -OutputDirectory ".\output" -Force -Verbose
    Exports all settings to the output directory, overwriting existing files, with detailed logging.

.NOTES
    This script requires all 7 export scripts to be in the same directory:
    - Export-GpoSecurityOptions.ps1
    - Export-GpoAdministrativeTemplates.ps1
    - Export-GpoAuditPolicies.ps1
    - Export-GpoFirewallProfiles.ps1
    - Export-GpoRegistrySettings.ps1
    - Export-GpoUserRightsAssignments.ps1
    - Export-GpoSystemServices.ps1
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
    [string]$OutputDirectory,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try
{
    $startTime = Get-Date
    Write-Output '========================================='
    Write-Output 'GPO EXPORT ORCHESTRATOR'
    Write-Output '========================================='
    Write-Output "Started: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Output ''

    # Get absolute paths
    $XmlPath = Resolve-Path $XmlPath
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

    if ($OutputDirectory)
    {
        if (-not (Test-Path $OutputDirectory))
        {
            Write-Verbose "Creating output directory: $OutputDirectory"
            New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        }
        $OutputDirectory = Resolve-Path $OutputDirectory
    }
    else
    {
        $OutputDirectory = Split-Path -Parent $XmlPath
    }

    Write-Output "Input file: $XmlPath"
    Write-Output "Output directory: $OutputDirectory"
    Write-Output ''

    # Define export scripts
    $exportScripts = @(
        @{
            Name        = 'Security Options'
            Script      = 'Export-GpoSecurityOptions.ps1'
            Description = 'Registry-based security settings'
        },
        @{
            Name        = 'Administrative Templates'
            Script      = 'Export-GpoAdministrativeTemplates.ps1'
            Description = 'ADMX policy settings'
        },
        @{
            Name        = 'Audit Policies'
            Script      = 'Export-GpoAuditPolicies.ps1'
            Description = 'Advanced audit configuration'
        },
        @{
            Name        = 'Firewall Profiles'
            Script      = 'Export-GpoFirewallProfiles.ps1'
            Description = 'Windows Firewall profile settings'
        },
        @{
            Name        = 'Registry Settings'
            Script      = 'Export-GpoRegistrySettings.ps1'
            Description = 'Direct registry operations'
        },
        @{
            Name        = 'User Rights Assignments'
            Script      = 'Export-GpoUserRightsAssignments.ps1'
            Description = 'User rights and privileges'
        },
        @{
            Name        = 'System Services'
            Script      = 'Export-GpoSystemServices.ps1'
            Description = 'Service startup configuration'
        }
    )

    # Verify all scripts exist
    Write-Verbose 'Verifying export scripts...'
    $missingScripts = @()
    foreach ($script in $exportScripts)
    {
        $scriptPath = Join-Path -Path $scriptDirectory -ChildPath $script.Script
        if (-not (Test-Path $scriptPath))
        {
            $missingScripts += $script.Script
        }
    }

    if ($missingScripts.Count -gt 0)
    {
        Write-Error "Missing export scripts: $($missingScripts -join ', ')"
        exit 1
    }

    # Execute each export script
    $results = @()
    $successCount = 0
    $failureCount = 0

    foreach ($script in $exportScripts)
    {
        Write-Output '-------------------------------------------'
        Write-Output "Exporting: $($script.Name)"
        Write-Output "Description: $($script.Description)"
        Write-Output "Script: $($script.Script)"

        $scriptPath = Join-Path -Path $scriptDirectory -ChildPath $script.Script

        # Determine output path
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($XmlPath)
        $outputSuffix = switch ($script.Script)
        {
            'Export-GpoSecurityOptions.ps1'
            {
                '-SecurityOptions.yml'
            }
            'Export-GpoAdministrativeTemplates.ps1'
            {
                '-AdministrativeTemplates.yml'
            }
            'Export-GpoAuditPolicies.ps1'
            {
                '-AuditPolicy.yml'
            }
            'Export-GpoFirewallProfiles.ps1'
            {
                '-FirewallProfiles.yml'
            }
            'Export-GpoRegistrySettings.ps1'
            {
                '-RegistrySettings.yml'
            }
            'Export-GpoUserRightsAssignments.ps1'
            {
                '-UserRightsAssignments.yml'
            }
            'Export-GpoSystemServices.ps1'
            {
                '-SystemServices.yml'
            }
        }
        $outputPath = Join-Path -Path $OutputDirectory -ChildPath "$baseName$outputSuffix"

        try
        {
            Write-Verbose "Executing: $scriptPath"

            # Build parameter hashtable
            $params = @{
                XmlPath    = $XmlPath
                OutputPath = $outputPath
            }

            if ($Force)
            {
                $params['Force'] = $true
            }

            if ($VerbosePreference -eq 'Continue')
            {
                $params['Verbose'] = $true
            }

            # Execute script and capture output
            $scriptOutput = & $scriptPath @params 2>&1

            if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE)
            {
                Write-Output '✅ SUCCESS'
                $successCount++
                $results += @{
                    Name       = $script.Name
                    Status     = 'Success'
                    Output     = $scriptOutput
                    OutputFile = $outputPath
                }
            }
            else
            {
                Write-Output "❌ FAILED (Exit code: $LASTEXITCODE)"
                $failureCount++
                $results += @{
                    Name       = $script.Name
                    Status     = 'Failed'
                    Output     = $scriptOutput
                    OutputFile = $null
                }
            }

            # Display script output
            if ($scriptOutput)
            {
                $scriptOutput | ForEach-Object { Write-Output "   $_" }
            }
        }
        catch
        {
            Write-Output '❌ FAILED (Exception)'
            Write-Output "   Error: $_"
            $failureCount++
            $results += @{
                Name       = $script.Name
                Status     = 'Failed'
                Output     = $_.Exception.Message
                OutputFile = $null
            }
        }

        Write-Output ''
    }

    # Summary
    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Information '=========================================' -InformationAction Continue
    Write-Information 'EXPORT SUMMARY' -InformationAction Continue
    Write-Information '=========================================' -InformationAction Continue
    Write-Information "Completed: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -InformationAction Continue
    Write-Information "Duration: $($duration.ToString('mm\:ss'))" -InformationAction Continue
    Write-Information '' -InformationAction Continue
    Write-Information 'Results:' -InformationAction Continue
    Write-Information "  ✅ Successful: $successCount" -InformationAction Continue
    Write-Information "  ❌ Failed: $failureCount" -InformationAction Continue
    Write-Information "  📊 Total: $($exportScripts.Count)" -InformationAction Continue
    Write-Information '' -InformationAction Continue

    if ($successCount -gt 0)
    {
        Write-Information 'Generated Files:' -InformationAction Continue
        foreach ($result in $results | Where-Object { $_.Status -eq 'Success' })
        {
            if ($result.OutputFile -and (Test-Path $result.OutputFile))
            {
                $fileSize = (Get-Item $result.OutputFile).Length
                $fileSizeKB = [Math]::Round($fileSize / 1KB, 1)
                Write-Information "  📄 $([System.IO.Path]::GetFileName($result.OutputFile)) ($fileSizeKB KB)" -InformationAction Continue
            }
        }
        Write-Information '' -InformationAction Continue
    }

    if ($failureCount -gt 0)
    {
        Write-Information 'Failed Exports:' -InformationAction Continue
        foreach ($result in $results | Where-Object { $_.Status -eq 'Failed' })
        {
            Write-Information "  ⚠️  $($result.Name)" -InformationAction Continue
        }
        Write-Information '' -InformationAction Continue
        Write-Warning 'Some exports failed. Review the output above for details.'
        exit 1
    }

    Write-Information '✅ All exports completed successfully!' -InformationAction Continue
    Write-Information '=========================================' -InformationAction Continue
    exit 0
}
catch
{
    Write-Error "Fatal error during orchestration: $_"
    exit 1
}
