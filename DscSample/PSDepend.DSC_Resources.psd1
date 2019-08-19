@{
    PSDependOptions              = @{
        AddToPath      = $true
        Target         = 'DSC_Resources'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    xPSDesiredStateConfiguration = '8.9.0.0'
    xDSCResourceDesigner         = '1.12.0.0'
    ComputerManagementDsc        = '6.5.0.0'
    NetworkingDsc                = '7.3.0.0'
    JeaDsc                       = '0.6.5'
    XmlContentDsc                = '0.0.1'
    xWebAdministration           = '2.7.0.0'
    SecurityPolicyDsc            = '2.9.0.0'
    
}
