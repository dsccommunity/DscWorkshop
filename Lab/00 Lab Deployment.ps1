param (
    [Parameter(Mandatory)]
    [ValidateSet('Azure', 'HyperV')]
    [string]
    $HostType
)

Import-Module -Name AutomatedLab, AutomatedLab.Common -ErrorAction Stop

$files = dir -Path $PSScriptRoot -File | Where-Object Name -NotLike 00*
$files = $files | Where-Object { $_ -ne ($files | Where-Object { $_.Name -like '10*' -and $_.Name -notlike "10 $HostType*" }) }

foreach ($file in $files)
{
    Write-Host "Calling script '$($file.FullName)'" -ForegroundColor Magenta
    & $file.FullName
}
