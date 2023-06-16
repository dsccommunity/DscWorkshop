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
task build_guestconfiguration_packages_from_MOF -if ($PSVersionTable.PSEdition -eq 'Core') {
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
    $mofFiles = Get-ChildItem -Path $mofPath -Filter '*.mof' -Recurse |
        Where-Object Name -NotLike ReferenceConfiguration*

    $moduleVersion = '2.0.0'

    foreach ($mofFile in $mofFiles)
    {
        $GCPackageName = $mofFile.BaseName
        Write-Build DarkGray "Package Name '$GCPackageName' with Configuration '$MOFFile', OutputDirectory $OutputDirectory, GCPackagesOutputPath '$GCPackagesOutputPath'."
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

task publish_guestconfiguration_packages -if (
    $PSVersionTable.PSEdition -eq 'Core' -and $env:azureClientSecret
) {
    $subscriptionId = $datum.Global.Azure.SubscriptionId
    $tenantId = $datum.Global.Azure.TenantId
    $resourceGroupName = $datum.Global.Azure.ResourceGroupName
    $storageAccountName = $datum.Global.Azure.StorageAccountName

    Update-AzConfig -DisplayBreakingChangeWarning $false

    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $env:azureClientId, (ConvertTo-SecureString -String $env:azureClientSecret -AsPlainText -Force)
    Connect-AzAccount -Credential $Credential -Tenant $tenantId -ServicePrincipal -SubscriptionId $subscriptionId | Out-Null

    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName
    $guestConfigurationContainerName = 'guestconfiguration'

    if (-not (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue))
    {
        $param = @{
            ResourceGroupName = $resourceGroupName
            Name              = $storageAccountName
            Location          = $resourceGroup.Location
            SkuName           = 'Standard_LRS'
            Kind              = 'StorageV2'
        }

        New-AzStorageAccount @param | Out-Null
    }

    $storageAccountKeys = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName
    $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKeys[0].Value
    if (-not (Get-AzStorageContainer -Context $storageContext -Name guestconfiguration -ErrorAction SilentlyContinue))
    {
        New-AzStorageContainer -Context $storageContext -Name guestconfiguration -Permission Blob | Out-Null
    }

    $moduleVersion = '2.0.0'

    $managedIdentity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name GCLab1_Remediation

    $gpPackages = Get-ChildItem -Path $OutputDirectory\$GCPackagesOutputPath -Filter '*.zip' -Recurse
    foreach ($gpPackage in $gpPackages)
    {
        $policyName = $gpPackage.BaseName.Split('_')[0]

        $param = @{
            Container = $guestConfigurationContainerName
            File      = $gpPackage.FullName
            Blob      = $gpPackage.Name
            Context   = $storageContext
            Force     = $true
        }
        Set-AzStorageBlobContent @param

        $param = @{
            Context    = $storageContext
            FullUri    = $true
            Container  = $guestConfigurationContainerName
            Blob       = $gpPackage.Name
            Permission = 'rwd'
        }
        $contentUri = New-AzStorageBlobSASToken @param

        $params = @{
            PolicyId      = New-Guid
            ContentUri    = $contentUri
            DisplayName   = $policyName
            Description   = 'none'
            Path          = "$OutputDirectory\$GCPoliciesPath"
            Platform      = 'Windows'
            PolicyVersion = $moduleVersion
            Mode          = 'ApplyAndAutoCorrect'
            Verbose       = $true
        }

        $policy = New-GuestConfigurationPolicy @params

        try
        {
            $policyDefinition = New-AzPolicyDefinition -Name $policyName -Policy $Policy.Path -ErrorAction Stop
        }
        catch
        {
            if ($_.Exception.HttpStatus -eq 'Forbidden')
            {
                Write-Error -Message "You do not have permission to create a Guest Configuration Policy. Please ensure you have the correct permissions, for example be a 'Resource Policy Contributor' on the Azure Subscription." -Exception $_.Exception
            }
            else
            {
                Write-Error -ErrorRecord $_
            }
            continue
        }

        $vm = Get-AzVM -Name $policyName -ResourceGroupName $resourceGroupName

        $param = @{
            Name             = $policyName
            DisplayName      = $policyDefinition.Properties.DisplayName
            Scope            = $vm.Id
            PolicyDefinition = $policyDefinition
            Location         = $datum.Global.Azure.LocationName
            IdentityType     = 'UserAssigned'
            IdentityId       = $managedIdentity.Id
        }
        $assignment = New-AzPolicyAssignment @param -WarningAction SilentlyContinue

        $param = @{
            Name                  = "$($policyName)Remediation"
            PolicyAssignmentId    = $assignment.PolicyAssignmentId
            Scope                 = $vm.Id
            ResourceDiscoveryMode = 'ReEvaluateCompliance'
        }
        Start-AzPolicyRemediation @param

    }

}
