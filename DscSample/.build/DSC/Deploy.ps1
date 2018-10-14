Task Deploy {

    Write-Host "Starting deployment with files inside '$ProjectPath'"

    $Params = @{
        Path    = $ProjectPath
        Force   = $true
        Recurse = $false
        Verbose = $true
    }
    Invoke-PSDeploy @Params
    
}