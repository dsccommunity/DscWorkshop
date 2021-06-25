task GenerateArmTemplate {
    $outputPath = Join-Path -Path $BuildOutput -ChildPath ARMTemplates
    if (-not (Test-Path -Path $outputPath))
    {
        $null = New-Item -ItemType Directory -Path $outputPath 
    }

    if (-not $env:SharedAccessSignature)
    {
        Write-Build Yellow 'No shared access signature stored in $env:SharedAccessSignature, templates will need to be manually updated'
    }

    # Collect resolved node configuration    
    $rsopData = if ($configurationData.AllNodes)
    {
        Write-Build Green "Generating RSOP output for $($configurationData.AllNodes.Count) nodes."
        $configurationData.AllNodes |
        Where-Object Name -ne * |
        ForEach-Object {
            $nodeRSOP = Get-DatumRsop -Datum $datum -AllNodes ([ordered]@{ } + $_)
            $nodeRSOP
        }
    }
    else
    {
        Write-Build Green "No data for generating RSOP output."
    }

    $environments = $rsopData.Environment | Sort-Object -Unique
    $locations = $rsopData.Location | Sort-Object -Unique

    Write-Build Green "Generating ARM templates for $($environments.Count) environments"
    foreach ($environmentName in $environments)
    {
        $globalTemplateName = Join-Path -Path $outputPath -ChildPath "$($environmentName).json"
        $globalTemplate = @{
            '$schema'      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
            contentVersion = '1.0.0.0'                
            parameters     = @{
                machineSize                    = @{
                    "type"          = "string"
                    "defaultValue"  = "small"
                    "allowedValues" = @(
                        "small"
                        "medium"
                        "large"
                    )
                    "metadata"      = @{
                        "description" = "Machine sizing"
                    }
                }
                installApplicationServices     = @{
                    "type"          = "string"
                    "defaultValue"  = "True"
                    "allowedValues" = @(
                        "True"
                        "False"
                    )
                    "metadata"      = @{
                        "description" = "Flag controlling that application services are deployed"
                    }
                }
                "artifactLocation"             = @{
                    "type"     = "string"
                    "metadata" = @{
                        "description" = "The location of resources, such as templates and DSC modules, that the template depends on"
                    }
                }
                "systemAdminUsername"          = @{
                    "type"     = "string"
                    "metadata" = @{
                        "description" = "The name of the administrator account of the new VM"
                    }
                }
                "systemAdminPassword"          = @{
                    "type"     = "securestring"
                    "metadata" = @{
                        "description" = "The password for the administrator account of the new VM and domain"
                    }
                }
                "installDirectoryServices"     = @{
                    "type"          = "string"
                    "defaultValue"  = "True"
                    "allowedValues" = @(
                        "True"
                        "False"
                    )
                    "metadata"      = @{
                        "description" = "A flag to control the installation of Directory services"
                    }
                }
                "installFileServices"          = @{
                    "type"          = "string"
                    "defaultValue"  = "True"
                    "allowedValues" = @(
                        "True"
                        "False"
                    )
                    "metadata"      = @{
                        "description" = "A flag to control the installation of file services"
                    }
                }
                "installExchangeServices"      = @{
                    "type"          = "string"
                    "defaultValue"  = "False"
                    "allowedValues" = @(
                        "True"
                        "False"
                    )
                    "metadata"      = @{
                        "description" = "A flag to control the installation of Exchange mail services"
                    }
                }
                "installSQLServices"           = @{
                    "type"          = "string"
                    "defaultValue"  = "False"
                    "allowedValues" = @(
                        "True"
                        "False"
                    )
                    "metadata"      = @{
                        "description" = "A flag to control the installation of SQL services"
                    }
                }
                "installSharePointServices"    = @{
                    "type"          = "string"
                    "defaultValue"  = "False"
                    "allowedValues" = @(
                        "True"
                        "False"
                    )
                    "metadata"      = @{
                        "description" = "A flag to control the installation of SharePoint services"
                    }
                }
                "installCertificateServices"   = @{
                    "type"          = "string"
                    "defaultValue"  = "False"
                    "allowedValues" = @(
                        "True"
                        "False"
                    )
                    "metadata"      = @{
                        "description" = "A flag to control the installation of Active Directory Certificate Services"
                    }
                }
                automationAccountResourceGroup = @{
                    type     = 'string'
                    metadata = @{
                        description = 'Automation Account resource group'
                    }
                }
                automationAccountName          = @{
                    type     = 'string'
                    metadata = @{
                        description = 'Automation Account Name'
                    }
                }
            }
            variables      = @{
                "armArtifactLocation" = "[parameters('artifactLocation')]"
            }
            resources      = @()
        }

        foreach ($site in $locations)
        {
            $globalTemplate.resources += @{
                "type"       = "Microsoft.Resources/deployments"
                "name"       = "$($environmentName)$($site)"
                "apiVersion" = "[providers('Microsoft.Resources','deployments').apiVersions[0]]"
                "properties" = @{
                    "mode"         = "Incremental"
                    "templateLink" = @{
                        "uri"            = "[concat(variables('armArtifactLocation'), '$($environmentName)_$($site).json$($env:SharedAccessSignature)')]"
                        "contentVersion" = "1.0.0.0"
                    }
                    "parameters"   = @{ 
                        "artifactLocation"             = @{value = "[parameters('artifactLocation')]" }
                        "systemAdminUsername"          = @{value = "[parameters('systemAdminUsername')]" }
                        "systemAdminPassword"          = @{value = "[parameters('systemAdminPassword')]" }
                        automationAccountName          = @{value = "[parameters('automationAccountName')]" }
                        automationAccountResourceGroup = @{value = "[parameters('automationAccountResourceGroup')]" }
                    }
                }
            }

            # Prepare template to link other templates in
            $siteTemplateName = Join-Path -Path $outputPath -ChildPath "$($environmentName)_$($site).json$($env:SharedAccessSignature)"
            $siteTemplate = @{
                '$schema'      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
                contentVersion = '1.0.0.0'                
                parameters     = @{
                    "artifactLocation"             = @{
                        "type"     = "string"
                        "metadata" = @{
                            "description" = "The location of resources, such as templates and DSC modules, that the template depends on"
                        }
                    }
                    "systemAdminUsername"          = @{
                        "type"     = "string"
                        "metadata" = @{
                            "description" = "The name of the administrator account of the new VM"
                        }
                    }
                    "systemAdminPassword"          = @{
                        "type"     = "securestring"
                        "metadata" = @{
                            "description" = "The password for the administrator account of the new VM and domain"
                        }
                    }
                    "installDirectoryServices"     = @{
                        "type"          = "string"
                        "defaultValue"  = "True"
                        "allowedValues" = @(
                            "True"
                            "False"
                        )
                        "metadata"      = @{
                            "description" = "A flag to control the installation of Directory services"
                        }
                    }
                    "installFileServices"          = @{
                        "type"          = "string"
                        "defaultValue"  = "False"
                        "allowedValues" = @(
                            "True"
                            "False"
                        )
                        "metadata"      = @{
                            "description" = "A flag to control the installation of file services"
                        }
                    }
                    "installExchangeServices"      = @{
                        "type"          = "string"
                        "defaultValue"  = "False"
                        "allowedValues" = @(
                            "True"
                            "False"
                        )
                        "metadata"      = @{
                            "description" = "A flag to control the installation of Exchange mail services"
                        }
                    }
                    "installSQLServices"           = @{
                        "type"          = "string"
                        "defaultValue"  = "False"
                        "allowedValues" = @(
                            "True"
                            "False"
                        )
                        "metadata"      = @{
                            "description" = "A flag to control the installation of SQL services"
                        }
                    }
                    "installSharePointServices"    = @{
                        "type"          = "string"
                        "defaultValue"  = "False"
                        "allowedValues" = @(
                            "True"
                            "False"
                        )
                        "metadata"      = @{
                            "description" = "A flag to control the installation of SharePoint services"
                        }
                    }
                    "installCertificateServices"   = @{
                        "type"          = "string"
                        "defaultValue"  = "False"
                        "allowedValues" = @(
                            "True"
                            "False"
                        )
                        "metadata"      = @{
                            "description" = "A flag to control the installation of Active Directory Certificate Services"
                        }
                    }
                    automationAccountName          = @{
                        type     = 'string'
                        metadata = @{
                            description = 'Automation Account Name'
                        }
                    }
                    automationAccountResourceGroup = @{
                        type     = 'string'
                        metadata = @{
                            description = 'Automation Account resource group'
                        }
                    }
                }
                variables      = @{
                    "armArtifactLocation" = "[parameters('artifactLocation')]"
                }
                resources      = @()
            }

            $siteTemplate.resources += @{
                "type"       = "Microsoft.Resources/deployments"
                "name"       = "$($environmentName)$($site)CoreInfrastructure"
                "apiVersion" = "[providers('Microsoft.Resources','deployments').apiVersions[0]]"
                "properties" = @{
                    "mode"         = "Incremental"
                    "templateLink" = @{
                        "uri"            = "[concat(variables('armArtifactLocation'), '$($environmentName)_$($site)_core.json$($env:SharedAccessSignature)')]"
                        "contentVersion" = "1.0.0.0"
                    }
                    "parameters"   = @{ 
                        "artifactLocation"               = @{value = "[parameters('artifactLocation')]" }
                        "systemAdminUsername"            = @{value = "[parameters('systemAdminUsername')]" }
                        "systemAdminPassword"            = @{value = "[parameters('systemAdminPassword')]" }
                        automationAccountName            = @{value = "[parameters('automationAccountName')]" }
                        "automationAccountResourceGroup" = @{value = "[parameters('automationAccountResourceGroup')]" }
                    }
                }
            }

            # Prepare linked templates
            $templateName = Join-Path -Path $outputPath -ChildPath "$($environmentName)_$($site)_core.json"

            # Hashtables to collect globally reused data like supernets
            $vnets = @{ }

            # Template hashtable
            $template = @{
                '$schema'      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
                contentVersion = '1.0.0.0'
                parameters     = @{
                    "artifactLocation"             = @{
                        "type"     = "string"
                        "metadata" = @{
                            "description" = "The location of resources, such as templates and DSC modules, that the template depends on"
                        }
                    }
                    "systemAdminUsername"          = @{
                        "type"     = "string"
                        "metadata" = @{
                            "description" = "The name of the administrator account of the new VM"
                        }
                    }
                    "systemAdminPassword"          = @{
                        "type"     = "securestring"
                        "metadata" = @{
                            "description" = "The password for the administrator account of the new VM and domain"
                        }
                    }
                    automationAccountName          = @{
                        type     = 'string'
                        metadata = @{
                            description = 'Automation Account Name'
                        }
                    }
                    automationAccountResourceGroup = @{
                        type     = 'string'
                        metadata = @{
                            description = 'Automation Account resource group'
                        }
                    }
                }
                resources      = @()
            }

            $filteredNodes = $rsopData.Where( { $_.Location -eq $site })
            foreach ($nodeRole in ($filteredNodes | Group-Object -Property { $_.Role }))
            {
                $roleTemplateName = Join-Path -Path $outputPath -ChildPath "$($environmentName)_$($site)_$($nodeRole.Name).json"
                $roleTemplate = @{
                    '$schema'      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
                    contentVersion = '1.0.0.0'
                    parameters     = @{
                        "artifactLocation"             = @{
                            "type"     = "string"
                            "metadata" = @{
                                "description" = "The location of resources, such as templates and DSC modules, that the template depends on"
                            }
                        }
                        "systemAdminUsername"          = @{
                            "type"     = "string"
                            "metadata" = @{
                                "description" = "The name of the administrator account of the new VM"
                            }
                        }
                        "systemAdminPassword"          = @{
                            "type"     = "securestring"
                            "metadata" = @{
                                "description" = "The password for the administrator account of the new VM and domain"
                            }
                        }
                        automationAccountName          = @{
                            type     = 'string'
                            metadata = @{
                                description = 'Automation Account Name'
                            }
                        }
                        automationAccountResourceGroup = @{
                            type     = 'string'
                            metadata = @{
                                description = 'Automation Account resource group'
                            }
                        }
                    }
                    resources      = @()
                }

                foreach ($node in $nodeRole.Group)
                {
                    # Network-Adapter
                    $count = 1
                    $adapters = @()
                    [object[]]$templateAdapter = $node.NetworkIpConfiguration.Interfaces
                    foreach ($adapter in $templateAdapter)
                    {
                        if ([string]::IsNullOrWhiteSpace($adapter.IpAddress))
                        {
                            continue
                        }

                        $net = Get-NetworkSummary -IPAddress $adapter.IpAddress -SubnetMask $adapter.Prefix
                        $superNet = Get-NetworkSummary -SubnetMask (ConvertTo-Mask -MaskLength ($net.MaskLength - 1)) -IPAddress $net.Network
                        $vnets[$superNet.Network] = @{
                            MaskLength = $superNet.MaskLength
                            VnetName   = '{0}-{1}-{2}-VNET' -f $environmentName, $site, $adapter.InterfaceAlias
                            Subnet     = '{0}/{1}' -f $net.Network, $net.MaskLength
                        }

                        [string[]]$dnsServers = if ((Test-Path env:\WeAreTesting) -or $adapter.DnsServer.Count -eq 0)
                        {
                            #'AzureProvidedDNS' 
                        }
                        elseif ($adapter.DnsServer.Count -gt 0 -and -not (Test-Path env:\WeAreTesting))
                        {
                            $adapter.DnsServer 
                        }
                        else
                        {
                            #'AzureProvidedDNS' 
                        }

                        $adapters += "[resourceId('Microsoft.Network/networkInterfaces', '{0}-nic{1}')]" -f $node.NodeName, $count
                        $roleTemplate.resources += @{
                            "comments"   = "DSC extension config for {0}" -f $node.NodeName
                            "type"       = "Microsoft.Compute/virtualMachines/extensions"
                            "name"       = "{0}/Microsoft.Powershell.DSC" -f $node.NodeName
                            "apiVersion" = "[providers('Microsoft.Compute','virtualMachines/extensions').apiVersions[0]]"
                            "location"   = "[resourceGroup().location]"
                            "dependsOn"  = @(
                                "[concat('Microsoft.Compute/virtualMachines/', '{0}')]" -f $node.NodeName
                            )
                            "properties" = @{
                                "publisher"               = "Microsoft.Powershell"
                                "type"                    = "DSC"
                                "typeHandlerVersion"      = "2.77"
                                "autoUpgradeMinorVersion" = $true
                                
                                "protectedSettings"       = @{
                                    "configurationArguments" = @{
                                        "RegistrationKey" = @{
                                            "userName" = "whatever"
                                            "password" = "[listKeys(resourceId(parameters('automationAccountResourceGroup'), 'Microsoft.Automation/automationAccounts/', parameters('automationAccountName')), '2015-01-01-preview').Keys[0].value]"
                                        }
                                    }
                                } 
                                "settings"                = @{
                                    "configurationArguments" = @{
                                        "RegistrationUrl"                = "[reference(resourceId(parameters('automationAccountResourceGroup'), 'Microsoft.Automation/automationAccounts/', parameters('automationAccountName')), '2015-01-01-preview').registrationUrl]"
                                        "NodeConfigurationName"          = "$($Node.Environment).$($Node.NodeName)"
                                        "ConfigurationMode"              = "ApplyAndAutoCorrect"
                                        "RebootNodeIfNeeded"             = $true
                                        "ActionAfterReboot"              = "ContinueConfiguration"
                                        "ConfigurationModeFrequencyMins" = "15"
                                        "RefreshFrequencyMins"           = "30"
                                    }
                                }
                            }
                        }

                        $roleTemplate.resources += @{
                            "type"       = "Microsoft.Network/networkInterfaces"
                            "apiVersion" = "[providers('Microsoft.Network','networkInterfaces').apiVersions[0]]"
                            "name"       = "{0}-nic{1}" -f $node.NodeName, $count
                            "location"   = "[resourceGroup().location]"
                            <#"dependsOn"  = @(
                                "[resourceId('Microsoft.Network/virtualNetworks/subnets', '{0}', 'sn')]" -f ('{0}-{1}-VNET' -f $node.Environment, $adapter.InterfaceAlias)
                            )#>
                            "properties" = @{
                                "ipConfigurations"            = @(
                                    @{
                                        "name"       = "ipconfig1"
                                        "properties" = @{
                                            "privateIPAddress"          = $adapter.IPAddress
                                            "privateIPAllocationMethod" = "Static"
                                            "subnet"                    = @{
                                                "id" = "[resourceId('Microsoft.Network/virtualNetworks/subnets', '{0}', 'sn')]" -f ('{0}-{1}-{2}-VNET' -f $environmentName, $site, $adapter.InterfaceAlias)
                                            }
                                            "primary"                   = $true
                                            "privateIPAddressVersion"   = "IPv4"
                                        }
                                    }
                                )
                                "dnsSettings"                 = @{
                                    "dnsServers" = $dnsServers
                                }
                                "enableAcceleratedNetworking" = $false
                                "enableIPForwarding"          = $false
                            }
                        }

                        $count ++
                    }

                    # Machines
                    $nicCount = 1
                    [object[]]$armNics = foreach ($nic in $adapters)
                    {
                        @{
                            "id"         = $nic
                            "properties" = @{
                                "primary" = $nicCount -eq 1
                            }
                        }
                        $nicCount ++
                    }

                    $roleTemplate.resources += @{
                        "type"       = "Microsoft.Compute/virtualMachines"
                        "apiVersion" = "[providers('Microsoft.Compute','virtualMachines').apiVersions[0]]"
                        "name"       = $node.NodeName
                        "location"   = "[resourceGroup().location]"
                        "dependsOn"  = $adapters
                        "properties" = @{
                            "hardwareProfile" = @{
                                "vmSize" = Lookup -Node $node -PropertyPath ArmSettings/VMSize
                            }
                            "storageProfile"  = @{
                                "imageReference" = @{
                                    sku       = Lookup -Node $Node -PropertyPath ArmSettings/OSImage/sku
                                    publisher = Lookup -Node $Node -PropertyPath ArmSettings/OSImage/publisher
                                    offer     = Lookup -Node $Node -PropertyPath ArmSettings/OSImage/offer
                                    version   = Lookup -Node $Node -PropertyPath ArmSettings/OSImage/version
                                }
                                "osDisk"         = @{
                                    "osType"       = "Windows"
                                    "createOption" = "FromImage"
                                    "caching"      = "ReadWrite"
                                }
                                "dataDisks"      = @()
                            }
                            "osProfile"       = @{
                                "computerName"             = $node.NodeName
                                "adminUsername"            = "[parameters('systemAdminUsername')]"
                                "adminPassword"            = "[parameters('systemAdminPassword')]"
                                "windowsConfiguration"     = @{
                                    "provisionVMAgent"       = $true
                                    "enableAutomaticUpdates" = $true
                                    "winRM"                  = @{
                                        "listeners" = @(
                                            @{
                                                "protocol" = "Http"
                                            }
                                        )
                                    }
                                }
                                "allowExtensionOperations" = $true
                            }
                            "networkProfile"  = @{
                                "networkInterfaces" = $armNics
                            }
                        }
                    }
                }

                $conditionParameterName = switch ($node.Role)
                {
                    'DomainController'
                    { 
                        'installDirectoryServices'
                    }
                    { $_ -in 'SqlServerScvmm', 'SqlServerSharepoint' }
                    {
                        'installSqlServices'
                    }
                    'SharePoint'
                    {
                        'installSharePointServices'
                    }
                    'WebServer'
                    {
                        'installSharePointServices'
                    }
                    'FileServer'                    
                    {
                        'installFileServices'
                    }
                    default
                    {
                        'NA'
                    }
                }

                if ($conditionParameterName -eq 'NA')
                {
                    continue 
                }
                
                $siteTemplate.resources += @{
                    "type"       = "Microsoft.Resources/deployments"
                    "name"       = "$($environmentName)$($site)$($node.Role)"
                    "apiVersion" = "[providers('Microsoft.Resources','deployments').apiVersions[0]]"
                    "condition"  = "[equals(parameters('$conditionParameterName'), 'True')]"
                    "dependsOn"  = @(
                        "Microsoft.Resources/deployments/$($environmentName)$($site)CoreInfrastructure"
                    )
                    "properties" = @{
                        "mode"         = "Incremental"
                        "templateLink" = @{
                            "uri"            = "[concat(variables('armArtifactLocation'), '$(Split-Path -Leaf $roleTemplateName)')]"
                            "contentVersion" = "1.0.0.0"
                        }
                        "parameters"   = @{ 
                            "artifactLocation"               = @{value = "[parameters('artifactLocation')]" }
                            "systemAdminUsername"            = @{value = "[parameters('systemAdminUsername')]" }
                            "systemAdminPassword"            = @{value = "[parameters('systemAdminPassword')]" }
                            "automationAccountName"          = @{value = "[parameters('automationAccountName')]" }
                            "automationAccountResourceGroup" = @{value = "[parameters('automationAccountResourceGroup')]" }
                        }
                    }
                }
                $roleTemplate | ConvertTo-JsonNewtonsoft | Set-Content -Path $roleTemplateName
            }

            # VNet
            foreach ($vnet in $vnets.GetEnumerator())
            {
                $nsg = $node.ArmSettings.NetworkSecurityGroups
                if ($nsg)
                {
                    [object[]]$rules = $nsg.Where( { $_.Name -eq "$($vnet.Value.VnetName)-nsg" }).SecurityRules
                }

                $nsgResource = @{
                    "type"       = "Microsoft.Network/networkSecurityGroups"
                    "apiVersion" = "[providers('Microsoft.Network','networkSecurityGroups').apiVersions[0]]"
                    "name"       = '{0}-nsg' -f $vnet.Value.VnetName
                    "location"   = "[resourceGroup().location]"
                    "properties" = @{ }
                }

                if ($rules.Count -gt 0)
                {
                    $nsgResource.properties.securityRules = $rules
                }

                $template.resources += $nsgResource

                $template.resources += @{
                    "type"       = "Microsoft.Network/virtualNetworks"
                    "apiVersion" = "[providers('Microsoft.Network','virtualNetworks').apiVersions[0]]"
                    "name"       = $vnet.Value.VnetName
                    "location"   = "[resourceGroup().location]"
                    "dependsOn"  = @(
                        "[resourceId('Microsoft.Network/networkSecurityGroups', '{0}-nsg')]" -f $vnet.Value.VnetName
                    )
                    "properties" = @{
                        "addressSpace" = @{
                            "addressPrefixes" = @(
                                '{0}/{1}' -f $vnet.Key, $vnet.Value.MaskLength
                            )
                        }
                        "subnets"      = @(
                            @{
                                "name"       = "sn"
                                "properties" = @{
                                    "addressPrefix"        = $vnet.Value.Subnet
                                    "networkSecurityGroup" = @{
                                        "id" = "[resourceId('Microsoft.Network/networkSecurityGroups', '{0}-nsg')]" -f $vnet.Value.VnetName
                                    }
                                }
                            }
                            #@{
                            #    "name"       = "GatewaySubnet"
                            #    "properties" = @{
                            #        "addressPrefix"                     = "10.0.1.0/24"
                            #    }
                            #}
                        )
                    }            
                }
            }

            # Export artifact
            $siteTemplate | ConvertTo-JsonNewtonsoft | Set-Content -Path $siteTemplateName
            $template | ConvertTo-JsonNewtonsoft | Set-Content -Path $templateName
        }

        $globalTemplate | ConvertTo-JsonNewtonsoft | Set-Content -Path $globalTemplateName
    }
}