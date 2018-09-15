@{
    PSDependOptions              = @{
        AddToPath  = $true
        Target     = 'DSC_Resources'
        Parameters = @{
            Force = $true
        }
    }

    xPSDesiredStateConfiguration = '8.4.0.0'
    xDSCResourceDesigner         = '1.12.0.0'
    ComputerManagementDsc        = '5.2.0.0'
    NetworkingDsc                = '6.1.0.0'
}