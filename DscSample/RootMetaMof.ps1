[DscLocalConfigurationManager()]
Configuration RootMetaMOF {
    Node $ConfigurationData.AllNodes.GetEnumerator().NodeName {
        
        $LcmConfig = $(Lookup 'LcmConfig\Settings' $Null)
        #If the Nodename is a GUID, use Config ID instead Named config, as per SMB Pull requirements
        if($Node.Nodename -as [Guid]) {$LcmConfig['ConfigurationID'] = $Node.Nodename}
        x Settings '' $LcmConfig

        if($ConfigurationRepositoryShare = $(Lookup 'LcmConfig\ConfigurationRepositoryShare' $Null)) {
            x ConfigurationRepositoryShare ConfigurationRepositoryShare $ConfigurationRepositoryShare
        }

        if($ResourceRepositoryShare = $(Lookup 'LcmConfig\ResourceRepositoryShare' $Null)) {
            x ResourceRepositoryShare ResourceRepositoryShare $ResourceRepositoryShare
        }

        if($ConfigurationRepositoryWeb = $(Lookup 'LcmConfig\ConfigurationRepositoryWeb' $Null)) {
            foreach($ConfigRepoName in $ConfigurationRepositoryWeb.keys) {
                x ConfigurationRepositoryWeb $ConfigRepoName $ConfigurationRepositoryWeb[$ConfigRepoName]
            }
        }

        if($ResourceRepositoryWeb = $(Lookup 'LcmConfig\ResourceRepositoryWeb' $Null)) {
            foreach($ResourceRepoName in $ResourceRepositoryWeb.keys) {
                x ResourceRepositoryWeb $ResourceRepoName $ResourceRepositoryWeb[$ResourceRepoName]
            }
        }

        if($ReportServerWeb = $(Lookup 'LcmConfig\ReportServerWeb' $Null)) {
            x ReportServerWeb ReportServerWeb $ReportServerWeb
        }

        if($PartialConfiguration = $(Lookup 'LcmConfig\PartialConfiguration' $Null)) {
            foreach($PartialConfigurationName in $PartialConfiguration.keys) {
                x PartialConfiguration $PartialConfigurationName $PartialConfiguration[$PartialConfigurationName]
            }
        }
    }
}