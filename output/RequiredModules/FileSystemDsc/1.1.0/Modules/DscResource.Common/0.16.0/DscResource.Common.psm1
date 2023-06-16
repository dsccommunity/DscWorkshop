#Region './prefix.ps1' 0
$script:modulesFolderPath = Split-Path -Path $PSScriptRoot -Parent
#EndRegion './prefix.ps1' 2
#Region './Private/Assert-RequiredCommandParameter.ps1' 0
<#
    .SYNOPSIS
        Assert that required parameters has been specified.

    .DESCRIPTION
        Assert that required parameters has been specified, and throws an exception if not.

    .PARAMETER BoundParameterList
       A hashtable containing the parameters to evaluate. Normally this is set to
       $PSBoundParameters.

    .PARAMETER RequiredParameter
       One or more parameter names that is required to have been specified.

    .PARAMETER IfParameterPresent
       One or more parameter names that if specified will trigger the evaluation.
       If neither of the parameter names has been specified the evaluation of required
       parameters are not made.

    .EXAMPLE
        Assert-RequiredCommandParameter -BoundParameter $PSBoundParameters -RequiredParameter @('PBStartPortRange', 'PBEndPortRange')

        Throws an exception if either of the two parameters are not specified.

    .EXAMPLE
        Assert-RequiredCommandParameter -BoundParameter $PSBoundParameters -RequiredParameter @('Property2', 'Property3') -IfParameterPresent @('Property1')

        Throws an exception if the parameter 'Property1' is specified and either of the required parameters are not.

    .OUTPUTS
        None.
#>
function Assert-RequiredCommandParameter
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $BoundParameterList,

        [Parameter(Mandatory = $true)]
        [System.String[]]
        $RequiredParameter,

        [Parameter()]
        [System.String[]]
        $IfParameterPresent
    )

    $evaluateRequiredParameter = $true

    if ($PSBoundParameters.ContainsKey('IfParameterPresent'))
    {
        $hasIfParameterPresent = $BoundParameterList.Keys.Where( { $_ -in $IfParameterPresent } )

        if (-not $hasIfParameterPresent)
        {
            $evaluateRequiredParameter = $false
        }
    }

    if ($evaluateRequiredParameter)
    {
        foreach ($parameter in $RequiredParameter)
        {
             if ($parameter -notin $BoundParameterList.Keys)
             {
                $errorMessage = if ($PSBoundParameters.ContainsKey('IfParameterPresent'))
                {
                    $script:localizedData.RequiredCommandParameter_SpecificParametersMustAllBeSetWhenParameterExist -f ($RequiredParameter -join ''', '''), ($IfParameterPresent -join ''', ''')
                }
                else
                {
                    $script:localizedData.RequiredCommandParameter_SpecificParametersMustAllBeSet -f ($RequiredParameter -join ''', ''')
                }

                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        $errorMessage,
                        'ARCP0001', # cspell: disable-line
                        [System.Management.Automation.ErrorCategory]::InvalidOperation,
                        'Command parameters'
                    )
                )
             }
        }
    }
}
#EndRegion './Private/Assert-RequiredCommandParameter.ps1' 90
#Region './Private/Test-DscObjectHasProperty.ps1' 0
<#
    .SYNOPSIS
        Tests if an object has a property.

    .DESCRIPTION
        Tests if the specified object has the specified property and return
        $true or $false.

    .PARAMETER Object
        Specifies the object to test for the specified property.

    .PARAMETER PropertyName
        Specifies the property name to test for.

    .EXAMPLE
        Test-DscObjectHasProperty -Object 'AnyString' -PropertyName 'Length'
#>
function Test-DscObjectHasProperty
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $Object,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PropertyName
    )

    if ($Object.PSObject.Properties.Name -contains $PropertyName)
    {
        return [System.Boolean] $Object.$PropertyName
    }

    return $false
}
#EndRegion './Private/Test-DscObjectHasProperty.ps1' 40
#Region './Private/Test-DscPropertyIsAssigned.ps1' 0
<#
    .SYNOPSIS
        Tests whether the class-based resource property is assigned a non-null value.

    .DESCRIPTION
        Tests whether the class-based resource property is assigned a non-null value.

    .PARAMETER InputObject
        Specifies the object that contain the property.

    .PARAMETER Name
        Specifies the name of the property.

    .EXAMPLE
        Test-DscPropertyIsAssigned -InputObject $this -Name 'MyDscProperty'

        Returns $true or $false whether the property is assigned or not.

    .OUTPUTS
        [System.Boolean]

    .NOTES
        This command only works with nullable data types, if using a non-nullable
        type make sure to make it nullable, e.g. [nullable[System.Int32]].
#>
function Test-DscPropertyIsAssigned
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    begin
    {
        $isAssigned = $false
    }

    process
    {
        $isAssigned = -not ($null -eq $InputObject.$Name)
    }

    end
    {
        return $isAssigned
    }
}
#EndRegion './Private/Test-DscPropertyIsAssigned.ps1' 56
#Region './Private/Test-DscPropertyState.ps1' 0
<#
    .SYNOPSIS
        Compares the current and the desired value of a property.

    .DESCRIPTION
        This function is used to compare the current and the desired value of a
        property.

    .PARAMETER Values
        This is set to a hash table with the current value (the CurrentValue key)
        and desired value (the DesiredValue key).

    .EXAMPLE
        Test-DscPropertyState -Values @{
            CurrentValue = 'John'
            DesiredValue = 'Alice'
        }

    .EXAMPLE
        Test-DscPropertyState -Values @{
            CurrentValue = 1
            DesiredValue = 2
        }

    .NOTES
        This function is used by the cmdlet Compare-ResourcePropertyState.
#>
function Test-DscPropertyState
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $Values
    )

    if ($null -eq $Values.CurrentValue -and $null -eq $Values.DesiredValue)
    {
        # Both values are $null so return $true
        $returnValue = $true
    }
    elseif ($null -eq $Values.CurrentValue -or $null -eq $Values.DesiredValue)
    {
        # Either CurrentValue or DesiredValue are $null so return $false
        $returnValue = $false
    }
    elseif (
        $Values.DesiredValue -is [Microsoft.Management.Infrastructure.CimInstance[]] `
        -or $Values.DesiredValue -is [System.Array] -and $Values.DesiredValue[0] -is [Microsoft.Management.Infrastructure.CimInstance]
    )
    {
        if (-not $Values.ContainsKey('KeyProperties'))
        {
            $errorMessage = $script:localizedData.KeyPropertiesMissing

            New-InvalidOperationException -Message $errorMessage
        }

        $propertyState = @()

        <#
            It is a collection of CIM instances, then recursively call
            Test-DscPropertyState for each CIM instance in the collection.
        #>
        foreach ($desiredCimInstance in $Values.DesiredValue)
        {
            $currentCimInstance = $Values.CurrentValue

            <#
                Use the CIM instance Key properties to filter out the current
                values if the exist.
            #>
            foreach ($keyProperty in $Values.KeyProperties)
            {
                $currentCimInstance = $currentCimInstance |
                    Where-Object -Property $keyProperty -EQ -Value $desiredCimInstance.$keyProperty
            }

            if ($currentCimInstance.Count -gt 1)
            {
                $errorMessage = $script:localizedData.TooManyCimInstances

                New-InvalidOperationException -Message $errorMessage
            }

            if ($currentCimInstance)
            {
                $keyCimInstanceProperties = $currentCimInstance.CimInstanceProperties |
                    Where-Object -FilterScript {
                        $_.Name -in $Values.KeyProperties
                    }

                <#
                    For each key property build a string representation of the
                    property name and its value.
                #>
                $keyPropertyValues = $keyCimInstanceProperties.ForEach({'{0}="{1}"' -f $_.Name, ($_.Value -join ',')})

                Write-Debug -Message (
                    $script:localizedData.TestingCimInstance -f @(
                        $currentCimInstance.CimClass.CimClassName,
                        ($keyPropertyValues -join ';')
                    )
                )
            }
            else
            {
                $keyCimInstanceProperties = $desiredCimInstance.CimInstanceProperties |
                    Where-Object -FilterScript {
                        $_.Name -in $Values.KeyProperties
                    }

                <#
                    For each key property build a string representation of the
                    property name and its value.
                #>
                $keyPropertyValues = $keyCimInstanceProperties.ForEach({'{0}="{1}"' -f $_.Name, ($_.Value -join ',')})

                Write-Debug -Message (
                    $script:localizedData.MissingCimInstance -f @(
                        $desiredCimInstance.CimClass.CimClassName,
                        ($keyPropertyValues -join ';')
                    )
                )
            }

            # Recursively call Test-DscPropertyState with the CimInstance to evaluate.
            $propertyState += Test-DscPropertyState -Values @{
                CurrentValue = $currentCimInstance
                DesiredValue = $desiredCimInstance
            }
        }

        # Return $false if one property is found to not be in desired state.
        $returnValue = -not ($false -in $propertyState)
    }
    elseif ($Values.DesiredValue -is [Microsoft.Management.Infrastructure.CimInstance])
    {
        $propertyState = @()

        <#
            It is a CIM instance, recursively call Test-DscPropertyState for each
            CIM instance property.
        #>
        $desiredCimInstanceProperties = $Values.DesiredValue.CimInstanceProperties |
            Select-Object -Property @('Name', 'Value')

        if ($desiredCimInstanceProperties)
        {
            foreach ($desiredCimInstanceProperty in $desiredCimInstanceProperties)
            {
                <#
                    Recursively call Test-DscPropertyState to evaluate each property
                    in the CimInstance.
                #>
                $propertyState += Test-DscPropertyState -Values @{
                    CurrentValue = $Values.CurrentValue.($desiredCimInstanceProperty.Name)
                    DesiredValue = $desiredCimInstanceProperty.Value
                }
            }
        }
        else
        {
            if ($Values.CurrentValue.CimInstanceProperties.Count -gt 0)
            {
                # Current value did not have any CIM properties, but desired state has.
                $propertyState += $false
            }
        }

        # Return $false if one property is found to not be in desired state.
        $returnValue = -not ($false -in $propertyState)
    }
    elseif ($Values.DesiredValue -is [System.Array] -or $Values.CurrentValue -is [System.Array])
    {
        $compareObjectParameters = @{
            ReferenceObject  = $Values.CurrentValue
            DifferenceObject = $Values.DesiredValue
        }

        $arrayCompare = Compare-Object @compareObjectParameters

        if ($null -ne $arrayCompare)
        {
            Write-Debug -Message $script:localizedData.ArrayDoesNotMatch

            $arrayCompare |
                ForEach-Object -Process {
                    if ($_.SideIndicator -eq '=>')
                    {
                        Write-Debug -Message (
                            $script:localizedData.ArrayValueIsAbsent -f $_.InputObject
                        )
                    }
                    else
                    {
                        Write-Debug -Message (
                            $script:localizedData.ArrayValueIsPresent -f $_.InputObject
                        )
                    }
                }

            $returnValue = $false
        }
        else
        {
            $returnValue = $true
        }
    }
    elseif ($Values.CurrentValue -ne $Values.DesiredValue)
    {
        $desiredType = $Values.DesiredValue.GetType()

        $returnValue = $false

        $supportedTypes = @(
            'String'
            'Int32'
            'UInt32'
            'Int16'
            'UInt16'
            'Single'
            'Boolean'
        )

        if ($desiredType.Name -notin $supportedTypes)
        {
            Write-Warning -Message ($script:localizedData.UnableToCompareType -f $desiredType.Name)
        }
        else
        {
            Write-Debug -Message (
                $script:localizedData.PropertyValueOfTypeDoesNotMatch `
                    -f $desiredType.Name, $Values.CurrentValue, $Values.DesiredValue
            )
        }
    }
    else
    {
        $returnValue = $true
    }

    return $returnValue
}
#EndRegion './Private/Test-DscPropertyState.ps1' 247
#Region './Public/Assert-BoundParameter.ps1' 0
<#
    .SYNOPSIS
        Throws an error if there is a bound parameter that exists in both the
        mutually exclusive lists.

    .DESCRIPTION
        Throws an error if there is a bound parameter that exists in both the
        mutually exclusive lists.

    .PARAMETER BoundParameterList
        The parameters that should be evaluated against the mutually exclusive
        lists MutuallyExclusiveList1 and MutuallyExclusiveList2. This parameter is
        normally set to the $PSBoundParameters variable.

    .PARAMETER MutuallyExclusiveList1
        An array of parameter names that are not allowed to be bound at the
        same time as those in MutuallyExclusiveList2.

    .PARAMETER MutuallyExclusiveList2
        An array of parameter names that are not allowed to be bound at the
        same time as those in MutuallyExclusiveList1.

    .PARAMETER RequiredParameter
       One or more parameter names that is required to have been specified.

    .PARAMETER IfParameterPresent
       One or more parameter names that if specified will trigger the evaluation.
       If neither of the parameter names has been specified the evaluation of required
       parameters are not made.

    .EXAMPLE
        $assertBoundParameterParameters = @{
            BoundParameterList = $PSBoundParameters
            MutuallyExclusiveList1 = @(
                'Parameter1'
            )
            MutuallyExclusiveList2 = @(
                'Parameter2'
            )
        }

        Assert-BoundParameter @assertBoundParameterParameters

        This example throws an exception if `$PSBoundParameters` contains both
        the parameters `Parameter1` and `Parameter2`.

    .EXAMPLE
        Assert-BoundParameter -BoundParameterList $PSBoundParameters -RequiredParameter @('PBStartPortRange', 'PBEndPortRange')

        Throws an exception if either of the two parameters are not specified.

    .EXAMPLE
        Assert-BoundParameter -BoundParameterList $PSBoundParameters -RequiredParameter @('Property2', 'Property3') -IfParameterPresent @('Property1')

        Throws an exception if the parameter 'Property1' is specified and either of the required parameters are not.
