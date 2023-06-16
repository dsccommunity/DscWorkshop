$script:resourceHelperModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\Modules\DscResource.Common'

Import-Module -Name $script:resourceHelperModulePath

$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

<#
    .SYNOPSIS
        Gets the rights of the specified filesystem object for the specified identity.

    .PARAMETER Path
        The path to the item that should have permissions set.

    .PARAMETER Identity
        The identity to set permissions for.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Identity
    )

    Write-Verbose -Message (
        $script:localizedData.GetCurrentState -f $Identity, $Path
    )

    $result = @{
        Ensure       = 'Absent'
        Path         = $Path
        Identity     = $Identity
        Rights       = [System.String[]] @()
        IsActiveNode = $true
    }

    if (-not (Test-Path -Path $Path))
    {
        Write-Verbose -Message $script:localizedData.EvaluatingIfCluster

        $failoverClusterInstance = Get-CimInstance -Namespace 'root/MSCluster' -ClassName 'MSCluster_Cluster' -ErrorAction 'SilentlyContinue'

        if ($failoverClusterInstance)
        {
            Write-Verbose -Message (
                $script:localizedData.NodeIsClusterMember -f $env:COMPUTERNAME, $failoverClusterInstance.Name
            )

            $clusterPartition = Get-CimInstance -Namespace 'root/MSCluster' -ClassName 'MSCluster_ClusterDiskPartition' |
                Where-Object -FilterScript {
                    $currentPartition = $_

                    # The property MountPoints is an array of mount points, e.g. @('D:', 'E:').
                    $currentPartition.MountPoints | ForEach-Object -Process {
                        [regex]::Escape($Path) -match ('^{0}' -f $_)
                    }
                }

            if ($clusterPartition)
            {
                Write-Verbose -Message (
                    $script:localizedData.EvaluatingOwnerOfClusterDiskPartition -f @(
                        (Split-Path -Path $Path -Qualifier)
                        $env:COMPUTERNAME
                    )
                )

                # Get the possible owner nodes for the partition.
                [System.Array] $possibleOwners = $clusterPartition |
                    Get-CimAssociatedInstance -ResultClassName 'MSCluster_Resource' |
                        Get-CimAssociatedInstance -Association 'MSCluster_ResourceToPossibleOwner' |
                            Select-Object -ExpandProperty Name -Unique

                # Ensure the current node is a possible owner of the drive.
                if ($possibleOwners -and $possibleOwners -contains $env:COMPUTERNAME)
                {
                    Write-Verbose -Message (
                        $script:localizedData.PossibleClusterResourceOwner -f @(
                            $env:COMPUTERNAME
                            $Path
                        )
                    )

                    $result.IsActiveNode = $false
                    $result.Ensure = 'Present'
                }
                else
                {
                    Write-Verbose -Message (
                        $script:localizedData.NotPossibleClusterResourceOwner -f @(
                            $env:COMPUTERNAME
                            $Path
                        )
                    )
                }
            }
            else
            {
                Write-Verbose -Message (
                    $script:localizedData.NoClusterDiskPartitionFound -f $Path
                )
            }
        }
        else
        {
            Write-Verbose -Message $script:localizedData.NodeIsNotClusterMember
        }

        <#
            Evaluates if the path was not found and the node is the active node.
            The node is always assumed to be the active node unless the node is
            a possible member of a cluster disk partition the path belong to.
            If the node could be a possible member but currently was not the active
            node then the property IsActiveNode was set to $false.
        #>
        if ($result.IsActiveNode)
        {
            Write-Warning -Message (
                $script:localizedData.PathDoesNotExist -f $Path
            )
        }
    }
    else
    {
        Write-Verbose -Message (
            $script:localizedData.PathExist -f $Identity
        )

        $acl = Get-ACLAccess -Path $Path
        $accessRules = $acl.Access

        <#
            Set-TargetResource works without BUILTIN\, but Get-TargetResource fails
            (silently) without this logic. This is regression tested by the 'Users'
            group in the test logic, which is actually BUILTIN\USERS per ACLs,
            however this is not obvious to users and results in unexpected
            functionality such as successfully running Set-TargetResource, but
            result in Test-TargetResource that fail every time. This regex
            workaround for the common windows identifier prefixes makes behavior
            consistent. Local groups are fully qualified with "$env:COMPUTERNAME\".
        #>
        $regexEscapedIdentity = [System.Text.RegularExpressions.Regex]::Escape($Identity)
        $escapedComputerName = [System.Text.RegularExpressions.Regex]::Escape($env:COMPUTERNAME)

        $regex = "^(NT AUTHORITY|BUILTIN|NT SERVICES|$escapedComputerName)\\$regexEscapedIdentity"

        $matchingRules = $accessRules | Where-Object -FilterScript {
            $_.IdentityReference -eq $Identity `
                -or $_.IdentityReference -match $regex
        }

        if ($matchingRules)
        {
            $result.Ensure = 'Present'
            $result.Rights = @(
                ($matchingRules.FileSystemRights -split ', ') | Select-Object -Unique
            )
        }
    }

    return $result
}

<#
    .SYNOPSIS
        Sets the rights of the specified filesystem object for the specified
        identity.

    .PARAMETER Path
        The path to the item that should have permissions set.

    .PARAMETER Identity
        The identity to set permissions for.

    .PARAMETER Rights
        The permissions to include in this rule. Optional if Ensure is set to
        value 'Absent'.

    .PARAMETER Ensure
        Present to create the rule, Absent to remove an existing rule. Default
        value is 'Present'.

    .PARAMETER ProcessOnlyOnActiveNode
        Specifies that the resource will only determine if a change is needed if
        the target node is the active host of the filesystem object. The user the
        configuration is run as must have permission to the Windows Server Failover
        Cluster.

        Not used in Set-TargetResource.

    .NOTES
        This function uses Set-Acl that was first introduced in
        Windows Powershell 5.1.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [Parameter()]
        [ValidateSet(
            'ListDirectory',
            'ReadData',
            'WriteData',
            'CreateFiles',
            'CreateDirectories',
            'AppendData',
            'ReadExtendedAttributes',
            'WriteExtendedAttributes',
            'Traverse',
            'ExecuteFile',
            'DeleteSubdirectoriesAndFiles',
            'ReadAttributes',
            'WriteAttributes',
            'Write',
            'Delete',
            'ReadPermissions',
            'Read',
            'ReadAndExecute',
            'Modify',
            'ChangePermissions',
            'TakeOwnership',
            'Synchronize',
            'FullControl'
        )]
        [System.String[]]
        $Rights,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    if (-not (Test-Path -Path $Path))
    {
        $errorMessage = $script:localizedData.PathDoesNotExist -f $Path

        New-ObjectNotFoundException -Message $errorMessage
    }

    $acl = Get-ACLAccess -Path $Path

    if ($Ensure -eq 'Present')
    {
        # Validate the rights parameter was passed.
        if (-not $PSBoundParameters.ContainsKey('Rights'))
        {
            $errorMessage = $script:localizedData.NoRightsWereSpecified -f $Identity, $Path

            New-InvalidArgumentException -ArgumentName 'Rights' -Message $errorMessage
        }

        Write-Verbose -Message (
            $script:localizedData.SetAllowAccessRule -f ($Rights -join ', '), $Identity, $Path
        )

        $newFileSystemAccessRuleParameters = @{
            TypeName     = 'System.Security.AccessControl.FileSystemAccessRule'
            ArgumentList = @(
                $Identity,
                [System.Security.AccessControl.FileSystemRights] $Rights,
                'ContainerInherit,ObjectInherit',
                'None',
                'Allow'
            )
        }

        $fileSystemAccessRule = New-Object @newFileSystemAccessRuleParameters

        $acl.SetAccessRule($fileSystemAccessRule)
    }

    if ($Ensure -eq 'Absent')
    {
        # If no rights were passed.
        if (-not $PSBoundParameters.ContainsKey('Rights'))
        {
            # Set rights to an empty array.
            $Rights = @()
        }

        <#
            If no specific rights was provided then purge all rights for the
            identity, otherwise remove just the specific rights.
        #>
        if ($Rights.Count -eq 0)
        {
            $identityRules = $acl.Access |
                Where-Object -FilterScript {
                    $_.IdentityReference -eq $Identity
                }

            $identityRule = $identityRules |
                Select-Object -First 1

            if ($identityRule)
            {
                Write-Verbose -Message (
                    $script:localizedData.RemoveAllAllowAccessRules -f $Identity, $Path
                )

                $acl.PurgeAccessRules($identityRule.IdentityReference)
            }
        }
        else
        {
            foreach ($right in $Rights)
            {
                Write-Verbose -Message (
                    $script:localizedData.RemoveAllowAccessRule -f $right, $Identity, $Path
                )

                $removeFileSystemAccessRuleParameters = @{
                    TypeName     = 'System.Security.AccessControl.FileSystemAccessRule'
                    ArgumentList = @(
                        $Identity,
                        [System.Security.AccessControl.FileSystemRights] $right,
                        'ContainerInherit,ObjectInherit',
                        'None',
                        'Allow'
                    )
                }

                $fileSystemAccessRule = New-Object @removeFileSystemAccessRuleParameters

                $null = $acl.RemoveAccessRule($fileSystemAccessRule)
            }
        }
    }

    try
    {
        Set-Acl -Path $Path -AclObject $acl
    }
    catch
    {
        $errorMessage = $script:localizedData.FailedToSetAccessRules -f $Path

        New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
    }
}

<#
    .SYNOPSIS
        Tests the rights of the specified filesystem object for the specified
        identity.

    .PARAMETER Path
        The path to the item that should have permissions set.

    .PARAMETER Identity
        The identity to set permissions for.

    .PARAMETER Rights
        The permissions to include in this rule. Optional if Ensure is set to
        value 'Absent'.

    .PARAMETER Ensure
        Present to create the rule, Absent to remove an existing rule. Default
        value is 'Present'.

    .PARAMETER ProcessOnlyOnActiveNode
        Specifies that the resource will only determine if a change is needed if
        the target node is the active host of the filesystem object. The user the
        configuration is run as must have permission to the Windows Server Failover
        Cluster.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Identity,

        [Parameter()]
        [ValidateSet(
            'ListDirectory',
            'ReadData',
            'WriteData',
            'CreateFiles',
            'CreateDirectories',
            'AppendData',
            'ReadExtendedAttributes',
            'WriteExtendedAttributes',
            'Traverse',
            'ExecuteFile',
            'DeleteSubdirectoriesAndFiles',
            'ReadAttributes',
            'WriteAttributes',
            'Write',
            'Delete',
            'ReadPermissions',
            'Read',
            'ReadAndExecute',
            'Modify',
            'ChangePermissions',
            'TakeOwnership',
            'Synchronize',
            'FullControl'
        )]
        [System.String[]]
        $Rights,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Boolean]
        $ProcessOnlyOnActiveNode
    )

    $result = $true

    $getTargetResourceParameters = @{
        Path     = $Path
        Identity = $Identity
    }

    $currentState = Get-TargetResource @getTargetResourceParameters

    <#
        If this is supposed to process on the active node, and this is not the
        active node, don't bother evaluating the test.
    #>
    if ($ProcessOnlyOnActiveNode -and -not $currentState.IsActiveNode)
    {
        Write-Verbose -Message (
            $script:localizedData.IsNotActiveNode -f $env:COMPUTERNAME, $Path
        )

        return $result
    }

    Write-Verbose -Message (
        $script:localizedData.EvaluatingRights -f $Identity
    )

    switch ($Ensure)
    {
        'Absent'
        {
            # If no rights were passed.
            if (-not $PSBoundParameters.ContainsKey('Rights'))
            {
                # Set rights to an empty array.
                $Rights = @()
            }

            if ($currentState.Rights -and (-not $Rights))
            {
                $result = $false

                Write-Verbose -Message (
                    $script:localizedData.AbsentRightsNotInDesiredState -f $Identity, ($currentState.Rights -join ', ')
                )
            }
            elseif (-not $currentState.Rights)
            {
                $result = $true

                Write-Verbose -Message (
                    $script:localizedData.InDesiredState -f $Identity
                )
            }
            # Always hit, but just clarifying what the actual case is by filling in the if block.
            elseif ($Rights)
            {
                Write-Verbose -Message (
                    $script:localizedData.EvaluatingIndividualRight -f $Identity, ($currentState.Rights -join ', '), ($Rights -join ', ')
                )

                foreach ($right in $Rights)
                {
                    $rightNotAllowed = [System.Security.AccessControl.FileSystemRights] $right
                    $currentRights = [System.Security.AccessControl.FileSystemRights] $currentState.Rights

                    # If any rights that we want to deny are individually a full subset of existing rights.
                    $currentRightResult = -not ($rightNotAllowed -eq ($rightNotAllowed -band $currentRights))

                    if (-not $currentRightResult)
                    {
                        Write-Verbose -Message (
                            $script:localizedData.IndividualRightNotInDesiredState -f $Identity, $rightNotAllowed
                        )
                    }
                    else
                    {
                        Write-Verbose -Message (
                            $script:localizedData.IndividualRightInDesiredState -f $rightNotAllowed
                        )
                    }

                    $result = $result -and $currentRightResult
                }
            }
        }

        'Present'
        {
            # Validate the rights parameter was passed.
            if (-not $PSBoundParameters.ContainsKey('Rights'))
            {
                $errorMessage = $script:localizedData.NoRightsWereSpecified -f $Identity, $Path

                New-InvalidArgumentException -ArgumentName 'Rights' -Message $errorMessage
            }

            <#
                This isn't always the same as the input if parts of the input are subset
                permissions, so pre-cast it. For example:

                [System.Security.AccessControl.FileSystemRights] @('Modify', 'Read', 'Write')

                is actually just 'Modify' within the flagged enum, so test as such to
                avoid false test failures.
            #>
            $expected = [System.Security.AccessControl.FileSystemRights] $Rights

            $result = $false

            if ($currentState.Rights)
            {
                <#
                    At minimum the AND result of the current and expected rights
                    should be the expected rights (allow extra rights, but not
                    missing). Otherwise permission flags are missing from the enum.
                #>
                $result = $expected -eq ($expected -band ([System.Security.AccessControl.FileSystemRights] $currentState.Rights))
            }

            if ($result)
            {
                Write-Verbose -Message (
                    $script:localizedData.InDesiredState -f $Identity
                )
            }
            else
            {
                Write-Verbose -Message (
                    $script:localizedData.NotInDesiredState -f @(
                        $Identity,
                        ($currentState.Rights -join ', '),
                        $expected,
                        ($Rights -join ', ' )
                    )
                )
            }
        }
    }

    return $result
}

<#
    .SYNOPSIS
        This function is wrapper for getting the DACL for the specified path.

    .PARAMETER Path
        The path to the item that should have permissions set.

    .NOTES
        "Well the limited features of Get-ACL means that you always read the full
        security descriptor including the owner whether you intended to or not.
        That means that when you come to write to the object based on a modified
        version of what you read, you are attempting to write back to the owner
        attribute.

        The GetAccessControl('Access') method reads only the DACL so when you
        write it back you are not trying to write something you did not intend to."
        https://www.mickputley.net/2015/11/set-acl-security-identifier-is-not.html
        https://github.com/dsccommunity/FileSystemDsc/issues/3
#>
function Get-ACLAccess
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )
    return (Get-Item -Path $Path).GetAccessControl('Access')
}
