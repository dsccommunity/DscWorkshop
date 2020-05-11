@{
    PSDependOptions              = @{
        AddToPath      = $true
        Target         = 'DscResources'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    xPSDesiredStateConfiguration = '9.1.0'
    ComputerManagementDsc        = '8.2.0'
    NetworkingDsc                = '7.4.0.0'
    JeaDsc                       = '0.6.5'
    XmlContentDsc                = '0.0.1'
    xWebAdministration           = '3.1.1'
    SecurityPolicyDsc            = '2.10.0.0'
    StorageDsc                   = '5.0.0'
    Chocolatey                   = '0.0.79'
    
}
