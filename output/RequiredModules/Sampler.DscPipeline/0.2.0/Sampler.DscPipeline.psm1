#Region '.\Public\Get-DatumNodesRecursive.ps1' 0
using module datum

function Get-DatumNodesRecursive
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [object]
        $AllDatumNodes = (Get-Variable -Name Datum -ValueOnly).AllNodes
    )

    $datumContainers = [System.Collections.Queue]::new()

    Write-Verbose -Message "Inspecting [$($AllDatumNodes.PSObject.Properties.Where({$_.MemberType -eq 'ScriptProperty'}).Name -join ', ')]"
    $AllDatumNodes.PSObject.Properties.Where({ $_.MemberType -eq 'ScriptProperty' }).ForEach({
            Write-Verbose -Message "Working on '$($_.Name)'."
            $val = $_.Value | Add-Member -MemberType NoteProperty -Name Name -Value $_.Name -PassThru -ErrorAction Ignore -Force
            if ($val -is [FileProvider])
            {
                Write-Verbose -Message "Adding '$($val.Name)' to the queue."
                $datumContainers.Enqueue($val)
            }
            else
            {
                Write-Verbose -Message "Adding Node '$($_.Name)'."
                $val['Name'] = $_.Name
                $val
            }
        })

    while ($datumContainers.Count -gt 0)
    {
        $currentContainer = $datumContainers.Dequeue()
        Write-Debug -Message "Working on Container '$($currentContainer.Name)'."

        $currentContainer.PSObject.Properties.Where({ $_.MemberType -eq 'ScriptProperty' }).ForEach({
                $val = $currentContainer.($_.Name)
                $val | Add-Member -MemberType NoteProperty -Name Name -Value $_.Name -ErrorAction Ignore
                if ($val -is [FileProvider])
                {
                    Write-Verbose -Message "Found Container '$($_.Name).'"
                    $datumContainers.Enqueue($val)
                }
                else
                {
                    Write-Verbose -Message "Found Node '$($_.Name)'."
                    $val['Name'] = $_.Name
                    $val
                }
            })
    }
}
#EndRegion '.\Public\Get-DatumNodesRecursive.ps1' 54
#Region '.\Public\Get-DscErrorMessage.ps1' 0
function Get-DscErrorMessage
{
    param
    (
        [Parameter()]
        [System.Exception]
        $Exception
    )

    switch ($Exception)
    {
        { $_ -is [System.Management.Automation.ItemNotFoundException] }
        {
            #can be ignored, very likely caused by Get-Item within the PSDesiredStateConfiguration module
            break
        }

        { $_.Message -match "Unable to find repository 'PSGallery" }
        {
            'Error in Package Management'
            break
        }

        { $_.Message -match 'A second CIM class definition' }
        {
            # This happens when several versions of same module are available.
            # Mainly a problem when when $Env:PSModulePath is polluted or
            # DscResources or DSC_Configuration are not clean
            'Multiple version of the same module exist'
            break
        }

        { $_ -is [System.Management.Automation.ParentContainsErrorRecordException] }
        {
            "Compilation Error: $_.Message"
            break
        }

        { $_.Message -match ([regex]::Escape("Cannot find path 'HKLM:\SOFTWARE\Microsoft\Powershell\3\DSC'")) }
        {
            if ($_.InvocationInfo.PositionMessage -match 'PSDscAllowDomainUser')
            {
                # This tend to be repeated for all nodes even if only 1 is affected
                'Domain user credentials are used and PSDscAllowDomainUser is not set'
                break
            }
            elseif ($_.InvocationInfo.PositionMessage -match 'PSDscAllowPlainTextPassword')
            {
                "It is not recommended to use plain text password. Use PSDscAllowPlainTextPassword = `$false"
                break
            }
            else
            {
                #can be ignored
                break
            }
        }
    }
}
#EndRegion '.\Public\Get-DscErrorMessage.ps1' 60
#Region '.\Public\Get-DscMofEnvironment.ps1' 0
function Get-DscMofEnvironment
{
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Path
    )

    process
    {
        if (-not (Test-Path -Path $Path))
        {
            Write-Error -Message "The MOF file '$Path' cannot be found."
            return
        }

        $content = Get-Content -Path $Path

        $xRegistryDscEnvironment = $content | Select-String -Pattern '\[xRegistry\]DscEnvironment' -Context 0, 10
        if (-not $xRegistryDscEnvironment)
        {
            Write-Error -Message "No environment information found in MOF file '$Path'. The environment information must be added using the 'xRegistryx' named 'DscEnvironment'."
            return
        }

        $valueData = $xRegistryDscEnvironment.Context.PostContext | Select-String -Pattern 'ValueData' -Context 0, 1
        if (-not $valueData)
        {
            Write-Error -Message "Found the resource 'xRegistry' named 'DscEnvironment' in '$Path' but no ValueData in the expected range (10 lines after defining '[xRegistry]DscEnvironment'."
            return
        }

        $valueData.Context.PostContext[0].Trim().Replace('"', '')
    }
}
#EndRegion '.\Public\Get-DscMofEnvironment.ps1' 37
#Region '.\Public\Get-DscMofVersion.ps1' 0
function Get-DscMofVersion
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Path
    )

    process
    {
        if (-not (Test-Path -Path $Path))
        {
            Write-Error -Message  "The MOF file '$Path' cannot be found."
            return
        }

        $content = Get-Content -Path $Path

        $xRegistryDscVersion = $content | Select-String -Pattern '\[xRegistry\]DscVersion' -Context 0, 10

        if (-not $xRegistryDscVersion)
        {
            Write-Error -Message "No version information found in MOF file '$Path'. The version information must be added using the 'xRegistry' named 'DscVersion'."
            return
        }

        $valueData = $xRegistryDscVersion.Context.PostContext | Select-String -Pattern 'ValueData' -Context 0, 1
        if (-not $valueData)
        {
            Write-Error -Message "Found the resource 'xRegistry' named 'DscVersion' in '$Path' but no ValueData in the expected range (10 lines after defining '[xRegistry]DscVersion'."
            return
        }

        try
        {
            $value = $valueData.Context.PostContext[0].Trim().Replace('"', '')
            [String]$value
        }
        catch
        {
            Write-Error -Message  "ValueData could not be converted into 'System.Version'. The value taken from the MOF file was '$value'"
            return
        }
    }
}
#EndRegion '.\Public\Get-DscMofVersion.ps1' 49
#Region '.\Public\Get-FilteredConfigurationData.ps1' 0
function Get-FilteredConfigurationData
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param
    (
        [Parameter()]
        [ScriptBlock]
        $Filter = {},

        [Parameter()]
        [int]
        $CurrentJobNumber = 1,

        [Parameter()]
        [int]
        $TotalJobCount = 1,

        [Parameter()]
        [Object]
        $Datum = $(Get-Variable -Name Datum -ValueOnly -ErrorAction Stop)
    )

    if ($null -eq $Filter)
    {
        $Filter = {}
    }

    try
    {
        $allDatumNodes = [System.Collections.Hashtable[]]@(Get-DatumNodesRecursive -AllDatumNodes $Datum.AllNodes -ErrorAction Stop)
    }
    catch
    {
        Write-Error -Message "Could not get datum nodes. Pretty likely there is a syntax error in one of the node's yaml definitions." -Exception $_.Exception
    }
    $totalNodeCount = $allDatumNodes.Count

    Write-Verbose -Message "Node count: $($allDatumNodes.Count)"

    if ($Filter.ToString() -ne {}.ToString())
    {
        Write-Verbose -Message "Filter: $($Filter.ToString())"
        $allDatumNodes = [System.Collections.Hashtable[]]$allDatumNodes.Where($Filter)
        Write-Verbose -Message "Node count after applying filter: $($allDatumNodes.Count)"
    }

    if (-not $allDatumNodes.Count)
    {
        Write-Error -Message "No node data found. There are in total $totalNodeCount nodes defined, but no node was selected. You may want to verify the filter: '$Filter'."
    }

    $CurrentJobNumber--
    $allDatumNodes = Split-Array -List $allDatumNodes -ChunkCount $TotalJobCount
    $allDatumNodes = $allDatumNodes[$CurrentJobNumber]

    return @{
        AllNodes = $allDatumNodes
        Datum    = $Datum
    }
}
#EndRegion '.\Public\Get-FilteredConfigurationData.ps1' 55
#Region '.\Public\Split-Array.ps1' 0
function Split-Array
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]
        $List,

        [Parameter(Mandatory = $true, ParameterSetName = 'ChunkSize')]
        [int]
        $ChunkSize,

        [Parameter(Mandatory = $true, ParameterSetName = 'ChunkCount')]
        [int]
        $ChunkCount
    )

    $aggregateList = @()

    if ($ChunkCount)
    {
        $ChunkSize = [Math]::Ceiling($List.Count / $ChunkCount)
    }

    $blocks = [Math]::Floor($List.Count / $ChunkSize)
    $leftOver = $List.Count % $ChunkSize
    for ($i = 0; $i -lt $blocks; $i++)
    {
        $end = $ChunkSize * ($i + 1) - 1

        $aggregateList += @(, $List[$start..$end])
        $start = $end + 1
    }

    if ($leftOver -gt 0)
    {
        $aggregateList += @(, $List[$start..($end + $leftOver)])
    }

    , $aggregateList
}
#EndRegion '.\Public\Split-Array.ps1' 42
#Region '.\suffix.ps1' 0
# Inspired from https://github.com/nightroman/Invoke-Build/blob/64f3434e1daa806814852049771f4b7d3ec4d3a3/Tasks/Import/README.md#example-2-import-from-a-module-with-tasks
Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'tasks\*') -Include '*.build.*' |
    ForEach-Object -Process {
        $ModuleName = ([System.IO.FileInfo] $MyInvocation.MyCommand.Name).BaseName
        $taskFileAliasName = "$($_.BaseName).$ModuleName.ib.tasks"

        Set-Alias -Name $taskFileAliasName -Value $_.FullName

        Export-ModuleMember -Alias $taskFileAliasName
    }
#EndRegion '.\suffix.ps1' 11