#>
function Assert-BoundParameter
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Hashtable]
        $BoundParameterList,

        [Parameter(ParameterSetName = 'MutuallyExclusiveParameters', Mandatory = $true)]
        [System.String[]]
        $MutuallyExclusiveList1,

        [Parameter(ParameterSetName = 'MutuallyExclusiveParameters', Mandatory = $true)]
        [System.String[]]
        $MutuallyExclusiveList2,

        [Parameter(ParameterSetName = 'RequiredParameter', Mandatory = $true)]
        [System.String[]]
        $RequiredParameter,

        [Parameter(ParameterSetName = 'RequiredParameter')]
        [System.String[]]
        $IfParameterPresent
    )

    switch ($PSCmdlet.ParameterSetName)
    {
        'MutuallyExclusiveParameters'
        {
            $itemFoundFromList1 = $BoundParameterList.Keys.Where({ $_ -in $MutuallyExclusiveList1 })
            $itemFoundFromList2 = $BoundParameterList.Keys.Where({ $_ -in $MutuallyExclusiveList2 })

            if ($itemFoundFromList1.Count -gt 0 -and $itemFoundFromList2.Count -gt 0)
            {
                $errorMessage = `
                    $script:localizedData.ParameterUsageWrong `
                        -f ($MutuallyExclusiveList1 -join "','"), ($MutuallyExclusiveList2 -join "','")

                New-InvalidArgumentException -ArgumentName 'Parameters' -Message $errorMessage
            }

            break
        }

        'RequiredParameter'
        {
            Assert-RequiredCommandParameter @PSBoundParameters

            break
        }
    }
}
#EndRegion './Public/Assert-BoundParameter.ps1' 111
#Region './Public/Assert-ElevatedUser.ps1' 0
<#
    .SYNOPSIS
        Assert that the user has elevated the PowerShell session.

    .DESCRIPTION
        Assert that the user has elevated the PowerShell session.

    .EXAMPLE
        Assert-ElevatedUser

        Throws an exception if the user has not elevated the PowerShell session.

    .OUTPUTS
        None.
#>
function Assert-ElevatedUser
{
    [CmdletBinding()]
    param ()

    $isElevated = $false

    if ($IsMacOS -or $IsLinux)
    {
        $isElevated = (id -u) -eq 0
    }
    else
    {
        [Security.Principal.WindowsPrincipal] $user = [Security.Principal.WindowsIdentity]::GetCurrent()

        $isElevated = $user.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    }

    if (-not $isElevated)
    {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                $script:localizedData.ElevatedUser_UserNotElevated,
                'UserNotElevated',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                'Command parameters'
            )
        )
    }
}
#EndRegion './Public/Assert-ElevatedUser.ps1' 46
#Region './Public/Assert-IPAddress.ps1' 0
<#
    .SYNOPSIS
        Asserts that the specified IP address is valid.

    .DESCRIPTION
        Checks the IP address so that it is valid and do not conflict with address
        family. If any problems are detected an exception will be thrown.

    .PARAMETER AddressFamily
        IP address family that the supplied Address should be in. Valid values are
        'IPv4' or 'IPv6'.

    .PARAMETER Address
        Specifies an IPv4 or IPv6 address.

    .EXAMPLE
        Assert-IPAddress -Address '127.0.0.1'

        This will assert that the supplied address is a valid IPv4 address.
        If it is not an exception will be thrown.

    .EXAMPLE
        Assert-IPAddress -Address 'fe80:ab04:30F5:002b::1'

        This will assert that the supplied address is a valid IPv6 address.
        If it is not an exception will be thrown.

    .EXAMPLE
        Assert-IPAddress -Address 'fe80:ab04:30F5:002b::1' -AddressFamily 'IPv6'

        This will assert that address is valid and that it matches the
        supplied address family. If the supplied address family does not match
        the address an exception will be thrown.
#>
function Assert-IPAddress
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('IPv4', 'IPv6')]
        [System.String]
        $AddressFamily,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Address
    )

    [System.Net.IPAddress] $ipAddress = $null

    if (-not ([System.Net.IPAddress]::TryParse($Address, [ref] $ipAddress)))
    {
        New-InvalidArgumentException `
            -Message ($script:localizedData.AddressFormatError -f $Address) `
            -ArgumentName 'Address'
    }

    if ($AddressFamily)
    {
        switch ($AddressFamily)
        {
            'IPv4'
            {
                if ($ipAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork.ToString())
                {
                    New-InvalidArgumentException `
                        -Message ($script:localizedData.AddressIPv6MismatchError -f $Address, $AddressFamily) `
                        -ArgumentName 'AddressFamily'
                }
            }

            'IPv6'
            {
                if ($ipAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6.ToString())
                {
                    New-InvalidArgumentException `
                        -Message ($script:localizedData.AddressIPv4MismatchError -f $Address, $AddressFamily) `
                        -ArgumentName 'AddressFamily'
                }
            }
        }
    }
}
#EndRegion './Public/Assert-IPAddress.ps1' 86
#Region './Public/Assert-Module.ps1' 0
<#
    .SYNOPSIS
        Assert if the specific module is available to be imported.

    .DESCRIPTION
        Assert if the specific module is available to be imported.

    .PARAMETER ModuleName
        Specifies the name of the module to assert.

    .PARAMETER ImportModule
        Specifies to import the module if it is asserted.

    .PARAMETER Force
        Specifies to forcibly import the module even if it is already in the
        session. This parameter is ignored unless parameter `ImportModule` is
        also used.

    .EXAMPLE
        Assert-Module -ModuleName 'DhcpServer'

        This asserts that the module DhcpServer is available on the system.

    .EXAMPLE
        Assert-Module -ModuleName 'DhcpServer' -ImportModule

        This asserts that the module DhcpServer is available on the system and
        imports it.

    .EXAMPLE
        Assert-Module -ModuleName 'DhcpServer' -ImportModule -Force

        This asserts that the module DhcpServer is available on the system and
        forcibly imports it.
#>
function Assert-Module
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleName,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $ImportModule,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Force
    )

    <#
        If the module is already in the session there is no need to use -ListAvailable.
        This is a fix for issue #66.
    #>
    if (-not (Get-Module -Name $ModuleName))
    {
        if (-not (Get-Module -Name $ModuleName -ListAvailable))
        {
            $errorMessage = $script:localizedData.ModuleNotFound -f $ModuleName
            New-ObjectNotFoundException -Message $errorMessage
        }

        # Only import it here if $Force is not set, otherwise it will be imported below.
        if ($ImportModule -and -not $Force)
        {
            Import-Module -Name $ModuleName
        }
    }

    # Always import the module even if already in session.
    if ($ImportModule -and $Force)
    {
        Import-Module -Name $ModuleName -Force
    }
}
#EndRegion './Public/Assert-Module.ps1' 79
#Region './Public/Compare-DscParameterState.ps1' 0
<#
    .SYNOPSIS
        This method is used to compare current and desired values for any DSC resource.

    .DESCRIPTION
        This function compare the parameter status of DSC resource parameters against
        the current values present on the system, and return a hashtable with the metadata
        from the comparison.

    .PARAMETER CurrentValues
        A hashtable with the current values on the system, obtained by e.g.
        Get-TargetResource.

    .PARAMETER DesiredValues
        The hashtable of desired values. For example $PSBoundParameters with the
        desired values.

    .PARAMETER Properties
        This is a list of properties in the desired values list should be checked.
        If this is empty then all values in DesiredValues are checked.

    .PARAMETER ExcludeProperties
        This is a list of which properties in the desired values list should be checked.
        If this is empty then all values in DesiredValues are checked.

    .PARAMETER TurnOffTypeChecking
        Indicates that the type of the parameter should not be checked.

    .PARAMETER ReverseCheck
        Indicates that a reverse check should be done. The current and desired state
        are swapped for another test.

    .PARAMETER SortArrayValues
        If the sorting of array values does not matter, values are sorted internally
        before doing the comparison.

    .PARAMETER IncludeInDesiredState
        Indicates that result adds the properties in the desired state.
        By default, this command returns only the properties not in desired state.

    .PARAMETER IncludeValue
        Indicates that result contains the ActualValue and ExcpectedValue properties.

    .EXAMPLE
        $currentValues = @{
            String = 'This is a string'
            Int = 1
            Bool = $true
        }

        $desiredValues = @{
            String = 'This is a string'
            Int = 99
        }

        Compare-DscParameterState -CurrentValues $currentValues -DesiredValues $desiredValues

        Name                           Value
        ----                           -----
        Property                       Int
        InDesiredState                 False
        ExpectedType                   System.Int32
        ActualType                     System.Int32
        ```

        The function Compare-DscParameterState compare the value of each hashtable based
        on the keys present in $desiredValues hashtable. The result indicates that Int
        property is not in the desired state.
        No information about Bool property, because it is not in $desiredValues hashtable.

    .EXAMPLE
        $currentValues = @{
            String = 'This is a string'
            Int = 1
            Bool = $true
        }

        $desiredValues = @{
            String = 'This is a string'
            Int = 99
            Bool = $false
        }

        $excludeProperties = @('Bool')

        Compare-DscParameterState `
            -CurrentValues $currentValues `
            -DesiredValues $desiredValues `
            -ExcludeProperties $ExcludeProperties

        Name                           Value
        ----                           -----
        Property                       Int
        InDesiredState                 False
        ExpectedType                   System.Int32
        ActualType                     System.Int32
        ```

        The function Compare-DscParameterState compare the value of each hashtable based
        on the keys present in $desiredValues hashtable and without those in $excludeProperties.
        The result indicates that Int property is not in the desired state.
        No information about Bool property, because it is in $excludeProperties.

    .EXAMPLE
        $serviceParameters = @{
            Name     = $Name
        }

        $returnValue = Compare-DscParameterState `
            -CurrentValues (Get-Service @serviceParameters) `
            -DesiredValues $PSBoundParameters `
            -Properties @(
                'Name'
                'Status'
                'StartType'
            )

        This compares the values in the current state against the desires state.
        The command Get-Service is called using just the required parameters
        to get the values in the current state. The parameter 'Properties'
        is used to specify the properties 'Name','Status' and
        'StartType' for the comparison.

