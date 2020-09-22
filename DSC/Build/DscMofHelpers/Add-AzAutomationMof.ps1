function Add-AzAutomationMof
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $MofPath,

        [Parameter(Mandatory)]
        [string]
        $Environment
    )

    foreach ($mof in (Get-ChildItem -Path $mof -Filter *.mof))
    {
        if (($mof | Get-DscMofEnvironment) -ne $Environment) { continue }
        Import-AzAutomationDscNodeConfiguration -Path $mof.FullName -ConfigurationName $Environment -ResourceGroupName $env:AutomationAccountRgName -AutomationAccountName $env:AutomationAccountName -Verbose -Force
    }
}