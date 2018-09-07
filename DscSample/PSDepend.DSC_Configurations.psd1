@{
    # Set up a mini virtual environment...
    PSDependOptions = @{
        AddToPath  = $true
        Target     = 'DSC_Configurations'
        Parameters = @{
            Force = $true
        }
    }

    CommonTasks     = 'latest'
}