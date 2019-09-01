task CompileRootMetaMof {

    . (Join-Path -Path $ProjectPath -ChildPath RootMetaMof.ps1)
    $metaMofs = RootMetaMOF -ConfigurationData $configurationData -OutputPath (Join-Path -Path $BuildOutput -ChildPath MetaMof)
    Write-Build Green "Successfully compiled $($metaMofs.Count) MOF files"
    
}