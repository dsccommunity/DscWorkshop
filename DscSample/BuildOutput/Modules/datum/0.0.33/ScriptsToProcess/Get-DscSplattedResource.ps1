function Global:Get-DscSplattedResource {
    [CmdletBinding()]
    Param(
        [String]
        $ResourceName,

        [String]
        $ExecutionName,

        [hashtable]
        $Properties,

        [switch]
        $NoInvoke
    )
    # Remove Case Sensitivity of ordered Dictionary or Hashtables
    $Properties = @{}+$Properties

    $stringBuilder = [System.Text.StringBuilder]::new()
    $null = $stringBuilder.AppendLine("Param([hashtable]`$Parameters)")
    $null = $stringBuilder.AppendLine()
    $null = $stringBuilder.AppendLine(" `$(`$Parameters=@{}+`$Parameters)")
    $null = $stringBuilder.AppendLine(" $ResourceName $ExecutionName { ")
    foreach($PropertyName in $Properties.keys) {
        $null = $stringBuilder.AppendLine("$PropertyName = `$(`$Parameters['$PropertyName'])")
    }
    $null = $stringBuilder.AppendLine("}")
    Write-Debug ("Generated Resource Block = {0}" -f $stringBuilder.ToString())

    if($NoInvoke.IsPresent) {
        [scriptblock]::Create($stringBuilder.ToString())
    }
    else {
        [scriptblock]::Create($stringBuilder.ToString()).Invoke($Properties)
    }
}
Set-Alias -Name x -Value Get-DscSplattedResource -scope Global
#Export-ModuleMember -Alias x