#>
function Compare-DscParameterState
{
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $CurrentValues,

        [Parameter(Mandatory = $true)]
        [System.Object]
        $DesiredValues,

        [Parameter()]
        [System.String[]]
        [Alias('ValuesToCheck')]
        $Properties,

        [Parameter()]
        [System.String[]]
        $ExcludeProperties,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $TurnOffTypeChecking,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $ReverseCheck,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $SortArrayValues,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludeInDesiredState,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludeValue
    )

    $returnValue = @()
    #region ConvertCIm to Hashtable
    if ($CurrentValues -is [Microsoft.Management.Infrastructure.CimInstance] -or
        $CurrentValues -is [Microsoft.Management.Infrastructure.CimInstance[]])
    {
        $CurrentValues = ConvertTo-HashTable -CimInstance $CurrentValues
    }

    if ($DesiredValues -is [Microsoft.Management.Infrastructure.CimInstance] -or
        $DesiredValues -is [Microsoft.Management.Infrastructure.CimInstance[]])
    {
        $DesiredValues = ConvertTo-HashTable -CimInstance $DesiredValues
    }
    #endregion Endofconverion
    #region CheckType of object
    $types = 'System.Management.Automation.PSBoundParametersDictionary',
        'System.Collections.Hashtable',
        'Microsoft.Management.Infrastructure.CimInstance'

    if ($DesiredValues.GetType().FullName -notin $types)
    {
        New-InvalidArgumentException `
            -Message ($script:localizedData.InvalidDesiredValuesError -f $DesiredValues.GetType().FullName) `
            -ArgumentName 'DesiredValues'
    }

    if ($CurrentValues.GetType().FullName -notin $types)
    {
        New-InvalidArgumentException `
            -Message ($script:localizedData.InvalidCurrentValuesError -f $CurrentValues.GetType().FullName) `
            -ArgumentName 'CurrentValues'
    }
    #endregion checktype
    #region check if CimInstance and not have properties in parameters invoke exception
    if ($DesiredValues -is [Microsoft.Management.Infrastructure.CimInstance] -and -not $Properties)
    {
        New-InvalidArgumentException `
            -Message $script:localizedData.InvalidPropertiesError `
            -ArgumentName Properties
    }
    #endregion check cim and properties
    #Clean value if there are a common parameters provide from Test/Get-TargetResource parameter
    $desiredValuesClean = Remove-CommonParameter -Hashtable $DesiredValues
    #region generate keyList based on $Properties and $excludeProperties value
    if (-not $Properties)
    {
        $keyList = $desiredValuesClean.Keys
    }
    else
    {
        $keyList = $Properties
    }

    if ($ExcludeProperties)
    {
        $keyList = $keyList | Where-Object -FilterScript { $_ -notin $ExcludeProperties }
    }
    #endregion
    #region enumerate of each key in list
    foreach ($key in $keyList)
    {
        #generate default value
        $InDesiredStateTable = [ordered]@{
            Property        = $key
            InDesiredState  = $true
        }
        $returnValue += $InDesiredStateTable
        #get value of each key
        $desiredValue = $desiredValuesClean.$key
        $currentValue = $CurrentValues.$key

        #Check if IncludeValue parameter is used.
        if ($IncludeValue)
        {
            $InDesiredStateTable['ExpectedValue']   = $desiredValue
            $InDesiredStateTable['ActualValue']     = $currentValue
        }

        #region convert to hashtable if value of key is CimInstance
        if ($desiredValue -is [Microsoft.Management.Infrastructure.CimInstance] -or
            $desiredValue -is [Microsoft.Management.Infrastructure.CimInstance[]])
        {
            $desiredValue = ConvertTo-HashTable -CimInstance $desiredValue
        }
        if ($currentValue -is [Microsoft.Management.Infrastructure.CimInstance] -or
            $currentValue -is [Microsoft.Management.Infrastructure.CimInstance[]])
        {
            $currentValue = ConvertTo-HashTable -CimInstance $currentValue
        }
        #endregion converttohashtable
        #region gettype of value to check if they are the same.
        if ($null -ne $desiredValue)
        {
            $desiredType = $desiredValue.GetType()
        }
        else
        {
            $desiredType = @{
                Name = 'Unknown'
            }
        }

        $InDesiredStateTable['ExpectedType'] = $desiredType

        if ($null -ne $currentValue)
        {
            $currentType = $currentValue.GetType()
        }
        else
        {
            $currentType = @{
                Name = 'Unknown'
            }
        }

        $InDesiredStateTable['ActualType'] = $currentType

        #endregion
        #region check if the desiredtype if a credential object. Only if the current type isn't unknown.
        if ($currentType.Name -ne 'Unknown' -and $desiredType.Name -eq 'PSCredential')
        {
            # This is a credential object. Compare only the user name
            if ($currentType.Name -eq 'PSCredential' -and $currentValue.UserName -eq $desiredValue.UserName)
            {
                Write-Verbose -Message ($script:localizedData.MatchPsCredentialUsernameMessage -f $currentValue.UserName, $desiredValue.UserName)
                continue # pass to the next key
            }
            elseif ($currentType.Name -ne 'string')
            {
                Write-Verbose -Message ($script:localizedData.NoMatchPsCredentialUsernameMessage -f $currentValue.UserName, $desiredValue.UserName)
                $InDesiredStateTable.InDesiredState = $false
            }

            # Assume the string is our username when the matching desired value is actually a credential
            if ($currentType.Name -eq 'string' -and $currentValue -eq $desiredValue.UserName)
            {
                Write-Verbose -Message ($script:localizedData.MatchPsCredentialUsernameMessage -f $currentValue, $desiredValue.UserName)
                continue # pass to the next key
            }
            else
            {
                Write-Verbose -Message ($script:localizedData.NoMatchPsCredentialUsernameMessage -f $currentValue, $desiredValue.UserName)
                $InDesiredStateTable.InDesiredState = $false
            }
        }
        #endregion test credential
        #region Test type of object. And if they're not InDesiredState, generate en exception
        if (-not $TurnOffTypeChecking)
        {
            if (($desiredType.Name -ne 'Unknown' -and $currentType.Name -ne 'Unknown') -and
                $desiredType.FullName -ne $currentType.FullName)
            {
                Write-Verbose -Message ($script:localizedData.NoMatchTypeMismatchMessage -f $key, $currentType.FullName, $desiredType.FullName)
                $InDesiredStateTable.InDesiredState = $false
                continue # pass to the next key
            }
            elseif ($desiredType.Name -eq 'Unknown' -and $desiredType.Name -ne $currentType.Name)
            {
                Write-Verbose -Message ($script:localizedData.NoMatchTypeMismatchMessage -f $key, $currentType.Name, $desiredType.Name)
                $InDesiredStateTable.InDesiredState = $false
                continue # pass to the next key
            }
        }
        #endregion TestType
        #region Check if the value of Current and desired state is the same but only if they are not an array
        if ($currentValue -eq $desiredValue -and -not $desiredType.IsArray)
        {
            Write-Verbose -Message ($script:localizedData.MatchValueMessage -f $desiredType.FullName, $key, $currentValue, $desiredValue)
            continue # pass to the next key
        }
        #endregion check same value
        #region Check if the DesiredValuesClean has the key and if it doesn't have, it's not necessary to check his value
        if ($desiredValuesClean.GetType().Name -in 'HashTable', 'PSBoundParametersDictionary')
        {
            $checkDesiredValue = $desiredValuesClean.ContainsKey($key)
        }
        else
        {
            $checkDesiredValue = Test-DscObjectHasProperty -Object $desiredValuesClean -PropertyName $key
        }
        # if there no key, don't need to check
        if (-not $checkDesiredValue)
        {
            Write-Verbose -Message ($script:localizedData.MatchValueMessage -f $desiredType.FullName, $key, $currentValue, $desiredValue)
            continue # pass to the next key
        }
        #endregion
        #region Check if desired type is array, ifno Hashtable and currenttype hashtable to
        if ($desiredType.IsArray)
        {
            Write-Verbose -Message ($script:localizedData.TestDscParameterCompareMessage -f $key, $desiredType.FullName)
            # Check if the currentValues and desiredValue are empty array.
            if (-not $currentValue -and -not $desiredValue)
            {
                Write-Verbose -Message ($script:localizedData.MatchValueMessage -f $desiredType.FullName, $key, 'empty array', 'empty array')
                continue
            }
            elseif (-not $currentValue)
            {
                #If only currentvalue is empty, the configuration isn't compliant.
                Write-Verbose -Message ($script:localizedData.NoMatchValueMessage -f $desiredType.FullName, $key, $currentValue, $desiredValue)
                $InDesiredStateTable.InDesiredState = $false
                continue
            }
            elseif ($currentValue.Count -ne $desiredValue.Count)
            {
                #If there is a difference between the number of objects in arrays, this isn't compliant.
                Write-Verbose -Message ($script:localizedData.NoMatchValueDifferentCountMessage -f $desiredType.FullName, $key, $currentValue.Count, $desiredValue.Count)
                $InDesiredStateTable.InDesiredState = $false
                continue
            }
            else
            {
                $desiredArrayValues = $desiredValue
                $currentArrayValues = $currentValue
                # if the sortArrayValues parameter is using, sort value of array
                if ($SortArrayValues)
                {
                    $desiredArrayValues = @($desiredArrayValues | Sort-Object)
                    $currentArrayValues = @($currentArrayValues | Sort-Object)
                }
                <#
                    for all object in collection, check their type.ConvertoString if they are script block.

                #>
                for ($i = 0; $i -lt $desiredArrayValues.Count; $i++)
                {
                    if ($desiredArrayValues[$i])
                    {
                        $desiredType = $desiredArrayValues[$i].GetType()
                    }
                    else
                    {
                        $desiredType = @{
                            Name = 'Unknown'
                        }
                    }

                    if ($currentArrayValues[$i])
                    {
                        $currentType = $currentArrayValues[$i].GetType()
                    }
                    else
                    {
                        $currentType = @{
                            Name = 'Unknown'
                        }
                    }

                    if (-not $TurnOffTypeChecking)
                    {
                        if (($desiredType.Name -ne 'Unknown' -and $currentType.Name -ne 'Unknown') -and
                            $desiredType.FullName -ne $currentType.FullName)
                        {
                            Write-Verbose -Message ($script:localizedData.NoMatchElementTypeMismatchMessage -f $key, $i, $currentType.FullName, $desiredType.FullName)
                            $InDesiredStateTable.InDesiredState = $false
                            continue
                        }
                    }

                    <#
                        Convert a scriptblock into a string as scriptblocks are not comparable
                        if currentvalue is scriptblock and if desired value is string,
                        we invoke the result of script block. Ifno, we convert to string.
                        if Desired value
                    #>

                    $wasCurrentArrayValuesConverted = $false
                    if ($currentArrayValues[$i] -is [scriptblock])
                    {
                        $currentArrayValues[$i] = if ($desiredArrayValues[$i] -is [string])
                        {
                            $currentArrayValues[$i] = $currentArrayValues[$i].Invoke()
                        }
                        else
                        {
                            $currentArrayValues[$i].ToString()
                        }
                        $wasCurrentArrayValuesConverted = $true
                    }

                    if ($desiredArrayValues[$i] -is [scriptblock])
                    {
                        $desiredArrayValues[$i] = if ($currentArrayValues[$i] -is [string] -and -not $wasCurrentArrayValuesConverted)
                        {
                            $desiredArrayValues[$i].Invoke()
                        }
                        else
                        {
                            $desiredArrayValues[$i].ToString()
                        }
                    }

                    if ($desiredType -eq [System.Collections.Hashtable] -and $currentType -eq [System.Collections.Hashtable])
                    {
                        $param = @{} + $PSBoundParameters
                        $param.CurrentValues = $currentArrayValues[$i]
                        $param.DesiredValues = $desiredArrayValues[$i]

                        'IncludeInDesiredState','IncludeValue','Properties','ReverseCheck' | ForEach-Object {
                            if ($param.ContainsKey($_))
                            {
                                $null = $param.Remove($_)
                            }
                        }

                        if ($InDesiredStateTable.InDesiredState)
                        {
                            $InDesiredStateTable.InDesiredState = Test-DscParameterState @param
                        }
                        else
                        {
                            Test-DscParameterState @param | Out-Null
                        }
                        continue
                    }

                    if ($desiredArrayValues[$i] -ne $currentArrayValues[$i])
                    {
                        Write-Verbose -Message ($script:localizedData.NoMatchElementValueMismatchMessage -f $i, $desiredType.FullName, $key, $currentArrayValues[$i], $desiredArrayValues[$i])
                        $InDesiredStateTable.InDesiredState = $false
                        continue
                    }
                    else
                    {
                        Write-Verbose -Message ($script:localizedData.MatchElementValueMessage -f $i, $desiredType.FullName, $key, $currentArrayValues[$i], $desiredArrayValues[$i])
                        continue
                    }
                }

            }
        }
        elseif ($desiredType -eq [System.Collections.Hashtable] -and $currentType -eq [System.Collections.Hashtable])
        {
            $param = @{} + $PSBoundParameters
            $param.CurrentValues = $currentValue
            $param.DesiredValues = $desiredValue

            'IncludeInDesiredState','IncludeValue','Properties','ReverseCheck' | ForEach-Object {
                if ($param.ContainsKey($_))
                {
                    $null = $param.Remove($_)
                }
            }

            if ($InDesiredStateTable.InDesiredState)
            {
                <#
                    if desiredvalue is an empty hashtable and not currentvalue, it's not necessery to compare them, it's not compliant.
                    See issue 65 https://github.com/dsccommunity/DscResource.Common/issues/65
                #>
                if ($desiredValue.Keys.Count -eq 0 -and $currentValue.Keys.Count -ne 0)
                {
                    Write-Verbose -Message ($script:localizedData.NoMatchKeyMessage -f $desiredType.FullName, $key, $($currentValue.Keys -join ', '))
                    $InDesiredStateTable.InDesiredState = $false
                }
                else{
                    $InDesiredStateTable.InDesiredState = Test-DscParameterState @param
                }
            }
            else
            {
                $null = Test-DscParameterState @param
            }
            continue
        }
        else
        {
            #Convert a scriptblock into a string as scriptblocks are not comparable
            $wasCurrentValue = $false
            if ($currentValue -is [scriptblock])
            {
                $currentValue = if ($desiredValue -is [string])
                {
                    $currentValue = $currentValue.Invoke()
                }
                else
                {
                    $currentValue.ToString()
                }
                $wasCurrentValue = $true
            }
            if ($desiredValue -is [scriptblock])
            {
                $desiredValue = if ($currentValue -is [string] -and -not $wasCurrentValue)
                {
                    $desiredValue.Invoke()
                }
                else
                {
                    $desiredValue.ToString()
                }
            }

            if ($desiredValue -ne $currentValue)
            {
                Write-Verbose -Message ($script:localizedData.NoMatchValueMessage -f $desiredType.FullName, $key, $currentValue, $desiredValue)
                $InDesiredStateTable.InDesiredState = $false
            }
        }
        #endregion check type
    }
    #endregion end of enumeration
    if ($ReverseCheck)
    {
        Write-Verbose -Message $script:localizedData.StartingReverseCheck
        $reverseCheckParameters = @{} + $PSBoundParameters
        $reverseCheckParameters['CurrentValues'] = $DesiredValues
        $reverseCheckParameters['DesiredValues'] = $CurrentValues
        $reverseCheckParameters['Properties'] = $keyList + $CurrentValues.Keys | Select-Object -Unique
        if ($ExcludeProperties)
        {
            $reverseCheckParameters['Properties'] = $reverseCheckParameters['Properties'] | Where-Object -FilterScript { $_ -notin $ExcludeProperties }
        }

        $null = $reverseCheckParameters.Remove('ReverseCheck')

        if ($returnValue)
        {
            $returnValue = Compare-DscParameterState @reverseCheckParameters
        }
        else
        {
            $null = Compare-DscParameterState @reverseCheckParameters
        }
    }

    # Remove in desired state value if IncludeDesirateState parameter is not use
    if (-not $IncludeInDesiredState)
    {
        [array]$returnValue = $returnValue.where({$_.InDesiredState -eq $false})
    }

    #change verbose message
    if ($IncludeInDesiredState.IsPresent)
    {
        $returnValue.ForEach({
            if ($_.InDesiredState)
            {
                $localizedString = $script:localizedData.PropertyInDesiredStateMessage
            }
            else
            {
                $localizedString = $script:localizedData.PropertyNotInDesiredStateMessage
            }

            Write-Verbose -Message ($localizedString -f $_.Property)
        })
    }
    <#
        If Compare-DscParameterState is used in precedent step, don't need to convert it
        We use .foreach() method as we are sure that $returnValue is an array.
    #>
    [Array]$returnValue = @(
        $returnValue.foreach(
            {
                if ($_ -is [System.Collections.Hashtable])
                {
                    [pscustomobject]$_
                }
                else
                {
                    $_
                }
            }
        )
    )

    return $returnValue
}
#EndRegion './Public/Compare-DscParameterState.ps1' 639
#Region './Public/Compare-ResourcePropertyState.ps1' 0
<#
    .SYNOPSIS
        Compare current and desired property values for any DSC resource.

    .DESCRIPTION
        This function is used to compare current and desired property values for any
        DSC resource, and return a hashtable with the metadata from the comparison.

    .PARAMETER CurrentValues
        The current values that should be compared to to desired values. Normally
        the values returned from Get-TargetResource.

    .PARAMETER DesiredValues
        The values set in the configuration and is provided in the call to the
        functions *-TargetResource, and that will be compared against current
        values. Normally set to $PSBoundParameters.

    .PARAMETER Properties
        An array of property names, from the keys provided in DesiredValues, that
        will be compared. If this parameter is left out, all the keys in the
        DesiredValues will be compared.

    .PARAMETER IgnoreProperties
        An array of property names, from the keys provided in DesiredValues, that
        will be ignored in the comparison. If this parameter is left out, all the
        keys in the DesiredValues will be compared.

    .PARAMETER CimInstanceKeyProperties
        A hashtable containing a key for each property that contain a collection
        of CimInstances and the value is an array of strings of the CimInstance
        key properties.
        @{
            Permission = @('State')
        }

    .EXAMPLE
        $compareTargetResourceStateParameters = @{
            CurrentValues = (Get-TargetResource $PSBoundParameters)
            DesiredValues = $PSBoundParameters
        }

        $propertyState = Compare-ResourcePropertyState @compareTargetResourceStateParameters

        This examples call Compare-ResourcePropertyState with the current state
        and the desired state and returns a hashtable array of all the properties
        that was evaluated based on the properties pass in the parameter DesiredValues.
