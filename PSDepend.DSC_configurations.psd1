@{
    # Set up a mini virtual environment...
    PSDependOptions = @{
        AddToPath = $True
        Target = 'DSC_Configurations'
        Parameters = @{
            #Force = $True
            #Import = $True
        }
    }

    #'gaelcolas/sharedDscConfig' = 'master'
}