task CompileRootMetaMof {

    if (-not (Test-Path -Path $BuildOutput\MetaMof)) {
        mkdir -Path $BuildOutput\MetaMof | Out-Null
    }

    if ($configurationData.AllNodes) {
        . (Join-Path -Path $ProjectPath -ChildPath RootMetaMof.ps1)
        $metaMofs = RootMetaMOF -ConfigurationData $configurationData -OutputPath (Join-Path -Path $BuildOutput -ChildPath MetaMof)
        Write-Build Green "Successfully compiled $($metaMofs.Count) Meta MOF files."
    }
    else {
        Write-Build Green "No data to compile Meta MOF files"
    }
}