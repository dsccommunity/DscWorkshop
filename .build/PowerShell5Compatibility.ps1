task PowerShell5Compatibility -if ($PSVersionTable.PSEdition -eq 'Desktop') {

    $path = "$requiredModulesPath\PSDesiredStateConfiguration"
    if (Test-Path -Path $path)
    {
        Remove-Item -Path $path -ErrorAction Stop -Recurse -Force
        Write-Warning "'PSDesiredStateConfiguration' > 2.0 module is not supported on Windows PowerShell and not required for DSC compilation."
        Write-Warning "'PSDesiredStateConfiguration' was removed from the 'RequiredModules' folder."
    }
    else
    {
        Write-Host "Module 'PSDesiredStateConfiguration' > 2.0 module has already been removed."
    }

}
