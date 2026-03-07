task NoWinPSCompatibility -if ($PSVersionTable.PSEdition -eq 'Core') {

    # On PowerShell 7, Get-DscResource scans C:\Windows\system32\WindowsPowerShell\v1.0\Modules
    # and encounters Desktop-only modules like Microsoft.PowerShell.Management.
    # PS 7 automatically creates a WinPSCompatSession remoting session to load them,
    # producing dozens of warnings during DSC compilation.
    # Using -SkipEditionCheck tells PS 7 to load these modules directly in-process
    # without creating a compatibility remoting session.
    $global:PSDefaultParameterValues['Import-Module:SkipEditionCheck'] = $true
    Write-Build DarkGray 'Set Import-Module -SkipEditionCheck to suppress WinPSCompatSession warnings on PS 7.'

}