#>
function Compare-ResourcePropertyState
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $CurrentValues,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $DesiredValues,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Properties,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $IgnoreProperties,

        [Parameter()]
        [ValidateNotNull()]
        [System.Collections.Hashtable]
        $CimInstanceKeyProperties = @{}
    )

    if ($PSBoundParameters.ContainsKey('Properties'))
    {
        # Filter out the parameters (keys) not specified in Properties
        $desiredValuesToRemove = $DesiredValues.Keys |
            Where-Object -FilterScript {
                $_ -notin $Properties
            }

        $desiredValuesToRemove |
            ForEach-Object -Process {
                $DesiredValues.Remove($_)
            }
    }
    else
    {
        <#
            Remove any common parameters that might be part of DesiredValues,
            if it $PSBoundParameters was used to pass the desired values.
        #>
        $commonParametersToRemove = $DesiredValues.Keys |
            Where-Object -FilterScript {
                $_ -in [System.Management.Automation.PSCmdlet]::CommonParameters `
                    -or $_ -in [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
            }

        $commonParametersToRemove |
            ForEach-Object -Process {
                $DesiredValues.Remove($_)
            }
    }

    # Remove any properties that should be ignored.
    if ($PSBoundParameters.ContainsKey('IgnoreProperties'))
    {
        $IgnoreProperties |
            ForEach-Object -Process {
                if ($DesiredValues.ContainsKey($_))
                {
                    $DesiredValues.Remove($_)
                }
            }
    }

    $compareTargetResourceStateReturnValue = @()

    foreach ($parameterName in $DesiredValues.Keys)
    {
        Write-Debug -Message ($script:localizedData.EvaluatePropertyState -f $parameterName)

        $parameterState = @{
            ParameterName = $parameterName
            Expected      = $DesiredValues.$parameterName
            Actual        = $CurrentValues.$parameterName
        }

        # Check if the parameter is in compliance.
        $isPropertyInDesiredState = Test-DscPropertyState -Values @{
            CurrentValue = $CurrentValues.$parameterName
            DesiredValue = $DesiredValues.$parameterName
            KeyProperties = $CimInstanceKeyProperties.$parameterName
        }

        if ($isPropertyInDesiredState)
        {
            Write-Verbose -Message ($script:localizedData.PropertyInDesiredState -f $parameterName)

            $parameterState['InDesiredState'] = $true
        }
        else
        {
            Write-Verbose -Message ($script:localizedData.PropertyNotInDesiredState -f $parameterName)

            $parameterState['InDesiredState'] = $false
        }

        $compareTargetResourceStateReturnValue += $parameterState
    }

    return $compareTargetResourceStateReturnValue
}
#EndRegion './Public/Compare-ResourcePropertyState.ps1' 158
#Region './Public/ConvertFrom-DscResourceInstance.ps1' 0

<#
    .SYNOPSIS
        Convert any object to hashtable.

    .DESCRIPTION
        This function is used to convert a psobject into a hashtable.

    .PARAMETER InputObject
        The object that should be convert to hashtable.

    .PARAMETER OutPutFormat
        Set the format you do want to convert the object. The default value is HashTable.
        It's the only value accepted at this time.

    .OUTPUTS
        Hashtable

    .EXAMPLE

    $Object = [pscustomobject]=@{
        FirstName = 'John'
        LastName = 'Smith'
    }

    ConvertFrom-DscResourceInstance -InputObject $Object

    This creates a pscustomobject and converts its properties/values to Hashtable Key/Value.

    .EXAMPLE

    $ObjectArray = [pscustomobject]=@{
        FirstName = 'John'
        LastName = 'Smith'
    },[pscustomobject]=@{
        FirstName = 'Peter'
        LastName = 'Smith'
    }

    $ObjectArray | ConvertFrom-DscResourceInstance

    This creates pscustomobjects and converts there properties/values to Hashtable Keys/Values through the pipeline.
#>
function ConvertFrom-DscResourceInstance
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $InputObject,

        [Parameter()]
        [ValidateSet('HashTable')]
        [String]
        $OutPutFormat = 'HashTable'

    )
    process {

        switch ($OutPutFormat)
        {
            'HashTable'
            {
                $Result = @{}
                foreach ($obj in $InputObject)
                {
                    $obj.psobject.Properties | Foreach-Object {
                        $Result[$_.Name] = $_.Value
                    }
                }
            }
        }

        return $Result
    }
}
#EndRegion './Public/ConvertFrom-DscResourceInstance.ps1' 79
#Region './Public/ConvertTo-CimInstance.ps1' 0
<#
    .SYNOPSIS
        Converts a hashtable into a CimInstance array.

    .DESCRIPTION
        This function is used to convert a hashtable into MSFT_KeyValuePair objects.
        These are stored as an CimInstance array. DSC cannot handle hashtables but
        CimInstances arrays storing MSFT_KeyValuePair.

    .PARAMETER Hashtable
        A hashtable with the values to convert.

    .OUTPUTS
        An object array with CimInstance objects.

    .EXAMPLE
        ConvertTo-CimInstance -Hashtable @{
            String = 'a string'
            Bool   = $true
            Int    = 99
            Array  = 'a, b, c'
        }

        This example returns an CimInstance with the provided hashtable values.
#>
function ConvertTo-CimInstance
{
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Hashtable')]
        [System.Collections.Hashtable]
        $Hashtable
    )

    process
    {
        foreach ($item in $Hashtable.GetEnumerator())
        {
            New-CimInstance -ClassName 'MSFT_KeyValuePair' -Namespace 'root/microsoft/Windows/DesiredStateConfiguration' -Property @{
                Key   = $item.Key
                Value = if ($item.Value -is [array])
                {
                    $item.Value -join ','
                }
                else
                {
                    $item.Value
                }
            } -ClientOnly
        }
    }
}
#EndRegion './Public/ConvertTo-CimInstance.ps1' 55
#Region './Public/ConvertTo-HashTable.ps1' 0
<#
    .SYNOPSIS
        Converts CimInstances into a hashtable.

    .DESCRIPTION
        This function is used to convert a CimInstance array containing
        MSFT_KeyValuePair objects into a hashtable.

    .PARAMETER CimInstance
        An array of CimInstances or a single CimInstance object to convert.

    .OUTPUTS
        Hashtable

    .EXAMPLE
        $newInstanceParameters = @{
            ClassName = 'MSFT_KeyValuePair'
            Namespace = 'root/microsoft/Windows/DesiredStateConfiguration'
            ClientOnly = $true
        }

        $cimInstance = [Microsoft.Management.Infrastructure.CimInstance[]] (
            (New-CimInstance @newInstanceParameters -Property @{
                Key   = 'FirstName'
                Value = 'John'
            }),

            (New-CimInstance @newInstanceParameters -Property @{
                Key   = 'LastName'
                Value = 'Smith'
            })
        )

        ConvertTo-HashTable -CimInstance $cimInstance

        This creates a array om CimInstances of the class name MSFT_KeyValuePair
        and passes it to ConvertTo-HashTable which returns a hashtable.
#>
function ConvertTo-HashTable
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'CimInstance')]
        [AllowEmptyCollection()]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $CimInstance
    )

    begin
    {
        $result = @{ }
    }

    process
    {
        foreach ($ci in $CimInstance)
        {
            $result.Add($ci.Key, $ci.Value)
        }
    }

    end
    {
        $result
    }
}
#EndRegion './Public/ConvertTo-HashTable.ps1' 69
#Region './Public/Find-Certificate.ps1' 0
<#
    .SYNOPSIS
        Locates one or more certificates using the passed certificate selector parameters.

        If more than one certificate is found matching the selector criteria, they will be
        returned in order of descending expiration date.

    .DESCRIPTION
        A common function to find certificates based on multiple search filters, including,
        but not limited to: Thumbprint, Friendly Name, DNS Names, Key Usage, Issuers, etc.

    .PARAMETER Thumbprint
        The thumbprint of the certificate to find.

    .PARAMETER FriendlyName
        The friendly name of the certificate to find.

    .PARAMETER Subject
        The subject of the certificate to find.

    .PARAMETER DNSName
        The subject alternative name of the certificate to export must contain these values.

    .PARAMETER Issuer
        The issuer of the certificate to find.

    .PARAMETER KeyUsage
        The key usage of the certificate to find must contain these values.

    .PARAMETER EnhancedKeyUsage
        The enhanced key usage of the certificate to find must contain these values.

    .PARAMETER Store
        The Windows Certificate Store Name to search for the certificate in.
        Defaults to 'My'.

    .PARAMETER AllowExpired
        Allows expired certificates to be returned.

    .EXAMPLE
        Find-Certificate -Thumbprint '1111111111111111111111111111111111111111'

        Return certificate that matches thumbprint.

    .EXAMPLE
        Find-Certificate -KeyUsage 'DataEncipherment', 'DigitalSignature'

        Return certificate(s) that have specific key usage.

    .EXAMPLE
        Find-Certificate -DNSName 'www.fabrikam.com', 'www.contoso.com'

        Return certificate(s) filtered on specific DNS Names.

    .EXAMPLE
        find-certificate -Subject 'CN=contoso, DC=com'

        Return certificate(s) with specific subject.

    .EXAMPLE
        find-certificate -Issuer 'CN=contoso-ca, DC=com' -AllowExpired $true

        Return all certificates from specific issuer, including expired certificates.

    .EXAMPLE
        Find-Certificate -EnhancedKeyUsage 'Server Authentication' -AllowExpired $true

        Return all certificates that can be used for "Server Authentication", including expired certificates.

    .EXAMPLE
        Find-Certificate -FriendlyName 'My IIS Site SSL Cert'

        Return certificate based on FriendlyName.

#>
function Find-Certificate
{
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2[]])]
    param
    (
        [Parameter()]
        [System.String]
        $Thumbprint,

        [Parameter()]
        [System.String]
        $FriendlyName,

        [Parameter()]
        [System.String]
        $Subject,

        [Parameter()]
        [System.String[]]
        $DNSName,

        [Parameter()]
        [System.String]
        $Issuer,

        [Parameter()]
        [System.String[]]
        $KeyUsage,

        [Parameter()]
        [System.String[]]
        $EnhancedKeyUsage,

        [Parameter()]
        [System.String]
        $Store = 'My',

        [Parameter()]
        [Boolean]
        $AllowExpired = $false
    )

    $certPath = Join-Path -Path 'Cert:\LocalMachine' -ChildPath $Store

    if (-not (Test-Path -Path $certPath))
    {
        # The Certificte Path is not valid
        New-InvalidArgumentException `
            -Message ($script:localizedData.CertificatePathError -f $certPath) `
            -ArgumentName 'Store'
    } # if

    # Assemble the filter to use to select the certificate
    $certFilters = @()

    if ($PSBoundParameters.ContainsKey('Thumbprint'))
    {
        $certFilters += @('($_.Thumbprint -eq $Thumbprint)')
    } # if

    if ($PSBoundParameters.ContainsKey('FriendlyName'))
    {
        $certFilters += @('($_.FriendlyName -eq $FriendlyName)')
    } # if

    if ($PSBoundParameters.ContainsKey('Subject'))
    {
        $certFilters += @('($_.Subject -eq $Subject)')
    } # if

    if ($PSBoundParameters.ContainsKey('Issuer'))
    {
        $certFilters += @('($_.Issuer -eq $Issuer)')
    } # if

    if (-not $AllowExpired)
    {
        $certFilters += @('(((Get-Date) -le $_.NotAfter) -and ((Get-Date) -ge $_.NotBefore))')
    } # if

    if ($PSBoundParameters.ContainsKey('DNSName'))
    {
        $certFilters += @('(@(Compare-Object -ReferenceObject $_.DNSNameList.Unicode -DifferenceObject $DNSName | Where-Object -Property SideIndicator -eq "=>").Count -eq 0)')
    } # if

    if ($PSBoundParameters.ContainsKey('KeyUsage'))
    {
        $certFilters += @('(@(Compare-Object -ReferenceObject ($_.Extensions.KeyUsages -split ", ") -DifferenceObject $KeyUsage | Where-Object -Property SideIndicator -eq "=>").Count -eq 0)')
    } # if

    if ($PSBoundParameters.ContainsKey('EnhancedKeyUsage'))
    {
        $certFilters += @('(@(Compare-Object -ReferenceObject ($_.EnhancedKeyUsageList.FriendlyName) -DifferenceObject $EnhancedKeyUsage | Where-Object -Property SideIndicator -eq "=>").Count -eq 0)')
    } # if

    # Join all the filters together
    $certFilterScript = '(' + ($certFilters -join ' -and ') + ')'

    Write-Verbose `
        -Message ($script:localizedData.SearchingForCertificateUsingFilters -f $store, $certFilterScript) `
        -Verbose

    $certs = Get-ChildItem -Path $certPath |
        Where-Object -FilterScript ([ScriptBlock]::Create($certFilterScript))

    # Sort the certificates
    if ($certs.count -gt 1)
    {
        $certs = $certs | Sort-Object -Descending -Property 'NotAfter'
    } # if

    return $certs
} # end function Find-Certificate
#EndRegion './Public/Find-Certificate.ps1' 190
#Region './Public/Get-ComputerName.ps1' 0
<#
    .SYNOPSIS
        Returns the computer name cross-plattform.

    .DESCRIPTION
        The variable `$env:COMPUTERNAME` does not exist cross-platform which
        hinders development and testing on macOS and Linux. Instead this cmdlet
        can be used to get the computer name cross-plattform.

    .EXAMPLE
        Get-ComputerName

        This example returns the computer name cross-plattform.
#>
function Get-ComputerName
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param ()

    $computerName = $null

    if ($IsLinux -or $IsMacOs)
    {
        $computerName = hostname
    }
    else
    {
        <#
            We could run 'hostname' on Windows too, but $env:COMPUTERNAME
            is more widely used.
        #>
        $computerName = $env:COMPUTERNAME
    }

    return $computerName
}
#EndRegion './Public/Get-ComputerName.ps1' 38
#Region './Public/Get-DscProperty.ps1' 0

<#
    .SYNOPSIS
        Returns DSC resource properties that is part of a class-based DSC resource.

    .DESCRIPTION
        Returns DSC resource properties that is part of a class-based DSC resource.
        The properties can be filtered using name, attribute, or if it has been
        assigned a value.

    .PARAMETER InputObject
        The object that contain one or more key properties.

    .PARAMETER Name
        Specifies one or more property names to return. If left out all properties
        are returned.

    .PARAMETER ExcludeName
        Specifies one or more property names to exclude.

    .PARAMETER Attribute
        Specifies one or more property attributes to return. If left out all property
        types are returned.

    .PARAMETER HasValue
        Specifies to return only properties that has been assigned a non-null value.
        If left out all properties are returned regardless if there is a value
        assigned or not.

    .EXAMPLE
        Get-DscProperty -InputObject $this

        Returns all DSC resource properties of the DSC resource.

    .EXAMPLE
        $this | Get-DscProperty

        Returns all DSC resource properties of the DSC resource.

    .EXAMPLE
        Get-DscProperty -InputObject $this -Name @('MyProperty1', 'MyProperty2')

        Returns the DSC resource properties with the specified names.

    .EXAMPLE
        Get-DscProperty -InputObject $this -Attribute @('Mandatory', 'Optional')

        Returns the DSC resource properties that has the specified attributes.

    .EXAMPLE
        Get-DscProperty -InputObject $this -Attribute @('Optional') -HasValue

        Returns the DSC resource properties that has the specified attributes and
        has a non-null value assigned.

    .OUTPUTS
        [System.Collections.Hashtable]

    .NOTES
        This command only works with nullable data types, if using a non-nullable
        type make sure to make it nullable, e.g. [Nullable[System.Int32]].
#>
function Get-DscProperty
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $InputObject,

        [Parameter()]
        [System.String[]]
        $Name,

        [Parameter()]
        [System.String[]]
        $ExcludeName,

        [Parameter()]
        [ValidateSet('Key', 'Mandatory', 'NotConfigurable', 'Optional')]
        [Alias('Type')]
        [System.String[]]
        $Attribute,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $HasValue
    )

    process
    {
        $property = $InputObject.PSObject.Properties.Name |
            Where-Object -FilterScript {
                <#
                    Return all properties if $Name is not assigned, or if assigned
                    just those properties.
                #>
                (-not $Name -or $_ -in $Name) -and

                <#
                    Return all properties if $ExcludeName is not assigned. Skip
                    property if it is included in $ExcludeName.
                #>
                (-not $ExcludeName -or ($_ -notin $ExcludeName)) -and

                # Only return the property if it is a DSC property.
                $InputObject.GetType().GetMember($_).CustomAttributes.Where(
                    {
                        $_.AttributeType.Name -eq 'DscPropertyAttribute'
                    }
                )
            }

        if (-not [System.String]::IsNullOrEmpty($property))
        {
            if ($PSBoundParameters.ContainsKey('Attribute'))
            {
                $propertiesOfAttribute = @()

                $propertiesOfAttribute += $property | Where-Object -FilterScript {
                    $InputObject.GetType().GetMember($_).CustomAttributes.Where(
                        {
                            <#
                                To simplify the code, ignoring that this will compare
                                MemberNAme against type 'Optional' which does not exist.
                            #>
                            $_.NamedArguments.MemberName -in $Attribute
                        }
                    ).NamedArguments.TypedValue.Value -eq $true
                }

                # Include all optional parameter if it was requested.
                if ($Attribute -contains 'Optional')
                {
                    $propertiesOfAttribute += $property | Where-Object -FilterScript {
                        $InputObject.GetType().GetMember($_).CustomAttributes.Where(
                            {
                                $_.NamedArguments.MemberName -notin @('Key', 'Mandatory', 'NotConfigurable')
                            }
                        )
                    }
                }

                $property = $propertiesOfAttribute
            }
        }

        # Return a hashtable containing each key property and its value.
        $getPropertyResult = @{}

        foreach ($currentProperty in $property)
        {
            if ($HasValue.IsPresent)
            {
                $isAssigned = Test-DscPropertyIsAssigned -Name $currentProperty -InputObject $InputObject

                if (-not $isAssigned)
                {
                    continue
                }
            }

            $getPropertyResult.$currentProperty = $InputObject.$currentProperty
        }

        return $getPropertyResult
    }
}
#EndRegion './Public/Get-DscProperty.ps1' 171
#Region './Public/Get-EnvironmentVariable.ps1' 0

<#
    .SYNOPSIS
        Returns the value from an environment variable from a specified target.

    .DESCRIPTION
        Returns the value from an environment variable from a specified target.

    .PARAMETER Name
        Specifies the environment variable name.

    .PARAMETER FromTarget
        Specifies the target to return the value from. Defaults to 'Session'.

    .EXAMPLE
        Get-EnvironmentVariable -Name 'PSModulePath'

        Returns the value for the environment variable PSModulePath.

    .EXAMPLE
        Get-EnvironmentVariable -Name 'PSModulePath' -FromTarget 'Machine'

        Returns the value for the environment variable PSModulePath from the
        Machine target.

    .OUTPUTS
        [System.String]
#>
function Get-EnvironmentVariable
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('Session', 'User', 'Machine')]
        [System.String]
        $FromTarget = 'Session'
    )

    switch ($FromTarget)
    {
        'Session'
        {
            $value = [System.Environment]::GetEnvironmentVariable($Name)
        }

        'User'
        {
            $value = [System.Environment]::GetEnvironmentVariable($Name, 'User')
        }

        'Machine'
        {
            $value = [System.Environment]::GetEnvironmentVariable($Name, 'Machine')
        }
    }

    return $value
}
#EndRegion './Public/Get-EnvironmentVariable.ps1' 65
#Region './Public/Get-LocalizedData.ps1' 0

<#
    .SYNOPSIS
        Gets language-specific data into scripts and functions based on the UI culture
        that is selected for the operating system.
        Similar to Import-LocalizedData, with extra parameter 'DefaultUICulture'.

    .DESCRIPTION
        The Get-LocalizedData cmdlet dynamically retrieves strings from a subdirectory
        whose name matches the UI language set for the current user of the operating system.
        It is designed to enable scripts to display user messages in the UI language selected
        by the current user.

        Get-LocalizedData imports data from .psd1 files in language-specific subdirectories
        of the script directory and saves them in a local variable that is specified in the
        command. The cmdlet selects the subdirectory and file based on the value of the
        $PSUICulture automatic variable. When you use the local variable in the script to
        display a user message, the message appears in the user's UI language.

        You can use the parameters of G-LocalizedData to specify an alternate UI culture,
        path, and file name, to add supported commands, and to suppress the error message that
        appears if the .psd1 files are not found.

        The G-LocalizedData cmdlet supports the script internationalization
        initiative that was introduced in Windows PowerShell 2.0. This initiative
        aims to better serve users worldwide by making it easy for scripts to display
        user messages in the UI language of the current user. For more information
        about this and about the format of the .psd1 files, see about_Script_Internationalization.

    .PARAMETER BindingVariable
        Specifies the variable into which the text strings are imported. Enter a variable
        name without a dollar sign ($).

        In Windows PowerShell 2.0, this parameter is required. In Windows PowerShell 3.0,
        this parameter is optional. If you omit this parameter, Import-LocalizedData
        returns a hash table of the text strings. The hash table is passed down the pipeline
        or displayed at the command line.

        When using Import-LocalizedData to replace default text strings specified in the
        DATA section of a script, assign the DATA section to a variable and enter the name
        of the DATA section variable in the value of the BindingVariable parameter. Then,
        when Import-LocalizedData saves the imported content in the BindingVariable, the
        imported data will replace the default text strings. If you are not specifying
        default text strings, you can select any variable name.

    .PARAMETER UICulture
        Specifies an alternate UI culture. The default is the value of the $PsUICulture
        automatic variable. Enter a UI culture in <language>-<region> format, such as
        en-US, de-DE, or ar-SA.

        The value of the UICulture parameter determines the language-specific subdirectory
        (within the base directory) from which Import-LocalizedData gets the .psd1 file
        for the script.

        The cmdlet searches for a subdirectory with the same name as the value of the
        UICulture parameter or the $PsUICulture automatic variable, such as de-DE or
        ar-SA. If it cannot find the directory, or the directory does not contain a .psd1
        file for the script, it searches for a subdirectory with the name of the language
        code, such as de or ar. If it cannot find the subdirectory or .psd1 file, the
        command fails and the data is displayed in the default language specified in the
        script.

    .PARAMETER BaseDirectory
        Specifies the base directory where the .psd1 files are located. The default is
        the directory where the script is located. Import-LocalizedData searches for
        the .psd1 file for the script in a language-specific subdirectory of the base
        directory.

    .PARAMETER FileName
        Specifies the name of the data file (.psd1) to be imported. Enter a file name.
        You can specify a file name that does not include its .psd1 file name extension,
        or you can specify the file name including the .psd1 file name extension.

        The FileName parameter is required when Import-LocalizedData is not used in a
        script. Otherwise, the parameter is optional and the default value is the base
        name of the script. You can use this parameter to direct Import-LocalizedData
        to search for a different .psd1 file.

        For example, if the FileName is omitted and the script name is FindFiles.ps1,
        Import-LocalizedData searches for the FindFiles.psd1 data file.

    .PARAMETER SupportedCommand
        Specifies cmdlets and functions that generate only data.

        Use this parameter to include cmdlets and functions that you have written or
        tested. For more information, see about_Script_Internationalization.

    .PARAMETER DefaultUICulture
        Specifies which UICulture to default to if current UI culture or its parents
        culture don't have matching data file.

        For example, if you have a data file in 'en-US' but not in 'en' or 'en-GB' and
        your current culture is 'en-GB', you can default back to 'en-US'.

    .NOTES
        Before using Import-LocalizedData, localize your user messages. Format the messages
        for each locale (UI culture) in a hash table of key/value pairs, and save the
        hash table in a file with the same name as the script and a .psd1 file name extension.
        Create a directory under the script directory for each supported UI culture, and
        then save the .psd1 file for each UI culture in the directory with the UI
        culture name.

        For example, localize your user messages for the de-DE locale and format them in
        a hash table. Save the hash table in a <ScriptName>.psd1 file. Then create a de-DE
        subdirectory under the script directory, and save the de-DE <ScriptName>.psd1
        file in the de-DE subdirectory. Repeat this method for each locale that you support.

        Import-LocalizedData performs a structured search for the localized user
        messages for a script.

        Import-LocalizedData begins the search in the directory where the script file
        is located (or the value of the BaseDirectory parameter). It then searches within
        the base directory for a subdirectory with the same name as the value of the
        $PsUICulture variable (or the value of the UICulture parameter), such as de-DE or
        ar-SA. Then, it searches in that subdirectory for a .psd1 file with the same name
        as the script (or the value of the FileName parameter).

        If Import-LocalizedData cannot find a subdirectory with the name of the UI culture,
        or the subdirectory does not contain a .psd1 file for the script, it searches for
        a .psd1 file for the script in a subdirectory with the name of the language code,
        such as de or ar. If it cannot find the subdirectory or .psd1 file, the command
        fails, the data is displayed in the default language in the script, and an error
        message is displayed explaining that the data could not be imported. To suppress
        the message and fail gracefully, use the ErrorAction common parameter with a value
        of SilentlyContinue.

        If Import-LocalizedData finds the subdirectory and the .psd1 file, it imports the
        hash table of user messages into the value of the BindingVariable parameter in the
        command. Then, when you display a message from the hash table in the variable, the
        localized message is displayed.

        For more information, see about_Script_Internationalization.

    .EXAMPLE
        $script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

        This is an example that can be used in DSC resources to import the
        localized strings and if the current UI culture localized folder does
        not exist the UI culture 'en-US' is returned.
#>
function Get-LocalizedData
{
    [CmdletBinding(DefaultParameterSetName = 'DefaultUICulture')]
    param
    (
        [Parameter(Position = 0)]
        [Alias('Variable')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $BindingVariable,

        [Parameter(Position = 1, ParameterSetName = 'TargetedUICulture')]
        [System.String]
        $UICulture,

        [Parameter()]
        [System.String]
        $BaseDirectory,

        [Parameter()]
        [System.String]
        $FileName,

        [Parameter()]
        [System.String[]]
        $SupportedCommand,

        [Parameter(Position = 1, ParameterSetName = 'DefaultUICulture')]
        [System.String]
        $DefaultUICulture = 'en-US'
    )

    begin
    {
        <#
            Because Proxy Command changes the Invocation origin, we need to be explicit
            when handing the pipeline back to original command.
        #>
        if ($PSBoundParameters.ContainsKey('FileName'))
        {
            Write-Debug -Message ('Looking for provided file with base name: ''{0}''.' -f $FileName)
        }
        else
        {
            if ($myInvocation.ScriptName)
            {
                $file = [System.IO.FileInfo] $myInvocation.ScriptName
            }
            else
            {
                $file = [System.IO.FileInfo] $myInvocation.MyCommand.Module.Path
            }

            $FileName = $file.BaseName

            $PSBoundParameters.Add('FileName', $file.Name)
            Write-Debug -Message ('Looking for resolved file with base name: ''{0}''.' -f $FileName)
        }

        if ($PSBoundParameters.ContainsKey('BaseDirectory'))
        {
            $callingScriptRoot = $BaseDirectory
        }
        else
        {
            $callingScriptRoot = $MyInvocation.PSScriptRoot
            $PSBoundParameters.Add('BaseDirectory', $callingScriptRoot)
        }

        # If we're not looking for a specific UICulture, but looking for current culture, one of its parent, or the default.
        if (-not $PSBoundParameters.ContainsKey('UICulture') -and $PSBoundParameters.ContainsKey('DefaultUICulture'))
        {
            <#
                We don't want the resolution to eventually return the ModuleManifest
                so we run the same GetFilePath() logic than here:
                https://github.com/PowerShell/PowerShell/blob/master/src/Microsoft.PowerShell.Commands.Utility/commands/utility/Import-LocalizedData.cs#L302-L333
                and if we see it will return the wrong thing, set the UICulture to DefaultUI culture, and return the logic to Import-LocalizedData.

                If the LCID is 127 (invariant) then use default UI culture anyway.
                If we can't create the CultureInfo object, it's probably because the Globalization-invariant mode is enabled for the DotNet runtime (breaking change in .Net)
                See more information in issue https://github.com/dsccommunity/DscResource.Common/issues/11.
                https://docs.microsoft.com/en-us/dotnet/core/compatibility/globalization/6.0/culture-creation-invariant-mode
            #>

            $currentCulture = Get-UICulture
            $evaluateDefaultCulture = $true

            if ($currentCulture.LCID -eq 127)
            {
                try
                {
                    # Current culture is invariant, let's directly evaluate the DefaultUICulture
                    $currentCulture = New-Object -TypeName 'System.Globalization.CultureInfo' -ArgumentList @($DefaultUICulture)
                    # No need to evaluate the DefaultUICulture later, as we'll start with this (in the while loop below)
                    $evaluateDefaultCulture = $false
                }
                catch
                {
                    Write-Debug -Message 'The Globalization-Invariant mode is enabled, only the Invariant Culture is allowed.'
                    # The code will now skip to the InvokeCommand part and execute the Get-LocalizedDataForInvariantCulture
                }

                $PSBoundParameters['UICulture'] = $DefaultUICulture
            }

            [string] $languageFile = ''
            [string[]] $localizedFileNamesToTry = @(
                ('{0}.psd1' -f $FileName)
                ('{0}.strings.psd1' -f $FileName)
            )

            while (-not [string]::IsNullOrEmpty($currentCulture.Name) -and [String]::IsNullOrEmpty($languageFile))
            {
                Write-Debug -Message ('Looking for Localized data file using the current culture ''{0}''.' -f $currentCulture.Name)
                foreach ($localizedFileName in $localizedFileNamesToTry)
                {
                    $filePath = [System.IO.Path]::Combine($callingScriptRoot, $CurrentCulture.Name, $localizedFileName)
                    if (Test-Path -Path $filePath)
                    {
                        Write-Debug -Message "Found '$filePath'."
                        $languageFile = $filePath
                        # Set the filename to the file we found.
                        $PSBoundParameters['FileName'] = $localizedFileName
                        # Exit loop if as we found the first filename.
                        break
                    }
                    else
                    {
                        Write-Debug -Message "File '$filePath' not found."
                    }
                }

                if ([String]::IsNullOrEmpty($languageFile))
                {
                    <#
                        Evaluate the parent culture if there is a valid one (not Invariant).

                        If the parent culture is LCID 127 then move to the default culture.
                        See more information in issue https://github.com/dsccommunity/DscResource.Common/issues/11.
                    #>
                    if ($currentCulture.Parent -and [string]$currentCulture.Parent.Name)
                    {
                        $currentCulture = $currentCulture.Parent
                    }
                    else
                    {
                        if ($evaluateDefaultCulture)
                        {
                            $evaluateDefaultCulture = $false

                            <#
                                Could not find localized strings file for the the operating
                                system UI culture. Evaluating the default UI culture (which
                                defaults to 'en-US' if not specifically set).
                            #>
                            try
                            {
                                $currentCulture = New-Object -TypeName 'System.Globalization.CultureInfo' -ArgumentList @($DefaultUICulture)
                            }
                            catch
                            {
                                Write-Debug -Message ('Unable to create the Default UI Culture [CultureInfo] object, most likely due to invariant mode being enabled.')
                                $currentCulture = Get-UICulture
                                # We already tried everything we could, exit the while loop and hand over to Import-LocalizedData or Get-LocalizedDataForInvariantCultureMode
                                break
                            }

                            $PSBoundParameters['UICulture'] = $DefaultUICulture
                        }
                        else
                        {
                            <#
                                Already evaluated everything we could, exit and let
                                Import-LocalizedData throw an exception.
                            #>
                            break
                        }
                    }
                }
            }

            <#
                Removes the parameter DefaultUICulture so that isn't used when
                calling Import-LocalizedData.
            #>
            $null = $PSBoundParameters.Remove('DefaultUICulture')
        }

        try
        {
            $outBuffer = $null

            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref] $outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }

            if ($currentCulture.LCID -eq 127)
            {
                # Culture is invariant, working around issue with Import-LocalizedData when pwsh configured as invariant
                $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Get-LocalizedDataForInvariantCulture', [System.Management.Automation.CommandTypes]::Function)
                $PSBoundParameters.Keys.ForEach({
                    if ($_ -notin $wrappedCmd.Parameters.Keys)
                    {
                        $PSBoundParameters.Remove($_)
                    }
                })

                $scriptCmd = { & $wrappedCmd @PSBoundParameters }
            }
            else
            {
                <# Action when all if and elseif conditions are false #>
                $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Import-LocalizedData', [System.Management.Automation.CommandTypes]::Cmdlet)
                $scriptCmd = { & $wrappedCmd @PSBoundParameters }
            }

            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        }
        catch
        {
            throw
        }
    }

    process
    {
        try
        {
            $steppablePipeline.Process($_)
        }
        catch
        {
            throw
        }
    }

    end
    {
        if ($BindingVariable -and ($valueToBind = Get-Variable -Name $BindingVariable -ValueOnly -ErrorAction 'Ignore'))
        {
            # Bringing the variable to the parent scope
            Set-Variable -Scope 1 -Name $BindingVariable -Force -ErrorAction 'SilentlyContinue' -Value $valueToBind
        }

        try
        {
            $steppablePipeline.End()
        }
        catch
        {
            throw
        }
    }
}
#EndRegion './Public/Get-LocalizedData.ps1' 397
#Region './Public/Get-LocalizedDataForInvariantCulture.ps1' 0

<#
    .SYNOPSIS
        Gets language-specific data when the culture is invariant.
        This directly gets the data from the DefaultUICulture, but without calling
        "Import-LocalizedData" which throws when the pwsh session is configured to be
        of invariant culture (as in the Guest Config agent).

    .DESCRIPTION
        The Get-LocalizedDataForInvariantCulture grabs the data from a localized string data psd1 file,
        without calling Import-LocalizedData which errors when called in a powershell session with the
        Globalization-Invariant mode enabled
        (https://docs.microsoft.com/en-us/dotnet/core/compatibility/globalization/6.0/culture-creation-invariant-mode).

        Instead, this function reads and executes the content of a psd1 file in a
        constrained language mode that only allows basic ConvertFrom-stringData.

    .PARAMETER BaseDirectory
        Specifies the base directory where the .psd1 files are located. The default is
        the directory where the script is located. Import-LocalizedData searches for
        the .psd1 file for the script in a language-specific subdirectory of the base
        directory.

    .PARAMETER FileName
        Specifies the base name of the data file (.psd1) to be imported. Enter a file name.
        You can specify a file name that does not include its .psd1 file name extension,
        or you can specify the file name including the .psd1 file name extension.

        The FileName parameter is required when Get-LocalizedDataForInvariantCulture is not used in a
        script. Otherwise, the parameter is optional and the default value is the base
        name of the calling script. You can use this parameter to directly search for a
        specific .psd1 file.

        For example, if the FileName is omitted and the script name is FindFiles.ps1,
        Get-LocalizedDataForInvariantCulture searches for the FindFiles.psd1 or
        FindFiles.strings.psd1 data file.

    .PARAMETER SupportedCommand
        Specifies cmdlets and functions that generate only data.

        Use this parameter to include cmdlets and functions that you have written or
        tested. For more information, see about_Script_Internationalization.

    .PARAMETER DefaultUICulture
        Specifies which UICulture to default to if current UI culture or its parents
        culture don't have matching data file.

        For example, if you have a data file in 'en-US' but not in 'en' or 'en-GB' and
        your current culture is 'en-GB', you can default back to 'en-US'.

    .NOTES
        The Get-LocalizedDataForInvariantCulture should only be used when we want to avoid
        using Import-LocalizedData, such as when doing so will fail because the powershell session
        is in Globalization-Invariant mode:
        https://docs.microsoft.com/en-us/dotnet/core/compatibility/globalization/6.0/culture-creation-invariant-mode

        Before using Get-LocalizedDataForInvariantCulture, localize your user messages to the desired
        default locale (UI culture, usually en-US) in a hash table of key/value pairs, and save the
        hash table in a file with the same name as the script or module with a .psd1 file name extension.
        Create a directory under the module base or script's parent directory for each supported UI culture,
        and then save the .psd1 file for each UI culture in the directory with the UI culture name.

        For example, localize your user messages for the de-DE locale and format them in
        a hash table. Save the hash table in a <ScriptName>.psd1 file. Then create a de-DE
        subdirectory under the script directory, and save the de-DE <ScriptName>.psd1
        file in the de-DE subdirectory. Repeat this method for each locale that you support.

        Import-LocalizedData performs a structured search for the localized user
        messages for a script.

        Get-LocalizedDataForInvariantCulture only search in the BaseDirectory specified.
        It then searches within the base directory for a subdirectory with the same name
        as the value of the $DefaultUICulture variable (specified or default to en-US),
        such as de-DE or ar-SA.
        Then, it searches in that subdirectory for a .psd1 file with the same name
        as provided FileName such as FileName.psd1 or FileName.strings.psd1.

    .EXAMPLE
        Get-LocalizedDataForInvariantCulture -BaseDirectory .\source\ -FileName DscResource.Common -DefaultUICulture en-US

        This is an example, usually it is only used by Get-LocalizedData in DSC resources to import the
        localized strings when the Culture is Invariant (id 127).
#>
function Get-LocalizedDataForInvariantCulture
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $BaseDirectory,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [System.String]
        $FileName,

        [Parameter()]
        [System.String]
        [ValidateNotNull()]
        $DefaultUICulture = 'en-US'
    )

    begin
    {
        if ($FileName -match '\.psm1$|\.ps1$|\.psd1$')
        {
            Write-Debug -Message 'Found an extension to the file name to search. Stripping...'
            $FileName = $FileName -replace '\.psm1$|\.ps1$|\.psd1$'
        }

        [string] $languageFile = ''
        $localizedFolder = Join-Path -Path $BaseDirectory -ChildPath $DefaultUICulture
        [string[]] $localizedFileNamesToTry = @(
            ('{0}.psd1' -f $FileName)
            ('{0}.strings.psd1' -f $FileName)
        )

        foreach ($localizedFileName in $localizedFileNamesToTry)
        {
            $filePath = [System.IO.Path]::Combine($localizedFolder, $localizedFileName)
            if (Test-Path -Path $filePath)
            {
                Write-Debug -Message "Found '$filePath'."
                $languageFile = $filePath
                # Exit loop as we found the first filename.
                break
            }
            else
            {
                Write-Debug -Message "File '$filePath' not found."
            }
        }

        if ([string]::IsNullOrEmpty($languageFile))
        {
            throw ('File ''{0}'' not found in ''{1}''.' -f ($localizedFileNamesToTry -join ','),$localizedFolder)
        }
        else
        {
            Write-Verbose -Message ('Getting file {0}' -f $languageFile)
        }

        $constrainedState = [System.Management.Automation.Runspaces.InitialSessionState]::Create()

        if (!$IsCoreCLR)
        {
            $constrainedState.ApartmentState = [System.Threading.ApartmentState]::STA
        }

        $constrainedState.LanguageMode = [System.Management.Automation.PSLanguageMode]::ConstrainedLanguage
        $constrainedState.DisableFormatUpdates = $true

        $sspe = New-Object System.Management.Automation.Runspaces.SessionStateProviderEntry 'Environment',([Microsoft.PowerShell.Commands.EnvironmentProvider]),$null
        $constrainedState.Providers.Add($sspe)

        $sspe = New-Object System.Management.Automation.Runspaces.SessionStateProviderEntry 'FileSystem',([Microsoft.PowerShell.Commands.FileSystemProvider]),$null
        $constrainedState.Providers.Add($sspe)

        $ssce = New-Object System.Management.Automation.Runspaces.SessionStateCmdletEntry 'Get-Content',([Microsoft.PowerShell.Commands.GetContentCommand]),$null
        $constrainedState.Commands.Add($ssce)

        $ssce = New-Object System.Management.Automation.Runspaces.SessionStateCmdletEntry 'Get-Date',([Microsoft.PowerShell.Commands.GetDateCommand]),$null
        $constrainedState.Commands.Add($ssce)

        $ssce = New-Object System.Management.Automation.Runspaces.SessionStateCmdletEntry 'Get-ChildItem',([Microsoft.PowerShell.Commands.GetChildItemCommand]),$null
        $constrainedState.Commands.Add($ssce)

        $ssce = New-Object System.Management.Automation.Runspaces.SessionStateCmdletEntry 'Get-Item',([Microsoft.PowerShell.Commands.GetItemCommand]),$null
        $constrainedState.Commands.Add($ssce)

        $ssce = New-Object System.Management.Automation.Runspaces.SessionStateCmdletEntry 'Test-Path',([Microsoft.PowerShell.Commands.TestPathCommand]),$null
        $constrainedState.Commands.Add($ssce)

        $ssce = New-Object System.Management.Automation.Runspaces.SessionStateCmdletEntry 'Out-String',([Microsoft.PowerShell.Commands.OutStringCommand]),$null
        $constrainedState.Commands.Add($ssce)

        $ssce = New-Object System.Management.Automation.Runspaces.SessionStateCmdletEntry 'ConvertFrom-StringData',([Microsoft.PowerShell.Commands.ConvertFromStringDataCommand]),$null
        $constrainedState.Commands.Add($ssce)

        # $scopedItemOptions = [System.Management.Automation.ScopedItemOptions]::AllScope

        # Create new runspace with the above defined entries. Then open and set its working dir to $destinationAbsolutePath
        # so all condition attribute expressions can use a relative path to refer to file paths e.g.
        # condition="Test-Path src\${PLASTER_PARAM_ModuleName}.psm1"
        $constrainedRunspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($constrainedState)
        $constrainedRunspace.Open()
        $destinationAbsolutePath = (Get-Item -Path $BaseDirectory -ErrorAction Stop).FullName
        $null = $constrainedRunspace.SessionStateProxy.Path.SetLocation($destinationAbsolutePath)
    }

    process
    {
        try
        {
            $powershell = [PowerShell]::Create()
            $powershell.Runspace = $constrainedRunspace
            $expression = Get-Content -Raw -Path $languageFile
            try
            {
                $null = $powershell.AddScript($expression)
                $powershell.Invoke()
            }
            catch
            {
                throw $_
            }

            # Check for non-terminating errors.
            if ($powershell.Streams.Error.Count -gt 0)
            {
                $powershell.Streams.Error.ForEach({
                    Write-Error $_
                })
            }
        }
        finally
        {
            if ($powershell)
            {
                $powershell.Dispose()
            }
        }
    }

    end
    {
        $constrainedRunspace.Dispose()
    }
}
#EndRegion './Public/Get-LocalizedDataForInvariantCulture.ps1' 230
#Region './Public/Get-PSModulePath.ps1' 0

<#
    .SYNOPSIS
        Returns the environment variable PSModulePath from the specified target.

    .DESCRIPTION
        Returns the environment variable PSModulePath from the specified target.
        If more than one target is provided the return will contain all the
        concatenation of all unique paths from the targets.

    .PARAMETER FromTarget
        Specifies the target to get the PSModulePath from.

    .EXAMPLE
        Get-PSModulePath -FromTarget 'Session'

        Returns the paths from the Session target.

    .EXAMPLE
        Get-PSModulePath -FromTarget 'Session', 'User', 'Machine'

        Returns the unique paths from the all targets.

    .OUTPUTS
        [System.String]

        If there are no paths to return the command will return an empty string.
#>
function Get-PSModulePath
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Session', 'User', 'Machine')]
        [System.String[]]
        $FromTarget
    )

    $modulePathSession = $modulePathUser = $modulePathMachine = $null

    <#
        Get the environment variables from required targets. The value returned
        is cast to System.String to convert $null values to empty string.
    #>
    switch ($FromTarget)
    {
        'Session'
        {
            $modulePathSession = Get-EnvironmentVariable -Name 'PSModulePath'
        }

        'User'
        {
            $modulePathUser = Get-EnvironmentVariable -Name 'PSModulePath' -FromTarget 'User'
        }

        'Machine'
        {
            $modulePathMachine = Get-EnvironmentVariable -Name 'PSModulePath' -FromTarget 'Machine'
        }
    }

    $modulePath = $modulePathSession, $modulePathUser, $modulePathMachine -join ';'

    $modulePathArray = $modulePath -split ';' |
        Where-Object -FilterScript {
            -not [System.String]::IsNullOrEmpty($_)
        } |
        Sort-Object -Unique

    $modulePath = $modulePathArray -join ';'

    return $modulePath
}
#EndRegion './Public/Get-PSModulePath.ps1' 77
#Region './Public/Get-TemporaryFolder.ps1' 0
<#
    .SYNOPSIS
        Returns the path of the current user's temporary folder.

    .DESCRIPTION
        Returns the path of the current user's temporary folder.

    .NOTES
        This is the same as doing the following
        - Windows: $env:TEMP
        - macOS: $env:TMPDIR
        - Linux: /tmp/

    .EXAMPLE
        Get-TemporaryFolder

        Returns the current user temporary folder on the current operating system.
#>
function Get-TemporaryFolder
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param ()

    return [IO.Path]::GetTempPath()
}
#EndRegion './Public/Get-TemporaryFolder.ps1' 27
#Region './Public/New-InvalidArgumentException.ps1' 0
<#
    .SYNOPSIS
        Creates and throws an invalid argument exception.

    .DESCRIPTION
        Creates and throws an invalid argument exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ArgumentName
        The name of the invalid argument that is causing this error to be thrown.

    .EXAMPLE
        $errorMessage = $script:localizedData.ActionCannotBeUsedInThisContextMessage `
                -f $Action, $Parameter

        New-InvalidArgumentException -ArgumentName 'Action' -Message $errorMessage
#>
function New-InvalidArgumentException
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ArgumentName
    )

    $argumentException = New-Object -TypeName 'ArgumentException' `
        -ArgumentList @($Message, $ArgumentName)

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @($argumentException, $ArgumentName, 'InvalidArgument', $null)
    }

    $errorRecord = New-Object @newObjectParameters

    throw $errorRecord
}
#EndRegion './Public/New-InvalidArgumentException.ps1' 49
#Region './Public/New-InvalidDataException.ps1' 0
<#
    .SYNOPSIS
        Creates and throws an invalid data exception.

    .DESCRIPTION
        Creates and throws an invalid data exception.

    .PARAMETER ErrorId
        The error Id to assign to the exception.

    .PARAMETER ErrorMessage
        The error message to assign to the exception.

    .EXAMPLE
        if ( -not $resultOfEvaluation )
        {
            $errorMessage = $script:localizedData.InvalidData -f $Action

            New-InvalidDataException -ErrorId 'InvalidDataError' -ErrorMessage $errorMessage
        }
#>
function New-InvalidDataException
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ErrorId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ErrorMessage
    )

    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidData
    $exception = New-Object `
        -TypeName System.InvalidOperationException `
        -ArgumentList $ErrorMessage
    $errorRecord = New-Object `
        -TypeName System.Management.Automation.ErrorRecord `
        -ArgumentList $exception, $ErrorId, $errorCategory, $null

    throw $errorRecord
}
#EndRegion './Public/New-InvalidDataException.ps1' 47
#Region './Public/New-InvalidOperationException.ps1' 0
<#
    .SYNOPSIS
        Creates and throws an invalid operation exception.

    .DESCRIPTION
        Creates and throws an invalid operation exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.

    .EXAMPLE
        try
        {
            Start-Process @startProcessArguments
        }
        catch
        {
            $errorMessage = $script:localizedData.InstallationFailedMessage -f $Path, $processId
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
#>
function New-InvalidOperationException
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException' `
            -ArgumentList @($Message)
    }
    else
    {
        $invalidOperationException = New-Object -TypeName 'InvalidOperationException' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $invalidOperationException.ToString(),
            'MachineStateIncorrect',
            'InvalidOperation',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}
