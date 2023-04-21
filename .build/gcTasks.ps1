param
(
    [Parameter()]
    [System.String]
    $ProjectName = (property ProjectName ''),

    [Parameter()]
    [System.String]
    $SourcePath = (property SourcePath ''),

    [Parameter()]
    [System.String]
    $GCPackagesPath = (property GCPackagesPath 'GCPackages'),

    [Parameter()]
    [System.String]
    $GCPackagesOutputPath = (property GCPackagesOutputPath 'GCPackages'),

    [Parameter()]
    [System.String]
    $GCPoliciesPath = (property GCPoliciesPath 'GCPolicies'),

    [Parameter()]
    [System.String]
    $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

    [Parameter()]
    [System.String]
    $BuiltModuleSubdirectory = (property BuiltModuleSubdirectory ''),

    [Parameter()]
    [System.String]
    $BuildModuleOutput = (property BuildModuleOutput (Join-Path $OutputDirectory $BuiltModuleSubdirectory)),

    [Parameter()]
    [System.String]
    $ModuleVersion = (property ModuleVersion ''),

    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ })
)

# SYNOPSIS: Building the Azure Policy Guest Configuration Packages
task build_guestconfiguration_packages_from_MOF {
    # Get the vales for task variables, see https://github.com/gaelcolas/Sampler#task-variables.
    . Set-SamplerTaskVariable -AsNewBuild

    if (-not (Split-Path -IsAbsolute $GCPackagesPath))
    {
        $GCPackagesPath = Join-Path -Path $SourcePath -ChildPath $GCPackagesPath
    }

    if (-not (Split-Path -IsAbsolute $GCPoliciesPath))
    {
        $GCPoliciesPath = Join-Path -Path $SourcePath -ChildPath $GCPoliciesPath
    }

    "`tBuild Module Output  = $BuildModuleOutput"
    "`tGC Packages Path     = $GCPackagesPath"
    "`tGC Policies Path     = $GCPoliciesPath"
    "`t------------------------------------------------`r`n"

    $mofPath = Join-Path -Path $OutputDirectory -ChildPath $MofOutputFolder
    $mofFiles = Get-ChildItem -Path $mofPath -Filter '*.mof' -Recurse

    foreach ($mofFile in $mofFiles)
    {
        $moduleVersion = '2.0.0'

        Write-Verbose -Message "Package Name '$GCPackageName' with Configuration '$MOFFile', OutputDirectory $OutputDirectory, GCPackagesOutputPath '$GCPackagesOutputPath'."
        $GCPackageOutput = Get-SamplerAbsolutePath -Path $GCPackagesOutputPath -RelativeTo $OutputDirectory

        $NewGCPackageParams = @{
            Configuration = $mofFile.FullName
            Name          = $mofFile.BaseName
            Path          = $GCPackageOutput
            Force         = $true
            Version       = $ModuleVersion
            Type          = 'AuditAndSet'
        }

        foreach ($paramName in (Get-Command -Name 'New-GuestConfigurationPackage' -ErrorAction Stop).Parameters.Keys.Where({ $_ -in $newPackageExtraParams.Keys }))
        {
            Write-Verbose -Message "`t Testing for parameter '$paramName'."
            Write-Build DarkGray "`t`t Using configured parameter '$paramName' with value '$($newPackageExtraParams[$paramName])'."
            # Override the Parameters from the $GCPackageName.psd1
            $NewGCPackageParams[$paramName] = $newPackageExtraParams[$paramName]
        }

        $ZippedGCPackage = (& {
                New-GuestConfigurationPackage @NewGCPackageParams
            } 2>&1).Where{
            if ($_ -isnot [System.Management.Automation.ErrorRecord])
            {
                # Filter out the Error records from New-GuestConfigurationPackage
                $true
            }
            elseif ($_.Exception.Message -notmatch '^A second CIM class definition')
            {
                # Write non-terminating errors that are not "A second CIM class definition for .... was found..."
                $false
                Write-Error $_ -ErrorAction Continue
            }
            else
            {
                $false
            }
        }

        Write-Build DarkGray "`t Zips created, you may want to delete the unzipped folders under '$GCPackagesOutputPath'..."

        if ($ModuleVersion)
        {
            $GCPackageWithVersionZipName = ('{0}_{1}.zip' -f $GCPackageName, $ModuleVersion)
            $GCPackageOutputPath = Get-SamplerAbsolutePath -Path $GCPackagesOutputPath -RelativeTo $OutputDirectory
            $versionedGCPackageName = Join-Path -Path $GCPackageOutputPath -ChildPath $GCPackageWithVersionZipName
            Write-Build DarkGray "`t Renaming Zip as '$versionedGCPackageName'."
            $ZippedGCPackagePath = Move-Item -Path $ZippedGCPackage.Path -Destination $versionedGCPackageName -Force -PassThru
            $ZippedGCPackage = @{
                Name = $ZippedGCPackage.Name
                Path = $ZippedGCPackagePath.FullName
            }
        }

        Write-Build Green "`tZipped Guest Config Package: $($ZippedGCPackage.Path)"
    }
}

task gcpack clean, build, build_guestconfiguration_packages
