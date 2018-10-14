if ($env:BHBuildSystem -eq 'AppVeyor' -and $env:BHBranchName -eq "master") {

}
elseif ($env:BUILD_REPOSITORY_PROVIDER -eq 'TfsGit' -and $env:BUILD_SOURCEBRANCHNAME -eq "master") {

}
else {
    "Skipping deployment: To deploy, ensure that...`n" +
    "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" +
    "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" +
    "`t* Module path is valid (Current: )" |
        Write-Host
}

# Publish to AppVeyor if we're in AppVeyor
if ($env:BHBuildSystem -eq 'AppVeyor') {
    Write-Host "Creating build with version '$($env:APPVEYOR_BUILD_VERSION)'"
    Deploy MOF {
        By FileSystem  {
            FromSource "$($env:BHBuildOutput)\MOF"
            To AppVeyor
            Tagged MOFs
            WithOptions @{
                Mirror = $true
            }
        }
    }

    Deploy MetaMOF {
        By FileSystem  {
            FromSource "$($env:BHBuildOutput)\MetaMOF"
            To AppVeyor
            Tagged MetaMOFs
            WithOptions @{
                Mirror = $true
            }
        }
    }
}