#EndRegion './Public/New-InvalidOperationException.ps1' 67
#Region './Public/New-InvalidResultException.ps1' 0
<#
    .SYNOPSIS
        Creates and throws an invalid result exception.

    .DESCRIPTION
        Creates and throws an invalid result exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.

    .EXAMPLE
        try
        {
            $numberOfObjects = Get-ChildItem -Path $path
            if ($numberOfObjects -eq 0)
            {
                throw 'To few files.'
            }
        }
        catch
        {
            $errorMessage = $script:localizedData.TooFewFilesMessage -f $path
            New-InvalidResultException -Message $errorMessage -ErrorRecord $_
        }
#>
function New-InvalidResultException
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message)
    }
    else
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $exception.ToString(),
            'MachineStateIncorrect',
            'InvalidResult',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}
#EndRegion './Public/New-InvalidResultException.ps1' 71
#Region './Public/New-NotImplementedException.ps1' 0
<#
    .SYNOPSIS
        Creates and throws an not implemented exception.

    .DESCRIPTION
        Creates and throws an not implemented exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.

    .EXAMPLE
        if ($runFeature)
        {
            $errorMessage = $script:localizedData.FeatureMissing -f $path
            New-NotImplementedException -Message $errorMessage -ErrorRecord $_
        }

        Throws an not implemented exception if the variable $runFeature contains
        a value.
