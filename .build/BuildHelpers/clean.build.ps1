Param (

    [io.DirectoryInfo]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [string]
    $BuildOutput = (property BuildOutput 'C:\BuildOutput'),

    [string]
    $LineSeparation = (property LineSeparation ('-' * 78)) 
)

task Clean_BuildOutput {
    # Synopsis: Clears the BuildOutput folder from its artefacts, but leaves the modules subfolder and its content. 

    if (![io.path]::IsPathRooted($BuildOutput)) {
        $BuildOutput = Join-Path -Path $ProjectPath.FullName -ChildPath $BuildOutput
    }
    if (Test-Path $BuildOutput) {
        "Removing $BuildOutput\*"
        Gci .\BuildOutput\ -Exclude modules,README.md,RSOP | Remove-Item -Force -Recurse
    }
}

task Clean_Module {
    # Synopsis: Clears the content of the BuildOutput folder INCLUDING the modules folder
     if (![io.path]::IsPathRooted($BuildOutput)) {
        $BuildOutput = Join-Path -Path $ProjectPath.FullName -ChildPath $BuildOutput
    }
    "Removing $BuildOutput\*"
    Get-ChildItem .\BuildOutput\ | Remove-Item -Force -Recurse -Verbose -ErrorAction Stop
}