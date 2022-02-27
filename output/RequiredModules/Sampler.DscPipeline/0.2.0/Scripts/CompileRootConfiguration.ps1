Import-Module -Name DscBuildHelpers
$Error.Clear()

if (-not $ModuleVersion)
{
    $ModuleVersion = '0.0.0'
}

$environment = $node.Environment
if (-not $environment)
{
    $environment = 'NA'
}

$rsopCache = Get-DatumRsopCache

<#
This information is taken from build.yaml

Sampler.DscPipeline:
  DscCompositeResourceModules:
  - Name: CommonTasks
    Version: 0.3.259
  - PSDesiredStateConfiguration
#>

if (-not $BuildInfo.'Sampler.DscPipeline')
{
    Write-Error -Message "There are no modules to import defined in the 'build.yml'. Expected the element 'Sampler.DscPipeline'"
}
if (-not $BuildInfo.'Sampler.DscPipeline'.DscCompositeResourceModules)
{
    Write-Error -Message "There are no modules to import defined in the 'build.yml'. Expected the element 'Sampler.DscPipeline'.DscCompositeResourceModules"
}
if ($BuildInfo.'Sampler.DscPipeline'.DscCompositeResourceModules.Count -lt 1)
{
    Write-Error -Message "There are no modules to import defined in the 'build.yml'. Expected at least one module defined under 'Sampler.DscPipeline'.DscCompositeResourceModules"
}

Write-Host -Object "RootConfiguration will import these composite resource modules as defined in 'build.yaml':"
$importStatements = foreach ($module in $BuildInfo.'Sampler.DscPipeline'.DscCompositeResourceModules)
{
    if ($module -is [hashtable])
    {
        Write-Host -Object "`t- $($module.Name) ($($module.Version))"
        "Import-DscResource -ModuleName $($module.Name) -ModuleVersion $($module.Version)`n"
    }
    else
    {
        Write-Host -Object "`t- $module"
        "Import-DscResource -ModuleName $module`n"
    }
}
Write-Host

$rootConfiguration = Get-Content -Path $PSScriptRoot\RootConfiguration.ps1 -Raw
$rootConfiguration = $rootConfiguration -replace '#<importStatements>', $importStatements

Invoke-Expression -Command $rootConfiguration

$cd = @{}
$cd.Datum = $ConfigurationData.Datum

foreach ($node in $rsopCache.GetEnumerator())
{
    $cd.AllNodes = @([hashtable]$node.Value)
    try
    {
        $path = Join-Path -Path MOF -ChildPath $node.Environment
        RootConfiguration -ConfigurationData $cd -OutputPath (Join-Path -Path $BuildOutput -ChildPath $path)
    }
    catch
    {
        Write-Host -Object "Error occured during compilation of node '$($node.NodeName)' : $($_.Exception.Message)" -ForegroundColor Red
        $relevantErrors = $Error | Where-Object Exception -IsNot [System.Management.Automation.ItemNotFoundException]
        Write-Host -Object ($relevantErrors[0..2] | Out-String) -ForegroundColor Red
    }
}