#>
function New-NotImplementedException
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $invalidOperationException = New-Object -TypeName 'NotImplementedException' `
            -ArgumentList @($Message)
    }
    else
    {
        $invalidOperationException = New-Object -TypeName 'NotImplementedException' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $invalidOperationException.ToString(),
            'MachineStateIncorrect',
            'NotImplemented',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}
#EndRegion './Public/New-NotImplementedException.ps1' 66
#Region './Public/New-ObjectNotFoundException.ps1' 0

<#
    .SYNOPSIS
        Creates and throws an object not found exception.

    .DESCRIPTION
        Creates and throws an object not found exception.

    .PARAMETER Message
        The message explaining why this error is being thrown.

    .PARAMETER ErrorRecord
        The error record containing the exception that is causing this terminating error.

    .EXAMPLE
        try
        {
            Get-ChildItem -Path $path
        }
        catch
        {
            $errorMessage = $script:localizedData.PathNotFoundMessage -f $path
            New-ObjectNotFoundException -Message $errorMessage -ErrorRecord $_
        }
#>
function New-ObjectNotFoundException
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,

        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($null -eq $ErrorRecord)
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message)
    }
    else
    {
        $exception = New-Object -TypeName 'System.Exception' `
            -ArgumentList @($Message, $ErrorRecord.Exception)
    }

    $newObjectParameters = @{
        TypeName     = 'System.Management.Automation.ErrorRecord'
        ArgumentList = @(
            $exception.ToString(),
            'MachineStateIncorrect',
            'ObjectNotFound',
            $null
        )
    }

    $errorRecordToThrow = New-Object @newObjectParameters

    throw $errorRecordToThrow
}
#EndRegion './Public/New-ObjectNotFoundException.ps1' 68
#Region './Public/Remove-CommonParameter.ps1' 0
<#
    .SYNOPSIS
        Removes common parameters from a hashtable.

    .DESCRIPTION
        This function serves the purpose of removing common parameters and option
        common parameters from a parameter hashtable.

    .PARAMETER Hashtable
        The parameter hashtable that should be pruned.

    .EXAMPLE
        Remove-CommonParameter -Hashtable $PSBoundParameters

        Returns a new hashtable without the common and optional common parameters.
