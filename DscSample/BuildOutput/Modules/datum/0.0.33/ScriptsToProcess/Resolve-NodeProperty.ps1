function Global:Resolve-NodeProperty {
    [CmdletBinding()]
    Param(
        [Parameter(
            Mandatory,
            Position = 0
        )]
        $PropertyPath,

        [Parameter(
            Position = 1
        )]
        [AllowNull()]
        $DefaultValue,

        [Parameter(
            Position = 3
        )]
        $Node = $ExecutionContext.InvokeCommand.InvokeScript('$Node'),

        [Alias('DatumStructure')]
        $DatumTree = $ExecutionContext.InvokeCommand.InvokeScript('$ConfigurationData.Datum'),

        [Alias('SearchBehavior')]
        [AllowNull()]
        $options,

        [string[]]
        $SearchPaths,

        [Parameter(
            Position = 5
        )]
        [allowNull()]
        [int]
        $MaxDepth
    )

    if ($Node -is [string] -and ($ConfigData = $ExecutionContext.InvokeCommand.InvokeScript('$ConfigurationData'))) {
        $Node = $ConfigData.AllNodes.Where{$_.Name -eq $Node -or $_.NodeName -eq $Node}
    }

    # Null result should return an exception, unless defined as Default value
    $NullAllowed = $false

    $ResolveDatumParams = ([hashtable]$PSBoundParameters).Clone()
    foreach ($removeKey in $PSBoundParameters.keys.where{$_ -in @('DefaultValue','Node')}) {
        $ResolveDatumParams.remove($removeKey)
    }

    # Translate the DSC specific Node into the 'Node' variable and Node name used by Resolve-Datum
    if($Node) {
        $ResolveDatumParams.Add('Variable',$Node)
        $ResolveDatumParams.Add('VariableName','Node')
    }

    # Starting DSC Behaviour: Resolve-Datum || $DefaultValue || $null if specified as default || throw
    if($result = Resolve-Datum @ResolveDatumParams) {
        Write-Verbose "`tResult found for $PropertyPath"
    }
    elseif($DefaultValue) {
        $result = $DefaultValue
        Write-Debug "`t`tDefault Found"
    }
    elseif($PSboundParameters.containsKey('DefaultValue') -and $null -eq $DefaultValue) {
        $result = $null
        $NullAllowed = $true
        Write-Debug "`t`tDefault NULL found and allowed."
    }
    else {
        #This is when the Lookup is initiated from a Composite Resource, for itself

        if(-not ($here = $MyInvocation.PSScriptRoot)) {
            $here = $Pwd.Path
        }
        Write-Debug "`t`tAttempting to load datum from $($here)."

        $ResourceConfigDataPath = Join-Path $here 'ConfigData' -Resolve -ErrorAction SilentlyContinue

        if($ResourceConfigDataPath) {
            $DatumDefinitionFile = Join-Path $ResourceConfigDataPath 'Datum.*' -Resolve -ErrorAction SilentlyContinue
            if($DatumDefinitionFile) {
                Write-Debug "Resource Datum File Path: $DatumDefinitionFile"
                $ResourceDatum = New-DatumStructure -DefinitionFile $DatumDefinitionFile
            }
            else {
                #Loading Default Datum structure
                Write-Debug "Loading data store from $($ResourceConfigDataPath)."
                $ResourceDatum = New-DatumStructure -DatumHierarchyDefinition @{
                    Path = $ResourceConfigDataPath
                }
            }
            $ResolveDatumParams.remove('DatumTree')

            $result = Resolve-Datum @ResolveDatumParams -DatumTree $ResourceDatum
        }
        else {
            Write-Warning "`tNo Datum store found for DSC Resource"
        }
    }

    if($null -ne $result -or $NullAllowed) {
        Write-Output $result -NoEnumerate
    }
    else {
        throw "The lookup of path '$PropertyPath' for node '$($node.Name)' returned a Null value, but Null is not specified as Default. This is not allowed." 
    }
}
Set-Alias -Name Lookup -Value Resolve-NodeProperty -scope Global
Set-Alias -Name Resolve-DscProperty -Value Resolve-NodeProperty -scope Global
