@{
    PSDependOptions              = @{
        AddToPath      = $true
        Target         = 'DscResources'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    xPSDesiredStateConfiguration = '9.0.0'
    ComputerManagementDsc        = '8.0.0-preview0001'
    NetworkingDsc                = '8.0.0-preview0001'
    JeaDsc                       = '0.6.5'
    XmlContentDsc                = '0.0.1'
    xWebAdministration           = '3.1.1'
    SecurityPolicyDsc            = '2.10.0.0'
    StorageDsc                   = '4.9.0.0' 
    
}
