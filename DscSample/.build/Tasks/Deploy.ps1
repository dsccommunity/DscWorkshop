Task Deploy {

    Write-Host "Starting deployment with files inside '$buildOutput'"
    $artifactsPath = "$buildOutput\CompressedArtifacts"
    if (-not (Test-Path -Path $artifactsPath)) {
        mkdir -Path $artifactsPath | Out-Null
    }

    Compress-Archive -Path $buildOutput\MOF -DestinationPath "$buildOutput\CompressedArtifacts\MOF.zip" -Force
    Compress-Archive -Path $buildOutput\MetaMOF -DestinationPath "$buildOutput\CompressedArtifacts\MetaMOF.zip" -Force

    if ($env:BHBuildSystem -eq 'AppVeyor') {
        Push-AppVeyorArtifact "$buildOutput\CompressedArtifacts\MOF.zip" -FileName MOF.zip -DeploymentName MOF
        Push-AppVeyorArtifact "$buildOutput\CompressedArtifacts\MetaMOF.zip" -FileName MetaMOF.zip -DeploymentName MetaMOF
    }
    
}