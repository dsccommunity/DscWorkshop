task PowerShell5Compatibility -if ($PSVersionTable.PSEdition -eq 'Desktop') {

    Remove-Item -Path $requiredModulesPath\PSDesiredStateConfiguration -ErrorAction Stop -Recurse -Force
    Write-Warning "'PSDesiredStateConfiguration' > 2.0 module is not supported on Windows PowerShell and not required for DSC compilation."
    Write-Warning "'PSDesiredStateConfiguration' was removed from the 'RequiredModules' folder."

}
