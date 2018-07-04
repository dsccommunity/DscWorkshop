param (
    [System.IO.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [String]
    $BuildOutput = (property BuildOutput 'C:\BuildOutput'),

    [String]
    $LineSeparation = (property LineSeparation ('-' * 78)) 
)

task Clean_BuildOutput {
    # Synopsis: Clears the BuildOutput folder from its artefacts, but leaves the modules subfolder and its content. 

    if (![System.IO.Path]::IsPathRooted($BuildOutput)) 
    {
        $BuildOutput = Join-Path -Path $ProjectPath.FullName -ChildPath $BuildOutput
    }
    if (Test-Path $BuildOutput) 
    {
        "Removing $BuildOutput\*"
        Get-ChildItem -Path .\BuildOutput\ -Exclude Modules, README.md | Remove-Item -Force -Recurse
    }
}

task Clean_Module {
    # Synopsis: Clears the content of the BuildOutput folder INCLUDING the modules folder
    if (![System.IO.Path]::IsPathRooted($BuildOutput)) 
    {
        $BuildOutput = Join-Path -Path $ProjectPath.FullName -ChildPath $BuildOutput
    }
    "Removing $BuildOutput\*"
    Get-ChildItem -Path .\BuildOutput\ | Remove-Item -Force -Recurse -Verbose -ErrorAction Stop
}