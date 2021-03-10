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
        Compress-Archive -Path $BuildOutput\RSOP -DestinationPath "$BuildOutput\CompressedArtifacts\RSOP.zip" -Force
        Compress-Archive -Path $BuildOutput\CompressedModules -DestinationPath "$BuildOutput\CompressedArtifacts\CompressedModules.zip" -Force

        Push-AppVeyorArtifact "$BuildOutput\CompressedArtifacts\MOF.zip" -FileName MOF.zip -DeploymentName MOF
        Push-AppVeyorArtifact "$BuildOutput\CompressedArtifacts\MetaMOF.zip" -FileName MetaMOF.zip -DeploymentName MetaMOF
        Push-AppVeyorArtifact "$BuildOutput\CompressedArtifacts\RSOP.zip" -FileName RSOP.zip -DeploymentName RSOP
        Push-AppVeyorArtifact "$BuildOutput\CompressedArtifacts\CompressedModules.zip" -FileName CompressedModules.zip -DeploymentName CompressedModules
    }
    elseif ($env:BUILD_REPOSITORY_PROVIDER -eq 'TfsGit' -and $env:RELEASE_ENVIRONMENTNAME) {
        Write-Host "Source Branch Name is: '$($env:BUILD_SOURCEBRANCHNAME )'"
        Write-Host "Release environment Name is : '$($env:RELEASE_ENVIRONMENTNAME)'"

        if ($env:BUILD_SOURCEBRANCHNAME -eq 'dev' -and $env:RELEASE_ENVIRONMENTNAME -ne 'Dev') {
            Write-Host 'Dev branch should be only deployed to Dev environment'
            return
        }
        
        Copy-DscMof -MofPath "$BuildOutput\MOF" -TargetPath $env:DscConfiguration -Environment $env:RELEASE_ENVIRONMENTNAME
        Copy-DscMof -MofPath "$BuildOutput\MOF" -TargetPath $env:DscConfiguration -Environment $env:RELEASE_ENVIRONMENTNAME
        if (Test-Path -Path "$BuildOutput\CompressedModules\*") {
            Copy-Item -Path "$BuildOutput\CompressedModules\*" -Destination $env:DscModules
        }
        else {
            Write-Host "The folder '$BuildOutput\CompressedModules\*' does not exist, skipping deployment of CompressedModules." 
        }
    }
    
}