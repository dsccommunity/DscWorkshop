#Region '.\Classes\1.DatumProvider.ps1' 0
class DatumProvider
{
    hidden [bool]$IsDatumProvider = $true

    [hashtable]ToHashTable()
    {
        $result = ConvertTo-Datum -InputObject $this
        return $result
    }

    [System.Collections.Specialized.OrderedDictionary]ToOrderedHashTable()
    {
        $result = ConvertTo-Datum -InputObject $this
        return $result
    }
}
#EndRegion '.\Classes\1.DatumProvider.ps1' 17
#Region '.\Classes\FileProvider.ps1' 0
class FileProvider : DatumProvider
{
    hidden [string]$Path
    hidden [hashtable] $Store
    hidden [hashtable] $DatumHierarchyDefinition
    hidden [hashtable] $StoreOptions
    hidden [hashtable] $DatumHandlers
    hidden [string] $Encoding

    FileProvider ($Path, $Store, $DatumHierarchyDefinition, $Encoding)
    {
        $this.Store = $Store
        $this.DatumHierarchyDefinition = $DatumHierarchyDefinition
        $this.StoreOptions = $Store.StoreOptions
        $this.Path = Get-Item $Path -ErrorAction SilentlyContinue
        $this.DatumHandlers = $DatumHierarchyDefinition.DatumHandlers
        $this.Encoding = $Encoding

        $result = Get-ChildItem -Path $path | ForEach-Object {
            if ($_.PSIsContainer)
            {
                $val = [scriptblock]::Create("New-DatumFileProvider -Path `"$($_.FullName)`" -Store `$this.DataOptions -DatumHierarchyDefinition `$this.DatumHierarchyDefinition -Encoding `$this.Encoding")
                $this | Add-Member -MemberType ScriptProperty -Name $_.BaseName -Value $val
            }
            else
            {
                $val = [scriptblock]::Create("Get-FileProviderData -Path `"$($_.FullName)`" -DatumHandlers `$this.DatumHandlers -Encoding `$this.Encoding")
                $this | Add-Member -MemberType ScriptProperty -Name $_.BaseName -Value $val
            }
        }
    }
}
#EndRegion '.\Classes\FileProvider.ps1' 33
#Region '.\Classes\Node.ps1' 0
class Node : hashtable
{
    Node([hashtable]$NodeData)
    {
        $NodeData.Keys | ForEach-Object {
            $this[$_] = $NodeData[$_]
        }

        $this | Add-Member -MemberType ScriptProperty -Name Roles -Value {
            $pathArray = $ExecutionContext.InvokeCommand.InvokeScript('Get-PSCallStack')[2].Position.Text -split '\.'
            $propertyPath = $pathArray[2..($pathArray.Count - 1)] -join '\'
            Write-Warning -Message "Resolve $propertyPath"

            $obj = [PSCustomObject]@{}
            $currentNode = $obj
            if ($pathArray.Count -gt 3)
            {
                foreach ($property in $pathArray[2..($pathArray.count - 2)])
                {
                    Write-Debug -Message "Adding $Property property"
                    $currentNode | Add-Member -MemberType NoteProperty -Name $property -Value ([PSCustomObject]@{})
                    $currentNode = $currentNode.$property
                }
            }
            Write-Debug -Message "Adding Resolved property to last object's property $($pathArray[-1])"
            $currentNode | Add-Member -MemberType NoteProperty -Name $pathArray[-1] -Value $propertyPath

            return $obj
        }
    }
    static ResolveDscProperty($Path)
    {
        "Resolve-DscProperty -DefaultValue $Path"
    }
}
#EndRegion '.\Classes\Node.ps1' 36
#Region '.\Private\Compare-Hashtable.ps1' 0
function Compare-Hashtable
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $ReferenceHashtable,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $DifferenceHashtable,

        [Parameter()]
        [string[]]
        $Property = ($ReferenceHashtable.Keys + $DifferenceHashtable.Keys | Select-Object -Unique)
    )

    Write-Debug -Message "Compare-Hashtable -Ref @{$($ReferenceHashtable.keys -join ';')} -Diff @{$($DifferenceHashtable.keys -join ';')} -Property [$($Property -join ', ')]"
    #Write-Debug -Message "REF:`r`n$($ReferenceHashtable | ConvertTo-Json)"
    #Write-Debug -Message "DIFF:`r`n$($DifferenceHashtable | ConvertTo-Json)"

    foreach ($propertyName in $Property)
    {
        Write-Debug -Message "  Testing <$propertyName>'s value"
        if (($inRef = $ReferenceHashtable.Contains($propertyName)) -and
            ($inDiff = $DifferenceHashtable.Contains($propertyName)))
        {
            if ($ReferenceHashtable[$propertyName] -as [hashtable[]] -or $DifferenceHashtable[$propertyName] -as [hashtable[]])
            {
                if ((Compare-Hashtable -ReferenceHashtable $ReferenceHashtable[$propertyName] -DifferenceHashtable $DifferenceHashtable[$propertyName]))
                {
                    Write-Debug -Message "  Skipping $propertyName...."
                    # If Compae returns something, they're not the same
                    continue
                }
            }
            else
            {
                Write-Debug -Message "Comparing: $($ReferenceHashtable[$propertyName]) With $($DifferenceHashtable[$propertyName])"
                if ($ReferenceHashtable[$propertyName] -ne $DifferenceHashtable[$propertyName])
                {
                    [PSCustomObject]@{
                        SideIndicator = '<='
                        PropertyName  = $propertyName
                        Value         = $ReferenceHashtable[$propertyName]
                    }

                    [PSCustomObject]@{
                        SideIndicator = '=>'
                        PropertyName  = $propertyName
                        Value         = $DifferenceHashtable[$propertyName]
                    }
                }
            }
        }
        else
        {
            Write-Debug -Message "  Property $propertyName Not in one Side: Ref: [$($ReferenceHashtable.Keys -join ',')] | [$($DifferenceHashtable.Keys -join ',')]"
            if ($inRef)
            {
                Write-Debug -Message "$propertyName found in Reference hashtable"
                [PSCustomObject]@{
                    SideIndicator = '<='
                    PropertyName  = $propertyName
                    Value         = $ReferenceHashtable[$propertyName]
                }
            }
            else
            {
                Write-Debug -Message "$propertyName found in Difference hashtable"
                [PSCustomObject]@{
                    SideIndicator = '=>'
                    PropertyName  = $propertyName
                    Value         = $DifferenceHashtable[$propertyName]
                }
            }
        }
    }

}
#EndRegion '.\Private\Compare-Hashtable.ps1' 81
#Region '.\Private\Copy-Object.ps1' 0
function Copy-Object
{
    <#
    .SYNOPSIS
        Creates a real copy of an object recursive including all the referenced objects it points to.

    .DESCRIPTION

        In .net reference types (classes), cannot be copied easily. If a type implements the IClonable interface it can be copied
        or cloned but the objects it references to will not be cloned. Rather the reference is cloned like shown in this example:

        $a = @{
            k1 = 'v1'
            k2 = @{
                kk1 = 'vv1'
                kk2 = 'vv2'
            }
        }

        $b = @{}
        $validKeys = 'k1', 'k2'
        foreach ($validKey in $validKeys)
        {
            if ($a.ContainsKey($validKey))
            {
                $b.Add($validKey, $a.Item($validKey))
            }
        }

        Write-Host '-------- Before removal of kk2 -------------'
        Write-Host "Key count of a.k2: $($a.k2.Keys.Count)"
        Write-Host "Key count in b.k2: $($b.k2.Keys.Count)"

        $b.k2.Remove('kk2')
        Write-Host '-------- After removal of kk2 --------------'
        Write-Host "Key count of a.k2: $($a.k2.Keys.Count)"
        Write-Host "Key count in b.k2: $($b.k2.Keys.Count)"


    .EXAMPLE
        PS C:\> $clonedObject = Copy-Object -DeepCopyObject $someObject

    .INPUTS
        [object]

    .OUTPUTS
        [object]

    #>

    param (
        [Parameter(Mandatory = $true)]
        [object]
        $DeepCopyObject
    )

    $serialData = [System.Management.Automation.PSSerializer]::Serialize($DeepCopyObject)
    [System.Management.Automation.PSSerializer]::Deserialize($serialData)
}
#EndRegion '.\Private\Copy-Object.ps1' 60
#Region '.\Private\Expand-RsopHashtable.ps1' 0
function Expand-RsopHashtable
{
    param (
        [Parameter()]
        [object]
        $InputObject,

        [Parameter()]
        [switch]
        $IsArrayValue,

        [Parameter()]
        [int]
        $Depth,

        [Parameter()]
        [switch]
        $AddSourceInformation
    )

    $Depth++

    if ($null -eq $InputObject)
    {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary])
    {
        $newObject = @{}
        $keys = [string[]]$InputObject.Keys
        foreach ($key in $keys)
        {
            $newObject.$key = Expand-RsopHashtable -InputObject $InputObject[$key] -Depth $Depth -AddSourceInformation:$AddSourceInformation
        }

        [ordered]@{} + $newObject
    }
    elseif ($InputObject -is [System.Collections.IList])
    {
        $doesUseYamlArraySyntax = [bool]($InputObject.Count - 1)
        if (-not $doesUseYamlArraySyntax)
        {
            $depth--
        }
        $items = foreach ($item in $InputObject)
        {
            Expand-RsopHashtable -InputObject $item -IsArrayValue:$doesUseYamlArraySyntax -Depth $Depth -AddSourceInformation:$AddSourceInformation
        }
        $items
    }
    elseif ($InputObject -is [pscredential])
    {
        $cred = $InputObject.GetNetworkCredential()
        $cred = "$($cred.UserName)@$($cred.Domain)$(if($cred.Domain){':'})$('*' * $cred.Password.Length)" | Add-Member -Name __File -MemberType NoteProperty -Value $InputObject.__File -PassThru

        Get-RsopValueString -InputString $cred -Key $key -Depth $depth -IsArrayValue:$IsArrayValue -AddSourceInformation:$AddSourceInformation
    }
    else
    {
        Get-RsopValueString -InputString $InputObject -Key $key -Depth $depth -IsArrayValue:$IsArrayValue -AddSourceInformation:$AddSourceInformation
    }
}
#EndRegion '.\Private\Expand-RsopHashtable.ps1' 64
#Region '.\Private\Get-DatumType.ps1' 0
function Get-DatumType
{
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]
        $DatumObject
    )

    if ($DatumObject -is [hashtable] -or $DatumObject -is [System.Collections.Specialized.OrderedDictionary])
    {
        'hashtable'
    }
    elseif ($DatumObject -isnot [string] -and $DatumObject -is [System.Collections.IEnumerable])
    {
        if ($DatumObject -as [hashtable[]])
        {
            'hash_array'
        }
        else
        {
            'baseType_array'
        }
    }
    else
    {
        'baseType'
    }

}
#EndRegion '.\Private\Get-DatumType.ps1' 32
#Region '.\Private\Get-MergeStrategyFromString.ps1' 0
function Get-MergeStrategyFromString
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter()]
        [string]
        $MergeStrategy
    )

    <#
    MergeStrategy: MostSpecific
            merge_hash: MostSpecific
            merge_baseType_array: MostSpecific
            merge_hash_array: MostSpecific

    MergeStrategy: hash
            merge_hash: hash
            merge_baseType_array: MostSpecific
            merge_hash_array: MostSpecific
            merge_options:
            knockout_prefix: --

    MergeStrategy: Deep
            merge_hash: deep
            merge_baseType_array: Unique
            merge_hash_array: DeepTuple
            merge_options:
            knockout_prefix: --
            Tuple_Keys:
                - Name
                - Version
    #>

    Write-Debug -Message "Get-MergeStrategyFromString -MergeStrategy <$MergeStrategy>"
    switch -regex ($MergeStrategy)
    {
        '^First$|^MostSpecific$'
        {
            @{
                merge_hash           = 'MostSpecific'
                merge_baseType_array = 'MostSpecific'
                merge_hash_array     = 'MostSpecific'
            }
        }

        '^hash$|^MergeTopKeys$'
        {
            @{
                merge_hash           = 'hash'
                merge_baseType_array = 'MostSpecific'
                merge_hash_array     = 'MostSpecific'
                merge_options        = @{
                    knockout_prefix = '--'
                }
            }
        }

        '^deep$|^MergeRecursively$'
        {
            @{
                merge_hash           = 'deep'
                merge_baseType_array = 'Unique'
                merge_hash_array     = 'DeepTuple'
                merge_options        = @{
                    knockout_prefix = '--'
                    tuple_keys      = @(
                        'Name',
                        'Version'
                    )
                }
            }
        }
        default
        {
            Write-Debug -Message "Couldn't Match the strategy $MergeStrategy"
            @{
                merge_hash           = 'MostSpecific'
                merge_baseType_array = 'MostSpecific'
                merge_hash_array     = 'MostSpecific'
            }
        }
    }

}
#EndRegion '.\Private\Get-MergeStrategyFromString.ps1' 86
#Region '.\Private\Get-RsopValueString.ps1' 0
function Get-RsopValueString
{
    param (
        [Parameter(Mandatory = $true)]
        [object]
        $InputString,

        [Parameter(Mandatory = $true)]
        [string]
        $Key,

        [Parameter()]
        [int]$Depth,

        [Parameter()]
        [switch]$IsArrayValue,

        [Parameter()]
        [switch]
        $AddSourceInformation
    )

    if (-not $AddSourceInformation)
    {
        $InputString.psobject.BaseObject
    }
    else
    {
        $fileInfo = (Get-DatumSourceFile -Path $InputString.__File)

        $i = if ($env:DatumRsopIndentation)
        {
            $env:DatumRsopIndentation
        }
        else
        {
            120
        }

        $i = if ($IsArrayValue)
        {
            $Depth--
            $i - ("$InputString".Length)
        }
        else
        {
            $i - ($Key.Length + "$InputString".Length)
        }

        $i -= [System.Math]::Max(0, ($depth) * 2)
        "{0}$(if ($fileInfo) { ""{1, $i}""  })" -f $InputString, $fileInfo
    }
}
#EndRegion '.\Private\Get-RsopValueString.ps1' 54
#Region '.\Private\Invoke-DatumHandler.ps1' 0
function Invoke-DatumHandler
{
    <#
    .SYNOPSIS
        Invokes the configured datum handlers.

    .DESCRIPTION
        This function goes through all datum handlers configured in the 'datum.yml'. For all handlers, it calls the test function
        first that identifies if the particular handler should be invoked at all for the given InputString. The test function
        look for a prefix and suffix in orer to know if a handler should be called. For the handler 'Datum.InvokeCommand' the
        prefix is '[x=' and the siffix '=]'.

        Let's assume the handler is defined in a module named 'Datum.InvokeCommand'. The handler is introduced in the 'datum.yml'
        like this:

        DatumHandlers:
            Datum.InvokeCommand::InvokeCommand:
                SkipDuringLoad: true

        The name of the function that checks if the handler should be called is constructed like this:

            <FilterModuleName>\Test-<FilterName>Filter

        Considering the definition in the 'datum.yml', the actual function name will be:

            Datum.InvokeCommand\Test-InvokeCommandFilter

        Same rule applies for the action function that is actually the handler. Datum searches a function with the name

            <FilterModuleName>\Invoke-<FilterName>Action

        which will be in case of the filter module named 'Datum.InvokeCommand' and the filter name 'InvokeCommand':

            Datum.InvokeCommand\Invoke-InvokeCommandAction

    .EXAMPLE
        This sample calls the handlers defined in the 'Datum.yml' on the value  '[x= { Get-Date } =]'. Only a handler will
        be invoked that has the prefix '[x=' and the siffix '=]'.

        PS C:\> $d = New-DatumStructure -DefinitionFile .\tests\Integration\assets\DscWorkshopConfigData\Datum.yml
        PS C:\> $result = $nul
        PS C:\> Invoke-DatumHandler -InputObject '[x= { Get-Date } =]' -DatumHandlers $d.__Definition.DatumHandlers -Result ([ref]$result)
        PS C:\> $result #-> Thursday, March 24, 2022 1:54:51 AM

    .INPUTS
        [object]

    .OUTPUTS
        Whatever the datum handler returns.

    .NOTES

    #>

    param (
        [Parameter(Mandatory = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [AllowNull()]
        [hashtable]
        $DatumHandlers,

        [Parameter()]
        [ref]$Result
    )

    $return = $false

    foreach ($handler in $DatumHandlers.Keys)
    {
        if ($DatumHandlers.$handler.SkipDuringLoad -and (Get-PSCallStack).Command -contains 'Get-FileProviderData')
        {
            continue
        }

        $filterModule, $filterName = $handler -split '::'
        if (-not (Get-Module $filterModule))
        {
            Import-Module $filterModule -Force -ErrorAction Stop
        }

        $filterCommand = Get-Command -ErrorAction SilentlyContinue ('{0}\Test-{1}Filter' -f $filterModule, $filterName)
        if ($filterCommand -and ($InputObject | &$filterCommand))
        {
            try
            {
                if ($actionCommand = Get-Command -Name ('{0}\Invoke-{1}Action' -f $filterModule, $filterName) -ErrorAction SilentlyContinue)
                {
                    $actionParams = @{}
                    $commandOptions = $DatumHandlers.$handler.CommandOptions.Keys

                    # Populate the Command's params with what's in the Datum.yml, or from variables
                    $variables = Get-Variable
                    foreach ($paramName in $actionCommand.Parameters.Keys)
                    {
                        if ($paramName -in $commandOptions)
                        {
                            $actionParams.Add($paramName, $DatumHandlers.$handler.CommandOptions[$paramName])
                        }
                        elseif ($var = $Variables.Where{ $_.Name -eq $paramName })
                        {
                            $actionParams."$paramName" = $var[0].Value
                        }
                    }
                    $internalResult = (&$actionCommand @actionParams)
                    if ($null -eq $internalResult)
                    {
                        $Result.Value = [string]::Empty
                    }

                    $Result.Value = $internalResult
                    return $true
                }
            }
            catch
            {
                $throwOnError = [bool]$datum.__Definition.DatumHandlersThrowOnError

                if ($throwOnError)
                {
                    Write-Error -ErrorRecord $_ -ErrorAction Stop
                }
                else
                {
                    Write-Warning "Error using Datum Handler '$Handler', the error was: '$($_.Exception.Message)'. Returning InputObject ($InputObject)."
                    $Result = $InputObject
                    return $false
                }
            }
        }
    }

    return $return
}
#EndRegion '.\Private\Invoke-DatumHandler.ps1' 137
#Region '.\Private\Merge-DatumArray.ps1' 0
function Merge-DatumArray
{
    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]
        $ReferenceArray,

        [Parameter(Mandatory = $true)]
        [object]
        $DifferenceArray,

        [Parameter()]
        [hashtable]
        $Strategy = @{},

        [Parameter()]
        [hashtable]
        $ChildStrategies = @{
            '^.*' = $Strategy
        },

        [Parameter(Mandatory = $true)]
        [string]
        $StartingPath
    )

    Write-Debug -Message "`tMerge-DatumArray -StartingPath <$StartingPath>"
    $knockout_prefix = [regex]::Escape($Strategy.merge_options.knockout_prefix).Insert(0, '^')
    $hashArrayStrategy = $Strategy.merge_hash_array
    Write-Debug -Message "`t`tHash Array Strategy: $hashArrayStrategy"
    $mergeBasetypeArraysStrategy = $Strategy.merge_basetype_array
    $mergedArray = [System.Collections.ArrayList]::new()

    $sortParams = @{}
    if ($propertyNames = [string[]]$Strategy.merge_options.tuple_keys)
    {
        $sortParams.Add('Property', $propertyNames)
    }

    if ($ReferenceArray -as [hashtable[]])
    {
        Write-Debug -Message "`t`tMERGING Array of Hashtables"
        if (-not $hashArrayStrategy -or $hashArrayStrategy -match 'MostSpecific')
        {
            Write-Debug -Message "`t`tMerge_hash_arrays Disabled. value: $hashArrayStrategy"
            $mergedArray = $ReferenceArray
            if ($Strategy.sort_merged_arrays)
            {
                $mergedArray = $mergedArray | Sort-Object @sortParams
            }
            return $mergedArray
        }

        switch -Regex ($hashArrayStrategy)
        {
            '^Sum|^Add'
            {
                (@($DifferenceArray) + @($ReferenceArray)) | ForEach-Object {
                    $null = $mergedArray.Add(([ordered]@{} + $_))
                }
            }

            # MergeHashesByProperties
            '^Deep|^Merge'
            {
                Write-Debug -Message "`t`t`tStrategy for Array Items: Merge Hash By tuple`r`n"
                # look at each $RefItems in $RefArray
                #   if no PropertyNames defined, use all Properties of $RefItem
                #   else use defined propertyNames
                #  Search for DiffItem that has the same Property/Value pairs
                #    if found, Merge-Datum (or MergeHashtable?)
                #    if not found, add $DiffItem to $RefArray

                # look at each $RefItems in $RefArray
                $usedDiffItems = [System.Collections.ArrayList]::new()
                foreach ($referenceItem in $ReferenceArray)
                {
                    $referenceItem = [ordered]@{} + $referenceItem
                    Write-Debug -Message "`t`t`t  .. Working on Merged Element $($mergedArray.Count)`r`n"
                    # if no PropertyNames defined, use all Properties of $RefItem
                    if (-not $propertyNames)
                    {
                        Write-Debug -Message "`t`t`t ..No PropertyName defined: Use ReferenceItem Keys"
                        $propertyNames = $referenceItem.Keys
                    }
                    $mergedItem = @{} + $referenceItem
                    $diffItemsToMerge = $DifferenceArray.Where{
                        $differenceItem = [ordered]@{} + $_
                        # Search for DiffItem that has the same Property/Value pairs than RefItem
                        $compareHashParams = @{
                            ReferenceHashtable  = [ordered]@{} + $referenceItem
                            DifferenceHashtable = $differenceItem
                            Property            = $propertyNames
                        }
                        (-not (Compare-Hashtable @compareHashParams))
                    }
                    Write-Debug -Message "`t`t`t ..Items to merge: $($diffItemsToMerge.Count)"
                    $diffItemsToMerge | ForEach-Object {
                        $mergeItemsParams = @{
                            ParentPath          = $StartingPath
                            Strategy            = $Strategy
                            ReferenceHashtable  = $mergedItem
                            DifferenceHashtable = $_
                            ChildStrategies     = $ChildStrategies
                        }
                        $mergedItem = Merge-Hashtable @mergeItemsParams
                    }
                    # If a diff Item has been used, save it to find the unused ones
                    $null = $usedDiffItems.AddRange($diffItemsToMerge)
                    $null = $mergedArray.Add($mergedItem)
                }
                $unMergedItems = $DifferenceArray | ForEach-Object {
                    if (-not $usedDiffItems.Contains($_))
                    {
                        ([ordered]@{} + $_)
                    }
                }
                if ($null -ne $unMergedItems)
                {
                    if ($unMergedItems -is [System.Array])
                    {
                        $null = $mergedArray.AddRange($unMergedItems)
                    }
                    else
                    {
                        $null = $mergedArray.Add($unMergedItems)
                    }
                }
            }

            # UniqueByProperties
            '^Unique'
            {
                Write-Debug -Message "`t`t`tSelecting Unique Hashes accross both arrays based on Property tuples"
                # look at each $DiffItems in $DiffArray
                #   if no PropertyNames defined, use all Properties of $DiffItem
                #   else use defined PropertyNames
                #  Search for a RefItem that has the same Property/Value pairs
                #  if Nothing is found
                #    add current DiffItem to RefArray

                if (-not $propertyNames)
                {
                    Write-Debug -Message "`t`t`t ..No PropertyName defined: Use ReferenceItem Keys"
                    $propertyNames = $referenceItem.Keys
                }

                $mergedArray = [System.Collections.ArrayList]::new()
                $ReferenceArray | ForEach-Object {
                    $currentRefItem = $_
                    if (-not ($mergedArray.Where{ -not (Compare-Hashtable -Property $propertyNames -ReferenceHashtable $currentRefItem -DifferenceHashtable $_ ) }))
                    {
                        $null = $mergedArray.Add(([ordered]@{} + $_))
                    }
                }

                $DifferenceArray | ForEach-Object {
                    $currentDiffItem = $_
                    if (-not ($mergedArray.Where{ -not (Compare-Hashtable -Property $propertyNames -ReferenceHashtable $currentDiffItem -DifferenceHashtable $_ ) }))
                    {
                        $null = $mergedArray.Add(([ordered]@{} + $_))
                    }
                }
            }
        }
    }

    $mergedArray
}
#EndRegion '.\Private\Merge-DatumArray.ps1' 172
#Region '.\Private\Merge-Hashtable.ps1' 0
function Merge-Hashtable
{
    [OutputType([hashtable])]
    [CmdletBinding()]
    param (
        # [hashtable] These should stay ordered
        [Parameter(Mandatory = $true)]
        [object]
        $ReferenceHashtable,

        # [hashtable] These should stay ordered
        [Parameter(Mandatory = $true)]
        [object]
        $DifferenceHashtable,

        [Parameter()]
        $Strategy = @{
            merge_hash           = 'hash'
            merge_baseType_array = 'MostSpecific'
            merge_hash_array     = 'MostSpecific'
            merge_options        = @{
                knockout_prefix = '--'
            }
        },

        [Parameter()]
        [hashtable]
        $ChildStrategies = @{},

        [Parameter()]
        [string]
        $ParentPath
    )

    Write-Debug -Message "`tMerge-Hashtable -ParentPath <$ParentPath>"

    # Removing Case Sensitivity while keeping ordering
    $ReferenceHashtable = [ordered]@{} + $ReferenceHashtable
    $DifferenceHashtable = [ordered]@{} + $DifferenceHashtable
    $clonedReference = [ordered]@{} + $ReferenceHashtable

    if ($Strategy.merge_options.knockout_prefix)
    {
        $knockoutPrefix = $Strategy.merge_options.knockout_prefix
        $knockoutPrefixMatcher = [regex]::Escape($knockoutPrefix).Insert(0, '^')
    }
    else
    {
        $knockoutPrefixMatcher = [regex]::Escape('--').insert(0, '^')
    }
    Write-Debug -Message "`t  Knockout Prefix Matcher: $knockoutPrefixMatcher"

    $knockedOutKeys = $ReferenceHashtable.Keys.Where{ $_ -match $knockoutPrefixMatcher }.ForEach{ $_ -replace $knockoutPrefixMatcher }
    Write-Debug -Message "`t  Knockedout Keys: [$($knockedOutKeys -join ', ')] from reference Hashtable Keys [$($ReferenceHashtable.keys -join ', ')]"

    foreach ($currentKey in $DifferenceHashtable.keys)
    {
        Write-Debug -Message "`t  CurrentKey: $currentKey"
        if ($currentKey -in $knockedOutKeys)
        {
            Write-Debug -Message "`t`tThe Key $currentkey is knocked out from the reference Hashtable."
        }
        elseif ($currentKey -match $knockoutPrefixMatcher -and -not $ReferenceHashtable.Contains(($currentKey -replace $knockoutPrefixMatcher)))
        {
            # it's a knockout coming from a lower level key, it should only apply down from here
            Write-Debug -Message "`t`tKnockout prefix found for $currentKey in Difference hashtable, and key not set in Reference hashtable"
            if (-not $ReferenceHashtable.Contains($currentKey))
            {
                Write-Debug -Message "`t`t..adding knockout prefixed key for $curretKey to block further merges"
                $clonedReference.Add($currentKey, $null)
            }
        }
        elseif (-not $ReferenceHashtable.Contains($currentKey) )
        {
            #if the key does not exist in reference ht, create it using the DiffHt's value
            Write-Debug -Message "`t    Added Missing Key $currentKey of value: $($DifferenceHashtable[$currentKey]) from difference HT"
            $clonedReference.Add($currentKey, $DifferenceHashtable[$currentKey])
        }
        else
        {
            #the key exists, and it's not a knockout entry
            $refHashItemValueType = Get-DatumType -DatumObject $ReferenceHashtable[$currentKey]
            $diffHashItemValueType = Get-DatumType -DatumObject $DifferenceHashtable[$currentKey]
            Write-Debug -Message "for Key $currentKey REF:[$refHashItemValueType] | DIFF:[$diffHashItemValueType]"
            if ($ParentPath)
            {
                $childPath = Join-Path -Path $ParentPath -ChildPath $currentKey
            }
            else
            {
                $childPath = $currentKey
            }

            switch ($refHashItemValueType)
            {
                'hashtable'
                {
                    if ($Strategy.merge_hash -eq 'deep')
                    {
                        Write-Debug -Message "`t`t .. Merging Datums at current path $childPath"
                        # if there's no Merge override for the subkey's path in the (not subkeys),
                        #   merge HASHTABLE with same strategy
                        # otherwise, merge Datum
                        $childStrategy = Get-MergeStrategyFromPath -Strategies $ChildStrategies -PropertyPath $childPath

                        if ($childStrategy.Default)
                        {
                            Write-Debug -Message "`t`t ..Merging using the current Deep Strategy, Bypassing default"
                            $MergePerDefault = @{
                                ParentPath          = $childPath
                                Strategy            = $Strategy
                                ReferenceHashtable  = $ReferenceHashtable[$currentKey]
                                DifferenceHashtable = $DifferenceHashtable[$currentKey]
                                ChildStrategies     = $ChildStrategies
                            }
                            $subMerge = Merge-Hashtable @MergePerDefault
                        }
                        else
                        {
                            Write-Debug -Message "`t`t ..Merging using Override Strategy $($childStrategy | ConvertTo-Json)"
                            $MergeDatumParam = @{
                                StartingPath    = $childPath
                                ReferenceDatum  = $ReferenceHashtable[$currentKey]
                                DifferenceDatum = $DifferenceHashtable[$currentKey]
                                Strategies      = $ChildStrategies
                            }
                            $subMerge = Merge-Datum @MergeDatumParam
                        }
                        Write-Debug -Message "`t  # Submerge $($submerge|ConvertTo-Json)."
                        $clonedReference[$currentKey] = $subMerge
                    }
                }

                'baseType'
                {
                    #do nothing to use most specific value (quicker than default)
                }

                # Default used for hash_array, baseType_array
                default
                {
                    Write-Debug -Message "`t  .. Merging Datums at current path $childPath`r`n$($Strategy | ConvertTo-Json)"
                    $MergeDatumParams = @{
                        StartingPath    = $childPath
                        Strategies      = $ChildStrategies
                        ReferenceDatum  = $ReferenceHashtable[$currentKey]
                        DifferenceDatum = $DifferenceHashtable[$currentKey]
                    }

                    if ($clonedReference.$currentKey -is [System.Array])
                    {
                        [System.Array]$clonedReference[$currentKey] = Merge-Datum @MergeDatumParams
                    }
                    else
                    {
                        $clonedReference[$currentKey] = Merge-Datum @MergeDatumParams
                    }
                    Write-Debug -Message "`t  .. Datum Merged for path $childPath"
                }
            }
        }
    }

    return $clonedReference
}
#EndRegion '.\Private\Merge-Hashtable.ps1' 166
#Region '.\Public\Clear-DatumRsopCache.ps1' 0
function Clear-DatumRsopCache
{
    [CmdletBinding()]

    param ()

    if ($script:rsopCache.Count)
    {
        $script:rsopCache.Clear()
        Write-Verbose -Message 'Datum RSOP Cache cleared'
    }
}
#EndRegion '.\Public\Clear-DatumRsopCache.ps1' 13
#Region '.\Public\ConvertTo-Datum.ps1' 0
function ConvertTo-Datum
{
    param (
        [Parameter(ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [AllowNull()]
        [hashtable]
        $DatumHandlers = @{}
    )

    process
    {
        $result = $null

        if ($null -eq $InputObject)
        {
            return $null
        }

        if ($InputObject -is [System.Collections.IDictionary])
        {
            if (-not $file -and $InputObject.__File)
            {
                $file = $InputObject.__File
            }

            $hashKeys = [string[]]$InputObject.Keys
            foreach ($key in $hashKeys)
            {
                $InputObject[$key] = ConvertTo-Datum -InputObject $InputObject[$key] -DatumHandlers $DatumHandlers
            }
            # Making the Ordered Dict Case Insensitive
            ([ordered]@{} + $InputObject) | Add-Member -Name __File -MemberType NoteProperty -Value "$file" -PassThru -Force
        }
        elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject)
                {
                    if (-not $file -and $object.__File)
                    {
                        $file = $object.__File
                    }
                    ConvertTo-Datum -InputObject $object -DatumHandlers $DatumHandlers
                }
            )

            , $collection
        }
        elseif (($InputObject -is [DatumProvider]) -and $InputObject -isnot [pscredential])
        {
            if (-not $file -and $InputObject.__File)
            {
                $file = $InputObject.__File
            }

            $hash = [ordered]@{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = ConvertTo-Datum -InputObject $property.Value -DatumHandlers $DatumHandlers | Add-Member -Name __File -MemberType NoteProperty -Value $File.FullName -PassThru -Force
            }

            $hash
        }
        # if there's a matching filter, process associated command and return result
        elseif ($DatumHandlers.Count -and (Invoke-DatumHandler -InputObject $InputObject -DatumHandlers $DatumHandlers -Result ([ref]$result)))
        {
            if (-not $file -and $InputObject.__File)
            {
                $file = $InputObject.__File
            }

            if ($result)
            {
                if (-not $result.__File -and $InputObject.__File)
                {
                    $result | Add-Member -Name __File -Value "$($InputObject.__File)" -MemberType NoteProperty -PassThru -Force
                }
                elseif (-not $result.__File -and $file)
                {
                    $result | Add-Member -Name __File -Value "$($file)" -MemberType NoteProperty -PassThru -Force
                }
                else
                {
                    $result
                }
            }
            else
            {
                Write-Verbose "Datum handlers for '$InputObject' returned '$null'"
                $null
            }
        }
        else
        {
            if (-not $file -and $InputObject.__File)
            {
                $file = $InputObject.__File
            }

            if ($file -and -not $InputObject.__File)
            {
                $InputObject | Add-Member -Name __File -Value "$file" -MemberType NoteProperty -PassThru -Force
            }
            else
            {
                $InputObject
            }
        }
    }
}
#EndRegion '.\Public\ConvertTo-Datum.ps1' 116
#Region '.\Public\Get-DatumRsop.ps1' 0
function Get-DatumRsop
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Datum,

        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $AllNodes,

        [Parameter()]
        [string]
        $CompositionKey = 'Configurations',

        [Parameter()]
        [scriptblock]
        $Filter = {},

        [Parameter()]
        [switch]
        $IgnoreCache,

        [Parameter()]
        [switch]
        $IncludeSource,

        [Parameter()]
        [switch]
        $RemoveSource
    )

    if (-not $script:rsopCache)
    {
        $script:rsopCache = @{}
    }

    if ($Filter.ToString() -ne ([System.Management.Automation.ScriptBlock]::Create( {})).ToString())
    {
        Write-Verbose "Filter: $($Filter.ToString())"
        $AllNodes = [System.Collections.Hashtable[]]$AllNodes.Where($Filter)
        Write-Verbose "Node count after applying filter: $($AllNodes.Count)"
    }

    foreach ($node in $AllNodes)
    {
        if (-not $node.Name)
        {
            $node.Name = $node.NodeName
        }

        $null = $node | ConvertTo-Datum -DatumHandlers $Datum.__Definition.DatumHandlers

        if (-not $script:rsopCache.ContainsKey($node.Name) -or $IgnoreCache)
        {
            Write-Verbose "Key not found in the cache: '$($node.Name)'. Creating RSOP..."
            $rsopNode = $node.Clone()

            $configurations = Resolve-NodeProperty -PropertyPath $CompositionKey -Node $node -DatumTree $Datum -DefaultValue @()
            $rsopNode."$CompositionKey" = $configurations

            $configurations.ForEach{
                $value = Resolve-NodeProperty -PropertyPath $_ -DefaultValue @{} -Node $node -DatumTree $Datum
                $rsopNode."$_" = $value
            }

            $lcmConfigKeyName = $datum.__Definition.DscLocalConfigurationManagerKeyName
            if ($lcmConfigKeyName)
            {
                $lcmConfig = Resolve-NodeProperty -PropertyPath $lcmConfigKeyName -DefaultValue $null
                if ($lcmConfig)
                {
                    $rsopNode.LcmConfig = $lcmConfig
                }
                else
                {
                    Write-Host -Object "`tWARNING: 'DscLocalConfigurationManagerKeyName' is defined in the 'datum.yml' but did not return a result for node '$($node.Name)'" -ForegroundColor Yellow
                }
            }

            $clonedRsopNode = Copy-Object -DeepCopyObject $rsopNode
            $clonedRsopNode = ConvertTo-Datum -InputObject $clonedRsopNode -DatumHandlers $Datum.__Definition.DatumHandlers
            $script:rsopCache."$($node.Name)" = $clonedRsopNode
        }
        else
        {
            Write-Verbose "Key found in the cache: '$($node.Name)'. Retrieving RSOP from cache."
        }

        if ($IncludeSource)
        {
            Expand-RsopHashtable -InputObject $script:rsopCache."$($node.Name)" -Depth 0 -AddSourceInformation
        }
        elseif ($RemoveSource)
        {
            Expand-RsopHashtable -InputObject $script:rsopCache."$($node.Name)" -Depth 0
        }
        else
        {
            $script:rsopCache."$($node.Name)"
        }
    }
}
#EndRegion '.\Public\Get-DatumRsop.ps1' 105
#Region '.\Public\Get-DatumRsopCache.ps1' 0
function Get-DatumRsopCache
{
    [CmdletBinding()]

    param ()

    if ($script:rsopCache.Count)
    {
        $script:rsopCache
    }
    else
    {
        $script:rsopCache = @{}
        Write-Verbose 'The Datum RSOP Cache is empty.'
    }
}
#EndRegion '.\Public\Get-DatumRsopCache.ps1' 17
#Region '.\Public\Get-DatumSourceFile.ps1' 0
function Get-DatumSourceFile
{
    <#
    .SYNOPSIS
        Gets the source file for the given datum.
    .DESCRIPTION

        This command gets the relative source file for the given datum. The source file path
        is relative to the current directory and skips the first directory in the path.

    .EXAMPLE
        PS C:\> Get-DatumSourceFile -Path D:\git\datum\tests\Integration\assets\DscWorkshopConfigData\Roles\DomainController.yml

        This command returns the source file path like this:
            assets\DscWorkshopConfigData\Roles\DomainController

    .INPUTS
        string

    .OUTPUTS
        string
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    if (-not $Path)
    {
        return [string]::Empty
    }

    try
    {
        $p = Resolve-Path -Path $Path -Relative -ErrorAction Stop
        $p = $p -split '\\'
        $p[-1] = [System.IO.Path]::GetFileNameWithoutExtension($p[-1])
        $p[2..($p.Length - 1)] -join '\'
    }
    catch
    {
        Write-Verbose 'Get-DatumSourceFile: nothing to catch here'
    }
}
#EndRegion '.\Public\Get-DatumSourceFile.ps1' 48
#Region '.\Public\Get-FileProviderData.ps1' 0
function Get-FileProviderData
{
    [OutputType([System.Array])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [AllowNull()]
        [hashtable]
        $DatumHandlers = @{},

        [Parameter()]
        [ValidateSet('Ascii', 'BigEndianUnicode', 'Default', 'Unicode', 'UTF32', 'UTF7', 'UTF8')]
        [string]
        $Encoding = 'Default'
    )

    if (-not $script:FileProviderDataCache)
    {
        $script:FileProviderDataCache = @{}
    }

    $file = Get-Item -Path $Path
    if ($script:FileProviderDataCache.ContainsKey($file.FullName) -and
        $file.LastWriteTime -eq $script:FileProviderDataCache[$file.FullName].Metadata.LastWriteTime)
    {
        Write-Verbose -Message "Getting File Provider Cache for Path: $Path"
        , $script:FileProviderDataCache[$file.FullName].Value
    }
    else
    {
        Write-Verbose -Message "Getting File Provider Data for Path: $Path"
        $data = switch ($file.Extension)
        {
            '.psd1'
            {
                Import-PowerShellDataFile -Path $file | ConvertTo-Datum -DatumHandlers $DatumHandlers
            }
            '.json'
            {
                ConvertFrom-Json -InputObject (Get-Content -Path $Path -Encoding $Encoding -Raw) | ConvertTo-Datum -DatumHandlers $DatumHandlers
            }
            '.yml'
            {
                ConvertFrom-Yaml -Yaml (Get-Content -Path $Path -Encoding $Encoding -Raw) -Ordered | ConvertTo-Datum -DatumHandlers $DatumHandlers
            }
            '.yaml'
            {
                ConvertFrom-Yaml -Yaml (Get-Content -Path $Path -Encoding $Encoding -Raw) -Ordered | ConvertTo-Datum -DatumHandlers $DatumHandlers
            }
            Default
            {
                Write-Verbose -Message "File extension $($file.Extension) not supported. Defaulting on RAW."
                Get-Content -Path $Path -Encoding $Encoding -Raw
            }
        }

        $script:FileProviderDataCache[$file.FullName] = @{
            Metadata = $file
            Value    = $data
        }
        , $data
    }
}
#EndRegion '.\Public\Get-FileProviderData.ps1' 68
#Region '.\Public\Get-MergeStrategyFromPath.ps1' 0
function Get-MergeStrategyFromPath
{
    [OutputType([hashtable])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Strategies,

        [Parameter(Mandatory = $true)]
        [string]
        $PropertyPath
    )

    Write-Debug -Message "`tGet-MergeStrategyFromPath -PropertyPath <$PropertyPath> -Strategies [$($Strategies.Keys -join ', ')], count $($Strategies.Count)"
    # Select Relevant strategy
    #   Use exact path match first
    #   or try Regex in order
    if ($Strategies.($PropertyPath))
    {
        $strategyKey = $PropertyPath
        Write-Debug -Message "`t  Strategy found for exact key $strategyKey"
    }
    elseif ($Strategies.Keys -and
        ($strategyKey = [string]($Strategies.Keys.Where{ $_.StartsWith('^') -and $_ -as [regex] -and $PropertyPath -match $_ } | Select-Object -First 1))
    )
    {
        Write-Debug -Message "`t  Strategy matching regex $strategyKey"
    }
    else
    {
        Write-Debug -Message "`t  No Strategy found"
        return
    }

    Write-Debug -Message "`t  StrategyKey: $strategyKey"
    if ($Strategies[$strategyKey] -is [string])
    {
        Write-Debug -Message "`t  Returning Strategy $strategyKey from String '$($Strategies[$strategyKey])'"
        Get-MergeStrategyFromString -MergeStrategy $Strategies[$strategyKey]
    }
    else
    {
        Write-Debug -Message "`t  Returning Strategy $strategyKey of type '$($Strategies[$strategyKey].Strategy)'"
        $Strategies[$strategyKey]
    }
}
#EndRegion '.\Public\Get-MergeStrategyFromPath.ps1' 48
#Region '.\Public\Invoke-TestHandlerAction.ps1' 0
function Invoke-TestHandlerAction
{
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Password,

        [Parameter()]
        [object]
        $Test,

        [Parameter()]
        [object]
        $Datum
    )

    @"
Action: $handler
Node: $($Node|fl *|Out-String)
Params:
$($PSBoundParameters | ConvertTo-Json)
"@

}
#EndRegion '.\Public\Invoke-TestHandlerAction.ps1' 27
#Region '.\Public\Merge-Datum.ps1' 0
function Merge-Datum
{
    [OutputType([System.Array])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $StartingPath,

        [Parameter(Mandatory = $true)]
        [object]
        $ReferenceDatum,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]
        $DifferenceDatum,

        [Parameter()]
        [hashtable]
        $Strategies = @{
            '^.*' = 'MostSpecific'
        }
    )

