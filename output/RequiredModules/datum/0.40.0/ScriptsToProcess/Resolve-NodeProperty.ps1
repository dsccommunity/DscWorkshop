function Global:Resolve-NodeProperty
{
    [OutputType([System.Array])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $PropertyPath,

        [Parameter(Position = 1)]
        [AllowNull()]
        [object]
        $DefaultValue,

        [Parameter(Position = 3)]
        $Node = $ExecutionContext.InvokeCommand.InvokeScript('$Node'),

        [Parameter()]
        [Alias('DatumStructure')]
        [object]
        $DatumTree = $ExecutionContext.InvokeCommand.InvokeScript('$ConfigurationData.Datum'),

        [Parameter()]
        [string[]]
        $SearchPaths,

        [Parameter(Position = 5)]
        [AllowNull()]
        [int]
        $MaxDepth
    )

    if ($Node -is [string] -and ($ConfigData = $ExecutionContext.InvokeCommand.InvokeScript('$ConfigurationData')))
    {
        $Node = $ConfigData.AllNodes.Where{ $_.Name -eq $Node -or $_.NodeName -eq $Node }
    }

    # Null result should return an exception, unless defined as Default value
    $nullAllowed = $false

    $ResolveDatumParams = ([hashtable]$PSBoundParameters).Clone()
    foreach ($removeKey in $PSBoundParameters.Keys.Where{ $_ -in @('DefaultValue', 'Node') })
    {
        $ResolveDatumParams.Remove($removeKey)
    }

    # Translate the DSC specific Node into the 'Node' variable and Node name used by Resolve-Datum
    if ($Node)
    {
        $ResolveDatumParams.Add('Variable', $Node)
        $ResolveDatumParams.Add('VariableName', 'Node')
    }

    # Starting DSC Behaviour: Resolve-Datum || $DefaultValue || $null if specified as default || throw
    if (($result = Resolve-Datum @ResolveDatumParams) -ne $null)
    {
        Write-Verbose "`tResult found for $PropertyPath"
    }
    elseif ($DefaultValue)
    {
        $result = $DefaultValue
        Write-Debug "`t`tDefault Found"
    }
    elseif ($PSBoundParameters.ContainsKey('DefaultValue') -and $null -eq $DefaultValue)
    {
        $result = $null
        $nullAllowed = $true
        Write-Debug "`t`tDefault NULL found and allowed."
    }
    else
    {
        #This is when the Lookup is initiated from a Composite Resource, for itself
        if (-not ($here = $PSScriptRoot))
        {
            $here = $PWD.Path
        }
        Write-Debug "`t`tAttempting to load datum from $($here)."

        $resourceConfigDataPath = Join-Path -Path $here -ChildPath 'ConfigData' -Resolve -ErrorAction SilentlyContinue

        if ($resourceConfigDataPath)
        {
            $datumDefinitionFile = Join-Path -Path $resourceConfigDataPath -ChildPath 'Datum.*' -Resolve -ErrorAction SilentlyContinue
            if ($datumDefinitionFile)
            {
                Write-Debug "Resource Datum File Path: $datumDefinitionFile"
                $resourceDatum = New-DatumStructure -DefinitionFile $datumDefinitionFile
            }
            else
            {
                #Loading Default Datum structure
                Write-Debug "Loading data store from $($resourceConfigDataPath)."
                $resourceDatum = New-DatumStructure -DatumHierarchyDefinition @{
                    Path = $resourceConfigDataPath
                }
            }
            $resolveDatumParams.Remove('DatumTree')

            $result = Resolve-Datum @resolveDatumParams -DatumTree $resourceDatum
        }
        else
        {
            Write-Warning "`tNo Datum store found for DSC Resource"
        }
    }

    if ($null -ne $result -or $nullAllowed)
    {
        ,$result
    }
    else
    {
        throw "The lookup of path '$PropertyPath' for node '$($Node.Name)' returned a Null value, but Null is not specified as Default. This is not allowed."
    }
}

Set-Alias -Name Lookup -Value Resolve-NodeProperty -Scope Global
Set-Alias -Name Resolve-DscProperty -Value Resolve-NodeProperty -Scope Global
