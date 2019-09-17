param (
    [System.IO.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [String]
    $BuildOutput = (property BuildOutput 'C:\BuildOutput'),

    [String]
    $LineSeparation = (property LineSeparation ('-' * 78)) 
)

task CleanBuildOutput {
    # Synopsis: Clears the BuildOutput folder from its artefacts, but leaves the modules subfolder and its content. 

    if (-not [System.IO.Path]::IsPathRooted($BuildOutput)) 
    {
        $BuildOutput = Join-Path -Path $ProjectPath.FullName -ChildPath $BuildOutput
    }
    if (Test-Path $BuildOutput) 
    {
        Write-Host "Removing $BuildOutput\*"
        Get-ChildItem -Path $BuildOutput -Exclude Modules | Remove-Item -Force -Recurse
    }
}

task CleanModule {
    # Synopsis: Clears the content of the BuildOutput folder INCLUDING the modules folder
    if (-not [System.IO.Path]::IsPathRooted($BuildOutput)) 
    {
        $BuildOutput = Join-Path -Path $ProjectPath.FullName -ChildPath $BuildOutput
    }
    Write-Host "Removing $BuildOutput\*"
    Get-ChildItem -Path .\BuildOutput\ | Remove-Item -Force -Recurse -Verbose -ErrorAction Stop
}
