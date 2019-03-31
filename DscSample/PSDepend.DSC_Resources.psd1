@{
    PSDependOptions              = @{
        AddToPath      = $true
        Target         = 'DSC_Resources'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    xPSDesiredStateConfiguration = '8.5.0.0'
    xDSCResourceDesigner         = '1.12.0.0'
    ComputerManagementDsc        = '6.2.0.0'
    NetworkingDsc                = '7.0.0.0'
    JeaDsc                       = '0.5.0'
    XmlContentDsc                = '0.0.1'
}
