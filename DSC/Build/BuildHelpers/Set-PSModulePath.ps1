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

    #$duplicateModules = Get-Module -ListAvailable | Group-Object -Property Name, Version | Where-Object Count -gt 1
    #Write-Host "Found $($duplicateModules.Count) duplicate modules"
    #Write-Host 'Removing modules...'
    #foreach ($duplicateModule in $duplicateModules.Group) {
    #    Write-Host "`t$($duplicateModule.Name)"
    #    foreach ($path in $PathsToSet) {
    #        if ($duplicateModule.Path -like "$path*") {
    #            $path = "$path\$($duplicateModule.Name)"
    #            Remove-Item -Path $path -Recurse -Force
    #        }
    #    }
    #}

}