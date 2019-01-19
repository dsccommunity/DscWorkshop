@{
    PSDependOptions = @{
        AddToPath      = $true
        Target         = 'DSC_Configurations'
        DependencyType = 'PSGalleryModule'
        Parameters     = @{
            Repository = 'PSGallery'
        }
    }

    CommonTasks     = '0.2.2'
}