    Write-Debug -Message "Merge-Datum -StartingPath <$StartingPath>"
    $strategy = Get-MergeStrategyFromPath -Strategies $Strategies -PropertyPath $startingPath -Verbose

    Write-Verbose -Message "   Merge Strategy: @$($strategy | ConvertTo-Json)"

    $result = $null
    if ($ReferenceDatum -is [array])
    {
        $datumItems = @()
        foreach ($item in $ReferenceDatum)
        {
            if (Invoke-DatumHandler -InputObject $item -DatumHandlers $Datum.__Definition.DatumHandlers -Result ([ref]$result))
            {
                $datumItems += ConvertTo-Datum -InputObject $result -DatumHandlers $Datum.__Definition.DatumHandlers
            }
            else
            {
                $datumItems += $item
            }
        }
        $ReferenceDatum = $datumItems
    }
    else
    {
        if (Invoke-DatumHandler -InputObject $ReferenceDatum -DatumHandlers $Datum.__Definition.DatumHandlers -Result ([ref]$result))
        {
            $ReferenceDatum = ConvertTo-Datum -InputObject $result -DatumHandlers $Datum.__Definition.DatumHandlers
        }
    }

    if ($DifferenceDatum -is [array])
    {
        $datumItems = @()
        foreach ($item in $DifferenceDatum)
        {
            if (Invoke-DatumHandler -InputObject $item -DatumHandlers $Datum.__Definition.DatumHandlers -Result ([ref]$result))
            {
                $datumItems += ConvertTo-Datum -InputObject $result -DatumHandlers $Datum.__Definition.DatumHandlers
            }
            else
            {
                $datumItems += $item
            }
        }
        $DifferenceDatum = $datumItems
    }
    else
    {
        if (Invoke-DatumHandler -InputObject $DifferenceDatum -DatumHandlers $Datum.__Definition.DatumHandlers -Result ([ref]$result))
        {
            $DifferenceDatum = ConvertTo-Datum -InputObject $result -DatumHandlers $Datum.__Definition.DatumHandlers
        }
    }

