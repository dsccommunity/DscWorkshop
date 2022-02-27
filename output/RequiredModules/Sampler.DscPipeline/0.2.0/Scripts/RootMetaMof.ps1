Import-Module DscBuildHelpers

[DscLocalConfigurationManager()]
Configuration RootMetaMOF {

    $rsopCache = Get-DatumRsopCache

    Node $ConfigurationData.AllNodes.NodeName {

        $clonedProperties = $rsopCache."$($Node.Name)".LcmConfig

        $lcmConfig = $clonedProperties.Settings

        #If the Nodename is a GUID, use Config ID instead Named config, as per SMB Pull requirements
        if ($Node.Nodename -as [Guid])
        {
            $lcmConfig['ConfigurationID'] = $Node.Nodename
        }
        (Get-DscSplattedResource -ResourceName Settings -ExecutionName '' -Properties $lcmConfig -NoInvoke).Invoke($lcmConfig)

        if ($configurationRepositoryShare = $clonedProperties.ConfigurationRepositoryShare)
        {
            (Get-DscSplattedResource -ResourceName ConfigurationRepositoryShare -ExecutionName ConfigurationRepositoryShare -Properties $configurationRepositoryShare -NoInvoke).Invoke($configurationRepositoryShare)
        }

        if ($resourceRepositoryShare = $clonedProperties.ResourceRepositoryShare)
        {
            (Get-DscSplattedResource -ResourceName ResourceRepositoryShare -ExecutionName ResourceRepositoryShare -Properties $resourceRepositoryShare -NoInvoke).Invoke($resourceRepositoryShare)
        }

        if ($configurationRepositoryWeb = $clonedProperties.ConfigurationRepositoryWeb)
        {
            foreach ($configRepoName in $configurationRepositoryWeb.Keys)
            {
                (Get-DscSplattedResource -ResourceName ConfigurationRepositoryWeb -ExecutionName $configRepoName -Properties $configurationRepositoryWeb[$configRepoName] -NoInvoke).Invoke($configurationRepositoryWeb[$configRepoName])
            }
        }

        if ($resourceRepositoryWeb = $clonedProperties.ResourceRepositoryWeb)
        {
            foreach ($resourceRepoName in $resourceRepositoryWeb.Keys)
            {
                (Get-DscSplattedResource -ResourceName ResourceRepositoryWeb -ExecutionName $resourceRepoName -Properties $resourceRepositoryWeb[$resourceRepoName] -NoInvoke).Invoke($resourceRepositoryWeb[$resourceRepoName])
            }
        }

        if ($reportServerWeb = $clonedProperties.ReportServerWeb)
        {
            (Get-DscSplattedResource -ResourceName ReportServerWeb -ExecutionName ReportServerWeb -Properties $reportServerWeb -NoInvoke).Invoke($reportServerWeb)
        }

        if ($partialConfiguration = $clonedProperties.PartialConfiguration)
        {
            foreach ($partialConfigurationName in $partialConfiguration.Keys)
            {
                (Get-DscSplattedResource -ResourceName PartialConfiguration -ExecutionName $partialConfigurationName -Properties $partialConfiguration[$partialConfigurationName] -NoInvoke).Invoke($partialConfiguration[$partialConfigurationName])
            }
        }

    }
}
