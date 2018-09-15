@{
    PSDependOptions = @{
        AddToPath  = $true
        Target     = 'DSC_Configurations'
        Parameters = @{
            Force = $true
        }
    }

    CommonTasks     = 'latest'
}