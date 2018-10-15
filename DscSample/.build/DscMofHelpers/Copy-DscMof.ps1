function Copy-DscMof
{
    param(
        [Parameter(Mandatory)]
        [string]$MofPath,

        [Parameter(Mandatory)]
        [string]$Environment,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    if (-not (Test-Path -Path $MofPath)) {
        Write-Error "The MOF file '$MofPath' cannot be found."
        return
    }
    if (-not (Test-Path -Path $TargetPath)) {
        Write-Error "The MOF file '$TargetPath' cannot be found."
        return
    }

    $mofFiles = dir -Path "$MofPath\*" -Include *.mof
    if (-not $mofFiles)
    {
        Write-Error "No Mof files found in directory '$MofPath'"
        return
    }

    foreach ($mofFile in $mofFiles)
    {
        if (($mofFile | Get-DscMofEnvironment) -eq $Environment) {
            Copy-Item -Path $mofFile.FullName -Destination $TargetPath -Force 
            Copy-Item -Path "$($mofFile.FullName).checksum" -Destination $TargetPath -Force
        }
    }
}