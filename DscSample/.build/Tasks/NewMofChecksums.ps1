task NewMofChecksums {
    $mofs = Get-ChildItem -Path (Join-Path -Path $BuildOutput -ChildPath MOF)
    foreach ($mof in $mofs)
    {
        if ($mof.BaseName -in $global:configurationData.AllNodes.NodeName)
        {
            New-DscChecksum -Path $mof.FullName -Verbose:$false -Force
        }
    }
}