#>
function Remove-CommonParameter
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'ShouldProcess is not supported in DSC resources.'
    )]
    [OutputType([System.Collections.Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $Hashtable
    )

    $inputClone = $Hashtable.Clone()

    $commonParameters = [System.Management.Automation.PSCmdlet]::CommonParameters
    $commonParameters += [System.Management.Automation.PSCmdlet]::OptionalCommonParameters

    $Hashtable.Keys | Where-Object -FilterScript {
        $_ -in $commonParameters
    } | ForEach-Object -Process {
        $inputClone.Remove($_)
    }

    return $inputClone
}
#EndRegion './Public/Remove-CommonParameter.ps1' 46
#Region './Public/Set-DscMachineRebootRequired.ps1' 0
<#
    .SYNOPSIS
        Set the DSC reboot required status variable.

    .DESCRIPTION
        Sets the global DSCMachineStatus variable to a value of 1.
        This function is used to set the global variable that indicates
        to the LCM that a reboot of the node is required.

    .EXAMPLE
        PS C:\> Set-DscMachineRebootRequired

        Sets the $global:DSCMachineStatus variable to 1.

    .NOTES
        This function is implemented so that individual resource modules
        do not need to use and therefore suppress Global variables
        directly. It also enables mocking to increase testability of
        consumers.
#>
function Set-DscMachineRebootRequired
{
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    # Suppressing this rule because $global:DSCMachineStatus is used to trigger a reboot.
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
    <#
        Suppressing this rule because $global:DSCMachineStatus is only set,
        never used (by design of Desired State Configuration).
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    [CmdletBinding()]
    param
    (
    )

    $global:DSCMachineStatus = 1
}
#EndRegion './Public/Set-DscMachineRebootRequired.ps1' 38
#Region './Public/Set-PSModulePath.ps1' 0

<#
    .SYNOPSIS
        Set environment variable PSModulePath in the current session or machine
        wide.

    .DESCRIPTION
        This is a wrapper to set environment variable PSModulePath in current
        session or machine wide.

    .PARAMETER Path
        A string with all the paths separated by semi-colons.

    .PARAMETER Machine
        If set the PSModulePath will be changed machine wide. If not set, only
        the current session will be changed.

    .EXAMPLE
        Set-PSModulePath -Path '<Path 1>;<Path 2>'

    .EXAMPLE
        Set-PSModulePath -Path '<Path 1>;<Path 2>' -Machine
#>
function Set-PSModulePath
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'ShouldProcess is not supported in DSC resources.'
    )]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Machine
    )

    if ($Machine.IsPresent)
    {
        [System.Environment]::SetEnvironmentVariable('PSModulePath', $Path, [System.EnvironmentVariableTarget]::Machine)
    }
    else
    {
        $env:PSModulePath = $Path
    }
}
#EndRegion './Public/Set-PSModulePath.ps1' 53
#Region './Public/Test-AccountRequirePassword.ps1' 0
<#
    .SYNOPSIS
        Returns whether the specified account require a password to be provided.

    .DESCRIPTION
        Returns whether the specified account require a password to be provided.
        If the account is a (global) managed service account, virtual account, or a
        built-in account then there is no need to provide a password.

    .PARAMETER Name
        Credential name for the account.

    .EXAMPLE
        Test-AccountRequirePassword -Name 'DOMAIN\MyMSA$'

        Returns $false as a manged service account does not need a password.

    .EXAMPLE
        Test-AccountRequirePassword -Name 'DOMAIN\MySqlUser'

        Returns $true as a user account need a password.

    .EXAMPLE
        Test-AccountRequirePassword -Name 'NT SERVICE\MSSQL$PAYROLL'

        Returns $false as a virtual account does not need a password.

    .OUTPUTS
        [System.Boolean]
