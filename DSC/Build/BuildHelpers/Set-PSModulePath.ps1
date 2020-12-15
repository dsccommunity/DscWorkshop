function Set-PSModulePath {
    param(
        [String[]]
        $ModuleToLeaveLoaded,

        [String[]]
        $PathsToSet = @()
    )

    $env:PSModulePath = Join-Path -Path $PShome -ChildPath Modules
    
    Get-Module | Where-Object { $_.Name -notin $ModuleToLeaveLoaded } | Remove-Module -Force

    $PathsToSet.Foreach{
        if ($_ -notin ($env:PSModulePath -split ';')) {
            $env:PSModulePath = "$_;$($Env:PSModulePath)"
        }
    }

}