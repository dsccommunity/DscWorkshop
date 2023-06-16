configuration RegistryValues {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Values
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    foreach ($value in $values)
    {
        if (-not $value.ContainsKey('Ensure'))
        {
            $value.Ensure = 'Present'
        }
        if ([String]::IsNullOrEmpty($value.ValueName))
        {
            $value.ValueName = ''
        }
        if ([String]::IsNullOrEmpty($value.ValueData) -and ($value.Ensure -eq 'Present'))
        {
            $value.ValueData = ''
        }
        $executionName = ($value.Key + '__' + $value.ValueName) -replace '[\s(){}/\\:-]', '_'
        (Get-DscSplattedResource -ResourceName xRegistry -ExecutionName $executionName -Properties $value -NoInvoke).Invoke($value)
    }
}
