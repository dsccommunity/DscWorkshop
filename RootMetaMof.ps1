[DscLocalConfigurationManager()]
Configuration RootMetaMOF {
    Node $ConfigurationData.AllNodes.Nodename {
        
        $LcmConfig = $(Lookup 'LCM_Config\Settings' $Null)
        #If the Nodename is a GUID, use Config ID instead Named config, as per SMB Pull requirements
        if($Node.Nodename -as [Guid]) {$LcmConfig['ConfigurationID'] = $Node.Nodename}
        x Settings '' $LcmConfig

        if($ConfigurationRepositoryShare = $(Lookup 'LCM_Config\ConfigurationRepositoryShare' $Null)) {
            x ConfigurationRepositoryShare ConfigurationRepositoryShare $ConfigurationRepositoryShare
        }

        if($ResourceRepositoryShare = $(Lookup 'LCM_Config\ResourceRepositoryShare' $Null)) {
            x ResourceRepositoryShare ResourceRepositoryShare $ResourceRepositoryShare
        }

        if($ConfigurationRepositoryWeb = $(Lookup 'LCM_Config\ConfigurationRepositoryWeb' $Null)) {
            foreach($ConfigRepoName in $ConfigurationRepositoryWeb.keys) {
                x ConfigurationRepositoryWeb $ConfigRepoName $ConfigurationRepositoryWeb[$ConfigRepoName]
            }
        }

        if($ResourceRepositoryWeb = $(Lookup 'LCM_Config\ResourceRepositoryWeb' $Null)) {
            foreach($ResourceRepoName in $ResourceRepositoryWeb.keys) {
                x ResourceRepositoryWeb $ResourceRepoName $ResourceRepositoryWeb[$ResourceRepoName]
            }
        }

        if($ReportServerWeb = $(Lookup 'LCM_Config\ReportServerWeb' $Null)) {
            x ReportServerWeb ReportServerWeb $ReportServerWeb
        }

        if($PartialConfiguration = $(Lookup 'LCM_Config\PartialConfiguration' $Null)) {
            foreach($PartialConfigurationName in $PartialConfiguration.keys) {
                x PartialConfiguration $PartialConfigurationName $PartialConfiguration[$PartialConfigurationName]
            }
        }
    }
}