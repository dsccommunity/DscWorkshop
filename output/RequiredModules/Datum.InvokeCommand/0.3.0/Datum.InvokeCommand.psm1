#Region '.\Prefix.ps1' 0
$here = $PSScriptRoot
$modulePath = Join-Path -Path $here -ChildPath 'Modules'

Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

$script:localizedData = Get-LocalizedData -DefaultUICulture en-US

$config = Import-PowerShellDataFile -Path $here\Config\Datum.InvokeCommand.Config.psd1
$regExString = '{0}(?<Content>((.|\s)+)?){1}' -f [regex]::Escape($config.Header), [regex]::Escape($config.Footer)
$global:datumInvokeCommandRegEx = New-Object Text.RegularExpressions.Regex($regExString, ('IgnoreCase', 'Compiled'))
#EndRegion '.\Prefix.ps1' 11
#Region '.\Private\Get-DatumCurrentNode.ps1' 0
function Get-DatumCurrentNode
{
    param (
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]
        $File
    )

    $fileNode = $File | Get-Content | ConvertFrom-Yaml
    $rsopNode = Get-DatumRsop -Datum $datum -AllNodes $currentNode

    if ($rsopNode)
    {
        $rsopNode
    }
    else
    {
        $fileNode
    }
}
#EndRegion '.\Private\Get-DatumCurrentNode.ps1' 21
#Region '.\Private\Get-RelativeNodeFileName.ps1' 0
function Get-RelativeNodeFileName
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]
        $Path
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
        Write-Verbose 'Get-RelativeNodeFileName: nothing to catch'
    }
}
#EndRegion '.\Private\Get-RelativeNodeFileName.ps1' 28
#Region '.\Private\Get-ValueKind.ps1' 0
function Get-ValueKind
{
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InputObject
    )

    $errors = $null
    $tokens = $null

    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $InputObject,
        [ref]$tokens,
        [ref]$errors
    )

    $InputObject = $InputObject.Trim()

    if ($InputObject -notmatch '^{[\s\S]+}$|^"[\s\S]+"$|^''[\s\S]+''$')
    {
        Write-Error 'Get-ValueKind: The input object is not an ExpandableString, nor a literal string or ScriptBlock'
    }
    elseif (($tokens[0].Kind -eq 'LCurly' -and $tokens[-2].Kind -eq 'RCurly' -and $tokens[-1].Kind -eq 'EndOfInput') -or
        ($tokens[0].Kind -eq 'LCurly' -and $tokens[-3].Kind -eq 'RCurly' -and $tokens[-2].Kind -eq 'NewLine' -and $tokens[-1].Kind -eq 'EndOfInput'))
    {
        @{
            Kind  = 'ScriptBlock'
            Value = $InputObject
        }
    }
    elseif ($tokens.Where({ $_.Kind -eq 'StringExpandable' }).Count -eq 1)
    {
        @{
            Kind  = 'ExpandableString'
            Value = $tokens.Where({ $_.Kind -eq 'StringExpandable' }).Value
        }
    }
    elseif ($tokens.Where({ $_.Kind -eq 'StringLiteral' }).Count -eq 1)
    {
        Write-Warning "Get-ValueKind: The value '$InputObject' is a literal string and cannot be expanded."
        @{
            Kind  = 'LiteralString'
            Value = $tokens.Where({ $_.Kind -eq 'StringLiteral' }).Value
        }
    }
    else
    {
        Write-Error "Get-ValueKind: The value '$InputObject' could not be parsed. It is not a scriptblock nor a string."
    }
}
#EndRegion '.\Private\Get-ValueKind.ps1' 54
#Region '.\Private\Invoke-InvokeCommandActionInternal.ps1' 0
function Invoke-InvokeCommandActionInternal
{
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $DatumType,

        [Parameter()]
        [hashtable]
        $Datum
    )

    if (-not $datum -and $DatumTree)
    {
        $datum = $DatumTree
    }

    #Prevent self-referencing loop
    if (($DatumType.Value.Contains('Get-DatumRsop')) -and ((Get-PSCallStack).Command | Where-Object { $_ -eq 'Get-DatumRsop' }).Count -gt 1)
    {
        return $DatumType.Value
    }

    try
    {
        $callId = New-Guid
        $start = Get-Date
        $global:CurrentDatumNode = $Node
        $global:CurrentDatumFile = $file

        Write-Verbose "Invoking command '$($DatumType.Value)'. CallId is '$callId'"

        $result = if ($DatumType.Kind -eq 'ScriptBlock')
        {
            $command = [scriptblock]::Create($DatumType.Value)
            & (& $command)
        }
        elseif ($DatumType.Kind -eq 'ExpandableString')
        {
            $ExecutionContext.InvokeCommand.ExpandString($DatumType.Value)
        }
        else
        {
            $DatumType.Value
        }

        $dynamicPart = $true
        while ($dynamicPart)
        {
            if ($dynamicPart = Test-InvokeCommandFilter -InputObject $result -ReturnValue)
            {
                $innerResult = Invoke-InvokeCommandAction -InputObject $result -Datum $Datum -Node $node
                $result = $result.Replace($dynamicPart, $innerResult)
            }
        }
        $duration = (Get-Date) - $start
        Write-Verbose "Invoke with CallId '$callId' has taken $([System.Math]::Round($duration.TotalSeconds, 2)) seconds"

        if ($result -is [string])
        {
            $ExecutionContext.InvokeCommand.ExpandString($result)
        }
        else
        {
            $result
        }
    }
    catch
    {
        Write-Error -Message ($script:localizedData.CannotCreateScriptBlock -f $DatumType.Value, $_.Exception.Message) -Exception $_.Exception
        return $DatumType.Value
    }
}
#EndRegion '.\Private\Invoke-InvokeCommandActionInternal.ps1' 74
#Region '.\Public\Invoke-InvokeCommandAction.ps1' 0
function Invoke-InvokeCommandAction
{
    <#
    .SYNOPSIS
    Call the scriptblock that is given via Datum.

    .DESCRIPTION
    When Datum uses this handler to invoke whatever script block is given to it. The returned
    data is used as configuration data.

    .PARAMETER InputObject
    Script block to invoke

    .PARAMETER Header
    Header of the Datum data string that encapsulates the script block.
    The default is [Command= but can be customized (i.e. in the Datum.yml configuration file)

    .PARAMETER Footer
    Footer of the Datum data string that encapsulates the encrypted data. The default is ]

    .EXAMPLE
    $command | Invoke-ProtectedDatumAction

    .NOTES
    The arguments you can set in the Datum.yml is directly related to the arguments of this function.

    #>
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [object]
        $InputObject,

        [Parameter()]
        [hashtable]
        $Datum,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [object]
        $Node
    )

    $throwOnError = [bool]$datum.__Definition.DatumHandlersThrowOnError

    if ($InputObject -is [array])
    {
        $returnValue = @()
    }
    else
    {
        $returnValue = $null
    }

    foreach ($value in $InputObject)
    {
        $regexResult = ($datumInvokeCommandRegEx.Match($value).Groups['Content'].Value)
        if (-not $regexResult -and $throwOnError)
        {
            Write-Error "Could not get the content for the Datum.InvokeCommand handler, RegEx '$($datumInvokeCommandRegEx.ToString())' did not succeed." -ErrorAction Stop
        }
        elseif (-not $regexResult -and -not $throwOnError)
        {
            Write-Warning "Could not get the content for the Datum.InvokeCommand handler, RegEx '$($datumInvokeCommandRegEx.ToString())' did not succeed."
            $returnValue += $value
            continue
        }

        $datumType = Get-ValueKind -InputObject $regexResult -ErrorAction (& { if ($throwOnError)
                {
                    'Stop'
                }
                else
                {
                    'Continue'
                } })

        if ($datumType)
        {
            try
            {
                $file = Get-Item -Path $value.__File -ErrorAction Ignore
            }
            catch
            {
                Write-Verbose 'Invoke-InvokeCommandAction: Nothing to catch'
            }

            if (-not $Node -and $file)
            {
                if ($file.Name -ne 'Datum.yml')
                {
                    $Node = Get-DatumCurrentNode -File $file

                    if (-not $Node)
                    {
                        return $value
                    }
                }
            }

            try
            {
                $returnValue += (Invoke-InvokeCommandActionInternal -DatumType $datumType -Datum $Datum -ErrorAction Stop).ForEach({
                        $_ | Add-Member -Name __File -MemberType NoteProperty -Value "$file" -PassThru -Force
                    })

            }
            catch
            {
                $throwOnError = [bool]$datum.__Definition.DatumHandlersThrowOnError

                if ($throwOnError)
                {
                    Write-Error -Message "Error using Datum Handler $Handler, the error was: '$($_.Exception.Message)'. Returning InputObject ($InputObject)." -Exception $_.Exception -ErrorAction Stop
                }
                else
                {
                    Write-Warning "Error using Datum Handler $Handler, the error was: '$($_.Exception.Message)'. Returning InputObject ($InputObject)."
                    $returnValue += $value
                    continue
                }
            }
        }
        else
        {
            $returnValue += $value
        }
    }

    if ($InputObject -is [array])
    {
        , $returnValue
    }
    else
    {
        $returnValue
    }
}
#EndRegion '.\Public\Invoke-InvokeCommandAction.ps1' 139
#Region '.\Public\Test-InvokeCommandFilter.ps1' 0
function Test-InvokeCommandFilter
{
    <#
    .SYNOPSIS
    Filter function to verify if it's worth triggering the action for the data block.

    .DESCRIPTION
    This function is run in the ConvertTo-Datum function of the Datum module on every pass,
    and when it returns true, the action of the handler is called.

    .PARAMETER InputObject
    Object to test to decide whether to trigger the action or not

    .EXAMPLE
    $object | Test-ProtectedDatumFilter

    #>
    param (
        [Parameter(ValueFromPipeline = $true)]
        [object]
        $InputObject,

        [Parameter()]
        [switch]
        $ReturnValue
    )

    if ($InputObject -is [string])
    {
        $all = $datumInvokeCommandRegEx.Match($InputObject.Trim()).Groups['0'].Value
        $content = $datumInvokeCommandRegEx.Match($InputObject.Trim()).Groups['Content'].Value

        if ($ReturnValue -and $content)
        {
            $all
        }
        elseif ($content)
        {
            return $true
        }
        else
        {
            return $false
        }
    }
    else
    {
        return $false
    }
}
#EndRegion '.\Public\Test-InvokeCommandFilter.ps1' 51

