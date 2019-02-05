Import-Module DscBuildHelpers

[DscLocalConfigurationManager()]
Configuration RootMetaMOF {
    Node $ConfigurationData.AllNodes.GetEnumerator().NodeName {
        
        $lcmConfig = Resolve-NodeProperty -PropertyPath LcmConfig\Settings -DefaultValue $null
        #If the Nodename is a GUID, use Config ID instead Named config, as per SMB Pull requirements
        if ($Node.Nodename -as [Guid]) {
            $lcmConfig['ConfigurationID'] = $Node.Nodename
        }
        (Get-DscSplattedResource -ResourceName Settings -ExecutionName '' -Properties $lcmConfig -NoInvoke).Invoke($lcmConfig)

        if ($configurationRepositoryShare = Resolve-NodeProperty -PropertyPath 'LcmConfig\ConfigurationRepositoryShare' -DefaultValue $null) {
            (Get-DscSplattedResource -ResourceName ConfigurationRepositoryShare -ExecutionName ConfigurationRepositoryShare -Properties $configurationRepositoryShare -NoInvoke).Invoke($configurationRepositoryShare)
        }

        if ($resourceRepositoryShare = Resolve-NodeProperty -PropertyPath 'LcmConfig\ResourceRepositoryShare' -DefaultValue $null) {
            (Get-DscSplattedResource -ResourceName ResourceRepositoryShare -ExecutionName ResourceRepositoryShare -Properties $resourceRepositoryShare -NoInvoke).Invoke($resourceRepositoryShare)
        }

        if ($configurationRepositoryWeb = Resolve-NodeProperty -PropertyPath 'LcmConfig\ConfigurationRepositoryWeb' -DefaultValue $null) {
            foreach ($configRepoName in $configurationRepositoryWeb.Keys) {
                (Get-DscSplattedResource -ResourceName ConfigurationRepositoryWeb -ExecutionName $configRepoName -Properties $configurationRepositoryWeb[$configRepoName] -NoInvoke).Invoke($configurationRepositoryWeb[$configRepoName])
            }
        }

        if ($resourceRepositoryWeb = Resolve-NodeProperty -PropertyPath 'LcmConfig\ResourceRepositoryWeb' -DefaultValue $null) {
            foreach ($resourceRepoName in $resourceRepositoryWeb.Keys) {
                (Get-DscSplattedResource -ResourceName ResourceRepositoryWeb -ExecutionName $resourceRepoName -Properties $resourceRepositoryWeb[$resourceRepoName] -NoInvoke).Invoke($resourceRepositoryWeb[$resourceRepoName])
            }
        }

        if ($reportServerWeb = Resolve-NodeProperty -PropertyPath 'LcmConfig\ReportServerWeb' -DefaultValue $null) {
            (Get-DscSplattedResource -ResourceName ReportServerWeb -ExecutionName ReportServerWeb -Properties $reportServerWeb -NoInvoke).Invoke($reportServerWeb)
        }

        if ($partialConfiguration = Resolve-NodeProperty -PropertyPath 'LcmConfig\PartialConfiguration' -DefaultValue $null) {
            foreach ($partialConfigurationName in $partialConfiguration.Keys) {
                (Get-DscSplattedResource -ResourceName PartialConfiguration -ExecutionName $partialConfigurationName -Properties $partialConfiguration[$partialConfigurationName] -NoInvoke).Invoke($partialConfiguration[$partialConfigurationName])
            }
        }
        
    }
}
