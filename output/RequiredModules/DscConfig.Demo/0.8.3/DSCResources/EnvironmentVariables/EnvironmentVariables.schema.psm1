configuration EnvironmentVariables {
    param (
        [Parameter()]
        [hashtable[]]
        $Variables
    )

<#
xEnvironment [String] #ResourceName
{
    Name = [string]
    [DependsOn = [string[]]]
    [Ensure = [string]{ Absent | Present }]
    [Path = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [Target = [string[]]{ Machine | Process }]
    [Value = [string]]
}
#>

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    foreach ($variable in $Variables)
    {
        $variable = @{} + $variable

        if (-not $variable.ContainsKey('Ensure'))
        {
            $variable.Ensure = 'Present'
        }

        (Get-DscSplattedResource -ResourceName xEnvironment -ExecutionName $variable.Name -Properties $variable -NoInvoke).Invoke($variable)
    }
}
