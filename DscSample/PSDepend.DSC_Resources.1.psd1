@{
    #PSDepend dependencies
    
    PSDependOptions              = @{
        AddToPath  = $True
        Target     = 'DSC_Resources'
        Parameters = @{
            #Force = $True
            #Import = $True
        }
    }

    xPSDesiredStateConfiguration = 'latest'
    xDscResourceDesigner         = 'latest'
}
