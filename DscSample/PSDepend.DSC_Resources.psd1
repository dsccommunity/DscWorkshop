@{
    PSDependOptions              = @{
        AddToPath  = $True
        Target     = 'DSC_Resources'
        Parameters = @{
            Force = $true
        }
    }

    xPSDesiredStateConfiguration = 'latest'
    xDscResourceDesigner         = 'latest'
}