    $referenceDatumType = Get-DatumType -DatumObject $ReferenceDatum
    $differenceDatumType = Get-DatumType -DatumObject $DifferenceDatum

    if ($referenceDatumType -ne $differenceDatumType)
    {
        Write-Warning -Message "Cannot merge different types in path '$StartingPath' REF:[$referenceDatumType] | DIFF:[$differenceDatumType]$($DifferenceDatum.GetType()) , returning most specific Datum."
        return $ReferenceDatum
    }

    if ($strategy -is [string])
    {
        $strategy = Get-MergeStrategyFromString -MergeStrategy $strategy
    }

    switch ($referenceDatumType)
    {
        'BaseType'
        {
            return $ReferenceDatum
        }

        'hashtable'
        {
            $mergeParams = @{
                ReferenceHashtable  = $ReferenceDatum
                DifferenceHashtable = $DifferenceDatum
                Strategy            = $strategy
                ParentPath          = $StartingPath
                ChildStrategies     = $Strategies
            }

            if ($strategy.merge_hash -match '^MostSpecific$|^First')
            {
                return $ReferenceDatum
            }
            else
            {
                Merge-Hashtable @mergeParams
            }
        }

        'baseType_array'
        {
            switch -Regex ($strategy.merge_baseType_array)
            {
                '^MostSpecific$|^First'
                {
                    return $ReferenceDatum
                }

                '^Unique'
                {
                    if ($regexPattern = $strategy.merge_options.knockout_prefix)
                    {
                        $regexPattern = $regexPattern.insert(0, '^')
                        $result = @(($ReferenceDatum + $DifferenceDatum).Where{ $_ -notmatch $regexPattern } | Select-Object -Unique)
                        , $result
                    }
                    else
                    {
                        $result = @(($ReferenceDatum + $DifferenceDatum) | Select-Object -Unique)
                        , $result
                    }

                }

                '^Sum|^Add'
                {
                    #--> $ref + $diff -$kop
                    if ($regexPattern = $strategy.merge_options.knockout_prefix)
                    {
                        $regexPattern = $regexPattern.insert(0, '^')
                        , (($ReferenceDatum + $DifferenceDatum).Where{ $_ -notMatch $regexPattern })
                    }
                    else
                    {
                        , ($ReferenceDatum + $DifferenceDatum)
                    }
                }

                Default
                {
                    return (, $ReferenceDatum)
                }
            }
        }

        'hash_array'
        {
            $MergeDatumArrayParams = @{
                ReferenceArray  = $ReferenceDatum
                DifferenceArray = $DifferenceDatum
                Strategy        = $strategy
                ChildStrategies = $Strategies
                StartingPath    = $StartingPath
            }

            switch -Regex ($strategy.merge_hash_array)
            {
                '^MostSpecific|^First'
                {
                    return $ReferenceDatum
                }

                '^UniqueKeyValTuples'
                {
                    #--> $ref + $diff | ? % key in Tuple_Keys -> $ref[Key] -eq $diff[key] is not already int output
                    , (Merge-DatumArray @MergeDatumArrayParams)
                }

                '^DeepTuple|^DeepItemMergeByTuples'
                {
                    #--> $ref + $diff | ? % key in Tuple_Keys -> $ref[Key] -eq $diff[key] is merged up
                    , (Merge-DatumArray @MergeDatumArrayParams)
                }

                '^Sum'
                {
                    #--> $ref + $diff
                    (@($DifferenceArray) + @($ReferenceArray)).Foreach{
                        $null = $MergedArray.Add(([ordered]@{} + $_))
                    }
                    , $MergedArray
                }

                Default
                {
                    return , $ReferenceDatum
                }
            }
        }
    }
}
#EndRegion '.\Public\Merge-Datum.ps1' 213
#Region '.\Public\New-DatumFileProvider.ps1' 0
function New-DatumFileProvider
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [Alias('DataOptions')]
        [AllowNull()]
        [object]
        $Store,

        [Parameter()]
        [AllowNull()]
        [hashtable]
        $DatumHierarchyDefinition = @{},

        [Parameter()]
        [string]
        $Path = $Store.StoreOptions.Path,

        [Parameter()]
        [ValidateSet('Ascii', 'BigEndianUnicode', 'Default', 'Unicode', 'UTF32', 'UTF7', 'UTF8')]
        [string]
        $Encoding = 'Default'
    )

    if (-not $DatumHierarchyDefinition)
    {
        $DatumHierarchyDefinition = @{}
    }

    [FileProvider]::new($Path, $Store, $DatumHierarchyDefinition, $Encoding)
}
#EndRegion '.\Public\New-DatumFileProvider.ps1' 33
#Region '.\Public\New-DatumStructure.ps1' 0
function New-DatumStructure
{
    [OutputType([hashtable])]
    [CmdletBinding(DefaultParameterSetName = 'FromConfigFile')]

    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'DatumHierarchyDefinition')]
        [Alias('Structure')]
        [hashtable]
        $DatumHierarchyDefinition,

        [Parameter(Mandatory = $true, ParameterSetName = 'FromConfigFile')]
        [System.IO.FileInfo]
        $DefinitionFile,

        [Parameter()]
        [ValidateSet('Ascii', 'BigEndianUnicode', 'Default', 'Unicode', 'UTF32', 'UTF7', 'UTF8')]
        [string]
        $Encoding = 'Default'
    )

    switch ($PSCmdlet.ParameterSetName)
    {
        'DatumHierarchyDefinition'
        {
            if ($DatumHierarchyDefinition.Contains('DatumStructure'))
            {
                Write-Debug -Message 'Loading Datum from Parameter'
            }
            elseif ($DatumHierarchyDefinition.Path)
            {
                $datumHierarchyFolder = $DatumHierarchyDefinition.Path
                Write-Debug -Message "Loading default Datum from given path $datumHierarchyFolder"
            }
            else
            {
                Write-Warning -Message 'Desperate attempt to load Datum from Invocation origin...'
                $callStack = Get-PSCallStack
                $datumHierarchyFolder = $callStack[-1].PSScriptRoot
                Write-Warning -Message " ---> $datumHierarchyFolder"
            }
        }

        'FromConfigFile'
        {
            if ((Test-Path -Path $DefinitionFile))
            {
                $DefinitionFile = (Get-Item -Path $DefinitionFile -ErrorAction Stop)
                Write-Debug -Message "File $DefinitionFile found. Loading..."
                $DatumHierarchyDefinition = Get-FileProviderData -Path $DefinitionFile.FullName -Encoding $Encoding
                if (-not $DatumHierarchyDefinition.Contains('ResolutionPrecedence'))
                {
                    throw 'Invalid Datum Hierarchy Definition'
                }
                $datumHierarchyFolder = $DefinitionFile.Directory.FullName
                $DatumHierarchyDefinition.DatumDefinitionFile = $DefinitionFile
                Write-Debug -Message "Datum Hierachy Parent folder: $datumHierarchyFolder"
            }
            else
            {
                throw 'Datum Hierarchy Configuration not found'
            }
        }
    }

    $root = @{}
    if ($datumHierarchyFolder -and -not $DatumHierarchyDefinition.DatumStructure)
    {
        $structures = foreach ($store in (Get-ChildItem -Directory -Path $datumHierarchyFolder))
        {
            @{
                StoreName     = $store.BaseName
                StoreProvider = 'Datum::File'
                StoreOptions  = @{
                    Path = $store.FullName
                }
            }
        }

        if ($DatumHierarchyDefinition.Contains('DatumStructure'))
        {
            $DatumHierarchyDefinition['DatumStructure'] = $structures
        }
        else
        {
            $DatumHierarchyDefinition.Add('DatumStructure', $structures)
        }
    }

    # Define the default hierachy to be the StoreNames, when nothing is specified
    if ($datumHierarchyFolder -and -not $DatumHierarchyDefinition.ResolutionPrecedence)
    {
        if ($DatumHierarchyDefinition.Contains('ResolutionPrecedence'))
        {
            $DatumHierarchyDefinition['ResolutionPrecedence'] = $structures.StoreName
        }
        else
        {
            $DatumHierarchyDefinition.Add('ResolutionPrecedence', $structures.StoreName)
        }
    }
    # Adding the Datum Definition to Root object
    $root.Add('__Definition', $DatumHierarchyDefinition)

    foreach ($store in $DatumHierarchyDefinition.DatumStructure)
    {
        $storeParams = @{
            Store    = (ConvertTo-Datum ([hashtable]$store).Clone())
            Path     = $store.StoreOptions.Path
            Encoding = $Encoding
        }

        # Accept Module Specification for Store Provider as String (unversioned) or Hashtable
        if ($store.StoreProvider -is [string])
        {
            $storeProviderModule, $storeProviderName = $store.StoreProvider -split '::'
        }
        else
        {
            $storeProviderModule = $store.StoreProvider.ModuleName
            $storeProviderName = $store.StoreProvider.ProviderName
            if ($store.StoreProvider.ModuleVersion)
            {
                $storeProviderModule = @{
                    ModuleName    = $storeProviderModule
                    ModuleVersion = $store.StoreProvider.ModuleVersion
                }
            }
        }

        if (-not ($module = Get-Module -Name $storeProviderModule -ErrorAction SilentlyContinue))
        {
            $module = Import-Module $storeProviderModule -Force -ErrorAction Stop -PassThru
        }
        $moduleName = ($module | Where-Object { $_.ExportedCommands.Keys -match 'New-Datum(\w+)Provider' }).Name

        $newProviderCmd = Get-Command ('{0}\New-Datum{1}Provider' -f $moduleName, $storeProviderName)

        if ($storeParams.Path -and -not [System.IO.Path]::IsPathRooted($storeParams.Path) -and $datumHierarchyFolder)
        {
            Write-Debug -Message 'Replacing Store Path with AbsolutePath'
            $storePath = Join-Path -Path $datumHierarchyFolder -ChildPath $storeParams.Path -Resolve -ErrorAction Stop
            $storeParams['Path'] = $storePath
        }

        if ($newProviderCmd.Parameters.Keys -contains 'DatumHierarchyDefinition')
        {
            Write-Debug -Message 'Adding DatumHierarchyDefinition to Store Params'
            $storeParams.Add('DatumHierarchyDefinition', $DatumHierarchyDefinition)
        }

        $storeObject = &$newProviderCmd @storeParams
        Write-Debug -Message "Adding key $($store.StoreName) to Datum root object"
        $root.Add($store.StoreName, $storeObject)
    }

    #return the Root Datum hashtable
    $root
}
#EndRegion '.\Public\New-DatumStructure.ps1' 160
#Region '.\Public\Resolve-Datum.ps1' 0
function Resolve-Datum
{
    [OutputType([System.Array])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $PropertyPath,

        [Parameter(Position = 1)]
        [Alias('Node')]
        [object]
        $Variable = $ExecutionContext.InvokeCommand.InvokeScript('$Node'),

        [Parameter()]
        [string]
        $VariableName = 'Node',

        [Parameter()]
        [Alias('DatumStructure')]
        [object]
        $DatumTree = $ExecutionContext.InvokeCommand.InvokeScript('$ConfigurationData.Datum'),

        [Parameter(ParameterSetName = 'UseMergeOptions')]
        [Alias('SearchBehavior')]
        [hashtable]
        $Options,

        [Parameter()]
        [Alias('SearchPaths')]
        [string[]]
        $PathPrefixes = $DatumTree.__Definition.ResolutionPrecedence,

        [Parameter()]
        [int]
        $MaxDepth = $(
            if ($mxdDpth = $DatumTree.__Definition.default_lookup_options.MaxDepth)
            {
                $mxdDpth
            }
            else
            {
                -1
            })
    )

    # Manage lookup options:
    <#
    default_lookup_options  Lookup_options  options (argument)  Behaviour
                MostSpecific for ^.*
    Present         default_lookup_options + most Specific if not ^.*
        Present     lookup_options + Default to most Specific if not ^.*
            Present options + Default to Most Specific if not ^.*
    Present Present     Lookup_options + Default for ^.* if !Exists
    Present     Present options + Default for ^.* if !Exists
        Present Present options override lookup options + Most Specific if !Exists
    Present Present Present options override lookup options + default for ^.*


    +========================+================+====================+============================================================+
    | default_lookup_options | Lookup_options | options (argument) |                         Behaviour                          |
    +========================+================+====================+============================================================+
    |                        |                |                    | MostSpecific for ^.*                                       |
    +------------------------+----------------+--------------------+------------------------------------------------------------+
    | Present                |                |                    | default_lookup_options + most Specific if not ^.*          |
    +------------------------+----------------+--------------------+------------------------------------------------------------+
    |                        | Present        |                    | lookup_options + Default to most Specific if not ^.*       |
    +------------------------+----------------+--------------------+------------------------------------------------------------+
    |                        |                | Present            | options + Default to Most Specific if not ^.*              |
    +------------------------+----------------+--------------------+------------------------------------------------------------+
    | Present                | Present        |                    | Lookup_options + Default for ^.* if !Exists                |
    +------------------------+----------------+--------------------+------------------------------------------------------------+
    | Present                |                | Present            | options + Default for ^.* if !Exists                       |
    +------------------------+----------------+--------------------+------------------------------------------------------------+
    |                        | Present        | Present            | options override lookup options + Most Specific if !Exists |
    +------------------------+----------------+--------------------+------------------------------------------------------------+
    | Present                | Present        | Present            | options override lookup options + default for ^.*          |
    +------------------------+----------------+--------------------+------------------------------------------------------------+

    If there's no default options, auto-add default options of mostSpecific merge, and tag as 'default'
    if there's a default options, use that strategy and tag as 'default'
    if the options implements ^.*, do not add Default_options, and do not tag

    1. Defaults to Most Specific
    2. Allow setting your own default, with precedence for non-default options
    3. Overriding ^.* without tagging it as default (always match unless)

    #>

    Write-Debug -Message "Resolve-Datum -PropertyPath <$PropertyPath> -Node $($Node.Name)"
    # Make options an ordered case insensitive variable
    if ($Options)
    {
        $Options = [ordered]@{} + $Options
    }

    if (-not $DatumTree.__Definition.default_lookup_options)
    {
        $default_options = Get-MergeStrategyFromString
        Write-Verbose -Message '  Default option not found in Datum Tree'
    }
    else
    {
        if ($DatumTree.__Definition.default_lookup_options -is [string])
        {
            $default_options = Get-MergeStrategyFromString -MergeStrategy $DatumTree.__Definition.default_lookup_options
        }
        else
        {
            $default_options = $DatumTree.__Definition.default_lookup_options
        }
        #TODO: Add default_option input validation
        Write-Verbose -Message "  Found default options in Datum Tree of type $($default_options.Strategy)."
    }

    if ($DatumTree.__Definition.lookup_options)
    {
        Write-Debug -Message '  Lookup options found.'
        $lookup_options = @{} + $DatumTree.__Definition.lookup_options
    }
    else
    {
        $lookup_options = @{}
    }

    # Transform options from string to strategy hashtable
    foreach ($optKey in ([string[]]$lookup_options.Keys))
    {
        if ($lookup_options[$optKey] -is [string])
        {
            $lookup_options[$optKey] = Get-MergeStrategyFromString -MergeStrategy $lookup_options[$optKey]
        }
    }

    foreach ($optKey in ([string[]]$Options.Keys))
    {
        if ($Options[$optKey] -is [string])
        {
            $Options[$optKey] = Get-MergeStrategyFromString -MergeStrategy $Options[$optKey]
        }
    }

    # using options if specified or lookup_options otherwise
    if (-not $Options)
    {
        $Options = $lookup_options
    }

    # Add default strategy for ^.* if not present, at the end
    if (([string[]]$Options.Keys) -notcontains '^.*')
    {
        # Adding Default flag
        $default_options['Default'] = $true
        $Options.Add('^.*', $default_options)
    }

    # Create the variable to be used as Pivot in prefix path
    if ($Variable -and $VariableName)
    {
        Set-Variable -Name $VariableName -Value $Variable -Force
    }

    # Scriptblock in path detection patterns
    $pattern = '(?<opening><%=)(?<sb>.*?)(?<closure>%>)'
    $propertySeparator = [System.IO.Path]::DirectorySeparatorChar
    $splitPattern = [regex]::Escape($propertySeparator)

    $depth = 0
    $mergeResult = $null

    # Get the strategy for this path, to be used for merging
    $startingMergeStrategy = Get-MergeStrategyFromPath -PropertyPath $PropertyPath -Strategies $Options

    #Invoke datum handlers
    $PathPrefixes = $PathPrefixes | ConvertTo-Datum -DatumHandlers $datum.__Definition.DatumHandlers

    # Walk every search path in listed order, and return datum when found at end of path
    foreach ($searchPrefix in $PathPrefixes)
    {
        #through the hierarchy
        $arraySb = [System.Collections.ArrayList]@()
        $currentSearch = Join-Path -Path $searchPrefix -ChildPath $PropertyPath
        Write-Verbose -Message ''
        Write-Verbose -Message " Lookup <$currentSearch> $($Node.Name)"
        #extract script block for execution into array, replace by substition strings {0},{1}...
        $newSearch = [regex]::Replace($currentSearch, $pattern, {
                param (
                    [Parameter()]
                    $match
                )

                $expr = $match.Groups['sb'].value
                $index = $arraySb.Add($expr)
                "`$({$index})"
            }, @('IgnoreCase', 'SingleLine', 'MultiLine'))

        $pathStack = $newSearch -split $splitPattern
        # Get value for this property path
        $datumFound = Resolve-DatumPath -Node $Node -DatumTree $DatumTree -PathStack $pathStack -PathVariables $arraySb

        if ($datumFound -is [DatumProvider])
        {
            $datumFound = $datumFound.ToOrderedHashTable()
        }

        Write-Debug -Message "  Depth: $depth; Merge options = $($Options.count)"

        #Stop processing further path at first value in 'MostSpecific' mode (called 'first' in Puppet hiera)
        if ($null -ne $datumFound -and ($startingMergeStrategy.Strategy -match '^MostSpecific|^First'))
        {
            return $datumFound
        }
        elseif ($null -ne $datumFound)
        {

            if ($null -eq $mergeResult)
            {
                $mergeResult = $datumFound
            }
            else
            {
                $mergeParams = @{
                    StartingPath    = $PropertyPath
                    ReferenceDatum  = $mergeResult
                    DifferenceDatum = $datumFound
                    Strategies      = $Options
                }
                $mergeResult = Merge-Datum @mergeParams
            }
        }

        #if we've reached the Maximum Depth allowed, return current result and stop further execution
        if ($depth -eq $MaxDepth)
        {
            Write-Debug "  Max depth of $MaxDepth reached. Stopping."
            , $mergeResult
            return
        }
    }
    , $mergeResult
}
#EndRegion '.\Public\Resolve-Datum.ps1' 242
#Region '.\Public\Resolve-DatumPath.ps1' 0
function Resolve-DatumPath
{
    [OutputType([System.Array])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [Alias('Variable')]
        $Node,

        [Parameter()]
        [Alias('DatumStructure')]
        [object]
        $DatumTree,

        [Parameter()]
        [string[]]
        $PathStack,

        [Parameter()]
        [System.Collections.ArrayList]
        $PathVariables
    )

    $currentNode = $DatumTree
    $propertySeparator = '.' #[System.IO.Path]::DirectorySeparatorChar
    $index = -1
    Write-Debug -Message "`t`t`t"

    foreach ($stackItem in $PathStack)
    {
        $index++
        $relativePath = $PathStack[0..$index]
        Write-Debug -Message "`t`t`tCurrent Path: `$Datum$propertySeparator$($relativePath -join $propertySeparator)"
        $remainingStack = $PathStack[$index..($PathStack.Count - 1)]
        Write-Debug -Message "`t`t`t`tbranch of path Left to walk: $propertySeparator$($remainingStack[1..$remainingStack.Length] -join $propertySeparator)"

        if ($stackItem -match '\{\d+\}')
        {
            Write-Debug -Message "`t`t`t`t`tReplacing expression $stackItem"
            $stackItem = [scriptblock]::Create(($stackItem -f ([string[]]$PathVariables)) ).Invoke()
            Write-Debug -Message ($stackItem | Format-List * | Out-String)
            $pathItem = $stackItem
        }
        else
        {
            $pathItem = $currentNode.($ExecutionContext.InvokeCommand.ExpandString($stackItem))
        }

        # if $pathItem is $null, it won't have subkeys, stop execution for this Prefix
        if ($null -eq $pathItem)
        {
            Write-Verbose -Message " NULL FOUND at `$Datum.$($ExecutionContext.InvokeCommand.ExpandString(($relativePath -join $propertySeparator) -f [string[]]$PathVariables))`t`t <`$Datum$propertySeparator$(($relativePath -join $propertySeparator) -f [string[]]$PathVariables)>"
            if ($remainingStack.Count -gt 1)
            {
                Write-Verbose -Message "`t`t----> before:  $propertySeparator$($ExecutionContext.InvokeCommand.ExpandString(($remainingStack[1..($remainingStack.Count-1)] -join $propertySeparator)))`t`t <$(($remainingStack[1..($remainingStack.Count-1)] -join $propertySeparator) -f [string[]]$PathVariables)>"
            }
            return $null
        }
        else
        {
            $currentNode = $pathItem
        }


        if ($remainingStack.Count -eq 1)
        {
            Write-Verbose -Message " VALUE found at `$Datum$propertySeparator$($ExecutionContext.InvokeCommand.ExpandString(($relativePath -join $propertySeparator) -f [string[]]$PathVariables))"
            , $currentNode
        }

    }
}
#EndRegion '.\Public\Resolve-DatumPath.ps1' 73
#Region '.\Public\Test-TestHandlerFilter.ps1' 0
function Test-TestHandlerFilter
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [object]$InputObject
    )

    $InputObject -is [string] -and $InputObject -match '^\[TEST=[\w\W]*\]$'
}
#EndRegion '.\Public\Test-TestHandlerFilter.ps1' 12

