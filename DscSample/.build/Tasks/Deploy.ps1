Task Deploy {

    if (-not ([System.IO.Path]::IsPathRooted($BuildOutput))) {
        $BuildOutput = Join-Path -Path $ProjectPath -ChildPath $BuildOutput
    }

    Write-Host "Starting deployment with files inside '$BuildOutput'"

    if ($env:BHBuildSystem -eq 'AppVeyor') {
        $artifactsPath = "$BuildOutput\CompressedArtifacts"
        if (-not (Test-Path -Path $artifactsPath)) {
            mkdir -Path $artifactsPath | Out-Null
        }
    
        Compress-Archive -Path $BuildOutput\MOF -DestinationPath "$BuildOutput\CompressedArtifacts\MOF.zip" -Force
        Compress-Archive -Path $BuildOutput\MetaMOF -DestinationPath "$BuildOutput\CompressedArtifacts\MetaMOF.zip" -Force

        Push-AppVeyorArtifact "$BuildOutput\CompressedArtifacts\MOF.zip" -FileName MOF.zip -DeploymentName MOF
        Push-AppVeyorArtifact "$BuildOutput\CompressedArtifacts\MetaMOF.zip" -FileName MetaMOF.zip -DeploymentName MetaMOF
    }
    elseif ($env:BUILD_REPOSITORY_PROVIDER -eq 'TfsGit' -and $env:RELEASE_ENVIRONMENTNAME) {
        Write-Host "Source Branch Name is: '$($env:BUILD_SOURCEBRANCHNAME )'"
        Write-Host "Release environment Name is : '$($env:RELEASE_ENVIRONMENTNAME)'"

        if ($env:BUILD_SOURCEBRANCHNAME -eq 'dev' -and $env:RELEASE_ENVIRONMENTNAME -ne 'Dev') {
            Write-Host 'Dev branch should be only deployed to Dev environment'
            return
        }
        
        Copy-DscMof -MofPath "$BuildOutput\MOF" -TargetPath $env:DscConfiguration -Environment $env:RELEASE_ENVIRONMENTNAME
        Copy-Item -Path "$BuildOutput\CompressedModules\*" -Destination $env:DscModules
    }
    
}