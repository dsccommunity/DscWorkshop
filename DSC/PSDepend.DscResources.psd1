@{
    PSDependOptions              = @{
        AddToPath      = $true
        Target         = 'DscResources'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    xPSDesiredStateConfiguration = '8.10.0.0'
    ComputerManagementDsc        = '7.0.0.0'
    NetworkingDsc                = '7.4.0.0'
    JeaDsc                       = '0.6.5'
    XmlContentDsc                = '0.0.1'
    xWebAdministration           = '2.8.0.0'
    SecurityPolicyDsc            = '2.10.0.0'
    StorageDsc                   = '4.8.0.0' 
    
}