#>
function Test-AccountRequirePassword
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name
    )

    # Assume local or domain service account.
    $requirePassword = $true

    switch -Regex ($Name.ToUpper())
    {
        # Built-in account.
        '^(?:NT ?AUTHORITY\\)?(SYSTEM|LOCALSERVICE|LOCAL SERVICE|NETWORKSERVICE|NETWORK SERVICE)$' # CSpell: disable-line
        {
            $requirePassword = $false

            break
        }

        # Virtual account.
        '^(?:NT SERVICE\\)(.*)$'
        {
            $requirePassword = $false

            break
        }

        # (Global) Managed Service Account.
        '\$$'
        {
            $requirePassword = $false

            break
        }
    }

    return $requirePassword
}
#EndRegion './Public/Test-AccountRequirePassword.ps1' 74
#Region './Public/Test-DscParameterState.ps1' 0
<#
    .SYNOPSIS
        This method is used to test current and desired values for any DSC resource.

    .DESCRIPTION
        This function tests the parameter status of DSC resource parameters against
        the current values present on the system.

    .PARAMETER CurrentValues
        A hashtable with the current values on the system, obtained by e.g.
        Get-TargetResource.

    .PARAMETER DesiredValues
        The hashtable of desired values. For example $PSBoundParameters with the
        desired values.

    .PARAMETER Properties
        This is a list of properties in the desired values list should be checked.
        If this is empty then all values in DesiredValues are checked.

    .PARAMETER ExcludeProperties
        This is a list of which properties in the desired values list should be checked.
        If this is empty then all values in DesiredValues are checked.

    .PARAMETER TurnOffTypeChecking
        Indicates that the type of the parameter should not be checked.

    .PARAMETER ReverseCheck
        Indicates that a reverse check should be done. The current and desired state
        are swapped for another test.

    .PARAMETER SortArrayValues
        If the sorting of array values does not matter, values are sorted internally
        before doing the comparison.

    .EXAMPLE
        $currentState = Get-TargetResource @PSBoundParameters

        $returnValue = Test-DscParameterState -CurrentValues $currentState -DesiredValues $PSBoundParameters

        The function Get-TargetResource is called first using all bound parameters
        to get the values in the current state. The result is then compared to the
        desired state by calling `Test-DscParameterState`.

    .EXAMPLE
        $getTargetResourceParameters = @{
            ServerName     = $ServerName
            InstanceName   = $InstanceName
            Name           = $Name
        }

        $returnValue = Test-DscParameterState `
            -CurrentValues (Get-TargetResource @getTargetResourceParameters) `
            -DesiredValues $PSBoundParameters `
            -ExcludeProperties @(
                'FailsafeOperator'
                'NotificationMethod'
            )

        This compares the values in the current state against the desires state.
        The function Get-TargetResource is called using just the required parameters
        to get the values in the current state. The parameter 'ExcludeProperties'
        is used to exclude the properties 'FailsafeOperator' and
        'NotificationMethod' from the comparison.

    .EXAMPLE
        $getTargetResourceParameters = @{
            ServerName     = $ServerName
            InstanceName   = $InstanceName
            Name           = $Name
        }

        $returnValue = Test-DscParameterState `
            -CurrentValues (Get-TargetResource @getTargetResourceParameters) `
            -DesiredValues $PSBoundParameters `
            -Properties ServerName, Name

        This compares the values in the current state against the desires state.
        The function Get-TargetResource is called using just the required parameters
        to get the values in the current state. The 'Properties' parameter  is used
        to to only compare the properties 'ServerName' and 'Name'.
#>
function Test-DscParameterState
{
    [CmdletBinding()]
    [OutputType([Bool])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $CurrentValues,

        [Parameter(Mandatory = $true)]
        [System.Object]
        $DesiredValues,

        [Parameter()]
        [System.String[]]
        [Alias('ValuesToCheck')]
        $Properties,

        [Parameter()]
        [System.String[]]
        $ExcludeProperties,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $TurnOffTypeChecking,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $ReverseCheck,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $SortArrayValues
    )

    $returnValue = $true

    $resultCompare = Compare-DscParameterState @PSBoundParameters

    if ($resultCompare.InDesiredState -contains $false)
    {
        $returnValue = $false
    }

    return $returnValue
}
#EndRegion './Public/Test-DscParameterState.ps1' 130
#Region './Public/Test-DscProperty.ps1' 0
<#
    .SYNOPSIS
        Tests whether the class-based resource has the specified property.

    .DESCRIPTION
        Tests whether the class-based resource has the specified property.

    .PARAMETER InputObject
        Specifies the object that should be tested for existens of the specified
        property.

    .PARAMETER Name
        Specifies the name of the property.

    .PARAMETER HasValue
        Specifies if the property should be evaluated to have a non-value. If
        the property exist but is assigned `$null` the command returns `$false`.

    .PARAMETER Attribute
        Specifies if the property should be evaluated to have a specific attribute.
        If the property exist but is not the specific attribute the command returns
        `$false`.

    .EXAMPLE
        Test-DscProperty -InputObject $this -Name 'MyDscProperty'

        Returns $true or $false whether the property exist or not.

    .EXAMPLE
        $this | Test-DscProperty -Name 'MyDscProperty'

        Returns $true or $false whether the property exist or not.

    .EXAMPLE
        Test-DscProperty -InputObject $this -Name 'MyDscProperty' -HasValue

        Returns $true if the property exist and is assigned a non-null value, if not
        $false is returned.

    .EXAMPLE
        Test-DscProperty -InputObject $this -Name 'MyDscProperty' -Attribute 'Optional'

        Returns `$true` if the property exist and is an optional property.

    .EXAMPLE
        Test-DscProperty -InputObject $this -Name 'MyDscProperty' -Attribute 'Optional' -HasValue

        Returns `$true` if the property exist, is an optional property, and is
        assigned a non-null value.

    .OUTPUTS
        [System.Boolean]

    .NOTES
        This command only works with nullable data types, if using a non-nullable
        type make sure to make it nullable, e.g. [Nullable[System.Int32]].
#>
function Test-DscProperty
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $HasValue,

        [Parameter()]
        [ValidateSet('Key', 'Mandatory', 'NotConfigurable', 'Optional')]
        [System.String[]]
        $Attribute
    )

    begin
    {
        $hasProperty = $false
    }

    process
    {
        $isDscProperty = (Get-DscProperty @PSBoundParameters).ContainsKey($Name)

        if ($isDscProperty)
        {
            $hasProperty = $true
        }
    }

    end
    {
        return $hasProperty
    }
}
#EndRegion './Public/Test-DscProperty.ps1' 102
#Region './Public/Test-IsNanoServer.ps1' 0
<#
    .SYNOPSIS
        Tests if the current OS is a Nano server.

    .DESCRIPTION
        Tests if the current OS is a Nano server.

    .EXAMPLE
        Test-IsNanoServer

        Returns $true if the current operating system is Nano Server, if not $false
        is returned.
#>
function Test-IsNanoServer
{
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param ()

    $productDatacenterNanoServer = 143
    $productStandardNanoServer = 144

    $operatingSystemSKU = (Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU

    Write-Verbose -Message ($script:localizedData.TestIsNanoServerOperatingSystemSku -f $operatingSystemSKU)

    return ($operatingSystemSKU -in ($productDatacenterNanoServer, $productStandardNanoServer))
}
#EndRegion './Public/Test-IsNanoServer.ps1' 29
#Region './Public/Test-IsNumericType.ps1' 0
<#
    .SYNOPSIS
        Returns whether the specified object is of a numeric type.

    .DESCRIPTION
        Returns whether the specified object is of a numeric type.

    .PARAMETER Object
       The object to test if it is a numeric type.

    .EXAMPLE
        Test-IsNumericType -Object ([System.UInt32] 1)

        Returns $true since the object passed is of a numeric type.

    .EXAMPLE
        ('a', 2, 'b') | Test-IsNumericType

        Returns $true since one of the values in the array is of a numeric type.

    .OUTPUTS
        [System.Boolean]

    .NOTES
        When passing in an array of values from the pipeline, the command will return
        $true if any of the values in the array is numeric.
#>
function Test-IsNumericType
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(ValueFromPipeline = $true)]
        [System.Object]
        $Object
    )

    begin
    {
        $isNumeric = $false
    }

    process
    {
        if (
            $Object -is [System.Byte] -or
            $Object -is [System.Int16] -or
            $Object -is [System.Int32] -or
            $Object -is [System.Int64] -or
            $Object -is [System.SByte] -or
            $Object -is [System.UInt16] -or
            $Object -is [System.UInt32] -or
            $Object -is [System.UInt64] -or
            $Object -is [System.Decimal] -or
            $Object -is [System.Double] -or
            $Object -is [System.Single]
        )
        {
            $isNumeric = $true
        }
    }

    end
    {
        return $isNumeric
    }
}
#EndRegion './Public/Test-IsNumericType.ps1' 69
#Region './suffix.ps1' 0
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'
#EndRegion './suffix.ps1' 2
