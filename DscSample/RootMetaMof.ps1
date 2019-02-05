Import-Module DscBuildHelpers

[DscLocalConfigurationManager()]
Configuration RootMetaMOF {
    Node $ConfigurationData.AllNodes.GetEnumerator().NodeName {

        $LcmConfig = $(Lookup 'LcmConfig\Settings' $Null)
        #If the Nodename is a GUID, use Config ID instead Named config, as per SMB Pull requirements
        if($Node.Nodename -as [Guid]) {$LcmConfig['ConfigurationID'] = $Node.Nodename}
        (Get-DscSplattedResource Settings '' $LcmConfig -NoInvoke).Invoke($LcmConfig)

        if($ConfigurationRepositoryShare = $(Lookup 'LcmConfig\ConfigurationRepositoryShare' $Null)) {
            (Get-DscSplattedResource ConfigurationRepositoryShare ConfigurationRepositoryShare $ConfigurationRepositoryShare -NoInvoke).Invoke($ConfigurationRepositoryShare)
        }

        if($ResourceRepositoryShare = $(Lookup 'LcmConfig\ResourceRepositoryShare' $Null)) {
            (Get-DscSplattedResource ResourceRepositoryShare ResourceRepositoryShare $ResourceRepositoryShare -NoInvoke).Invoke($ResourceRepositoryShare)
        }

        if($ConfigurationRepositoryWeb = $(Lookup 'LcmConfig\ConfigurationRepositoryWeb' $Null)) {
            foreach($ConfigRepoName in $ConfigurationRepositoryWeb.keys) {
                (Get-DscSplattedResource ConfigurationRepositoryWeb $ConfigRepoName $ConfigurationRepositoryWeb[$ConfigRepoName] -NoInvoke).Invoke($ConfigurationRepositoryWeb[$ConfigRepoName])
            }
        }

        if($ResourceRepositoryWeb = $(Lookup 'LcmConfig\ResourceRepositoryWeb' $Null)) {
            foreach($ResourceRepoName in $ResourceRepositoryWeb.keys) {
                (Get-DscSplattedResource ResourceRepositoryWeb $ResourceRepoName $ResourceRepositoryWeb[$ResourceRepoName] -NoInvoke).Invoke($ResourceRepositoryWeb[$ResourceRepoName])
            }
        }

        if($ReportServerWeb = $(Lookup 'LcmConfig\ReportServerWeb' $Null)) {
            (Get-DscSplattedResource ReportServerWeb ReportServerWeb $ReportServerWeb -NoInvoke).Invoke($ReportServerWeb)
        }

        if($PartialConfiguration = $(Lookup 'LcmConfig\PartialConfiguration' $Null)) {
            foreach($PartialConfigurationName in $PartialConfiguration.keys) {
                (Get-DscSplattedResource PartialConfiguration $PartialConfigurationName $PartialConfiguration[$PartialConfigurationName] -NoInvoke).Invoke($PartialConfiguration[$PartialConfigurationName])
            }
        }
    }
}