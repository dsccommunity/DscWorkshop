@{
    PSDependOptions              = @{
        AddToPath      = $true
        Target         = 'DSC_Resources'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    xPSDesiredStateConfiguration = '8.7.0.0'
    xDSCResourceDesigner         = '1.12.0.0'
    ComputerManagementDsc        = '6.4.0.0'
    NetworkingDsc                = '7.2.0.0'
    JeaDsc                       = '0.6.4'
    XmlContentDsc                = '0.0.1'
    xWebAdministration           = '2.6.0.0'
}
