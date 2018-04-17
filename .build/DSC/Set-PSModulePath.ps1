function Set-PSModulePath {
    Param(
        $ModuleToLeaveLoaded,

        [String[]]
        $PathsToSet = @()
    )

    if(Get-Module PSDesiredStateConfiguration) {
        Remove-Module -Force PSDesiredStateConfiguration
    }

    $Env:PSModulePath = Join-Path $PShome 'modules'
    Get-Module | Where-Object {$_.Name -notin $ModuleToLeaveLoaded} | Remove-Module -Force

    $PathsToSet.Foreach{
        if($_ -notin ($Env:PSModulePath -split ';')) {
            $Env:PSModulePath = $_ + ';' + $Env:PSModulePath
        }
    }
}