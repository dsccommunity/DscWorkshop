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

    [string[]]$dcDependencies = foreach ($domainController in $rsopData.Where( { $_.Role -eq 'DomainController' }))
    {
        "[resourceId('Microsoft.Compute/virtualMachines/extensions', '$($domainController.NodeName)', 'Microsoft.Powershell.DSC')]"
    }

    Write-Build Green "Generating ARM templates for $($environments.Count) environments $($rsopData.Count) nodes"
    foreach ($environmentName in $environments)
    {
        $globalTemplateName = Join-Path -Path $outputPath -ChildPath "$($environmentName).json"
        $globalTemplate = @{
            '$schema'      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
            contentVersion = '1.0.0.0'
            parameters     = @{
                "systemAdminUsername"        = @{
                    "defaultValue" = 'admInst'
                    "type"         = "string"
                    "metadata"     = @{
                        "description" = "The name of the administrator account of the new VM"
                    }
                }
                "systemAdminPassword"        = @{
                    "type"     = "securestring"
                    "metadata" = @{
                        "description" = "The password for the administrator account of the new VM and domain"
                    }
                }
                "installDirectoryServices"   = @{
                    "type"         = "string"
                    "defaultValue" = "true"
                    allowedValues  = "true", "false"
                    "metadata"     = @{
                        "description" = "A flag to control the installation of Directory services"
                    }
                }
                installWebServices           = @{
                    "type"         = "string"
                    "defaultValue" = "false"
                    allowedValues  = "true", "false"
                    "metadata"     = @{
                        "description" = "Flag controlling that application services are deployed"
                    }
                }
                "installFileServices"        = @{
                    "type"         = "string"
                    "defaultValue" = "false"
                    allowedValues  = "true", "false"
                    "metadata"     = @{
                        "description" = "A flag to control the installation of file services"
                    }
                }
                "installExchangeServices"    = @{
                    "type"         = "string"
                    "defaultValue" = "false"
                    allowedValues  = "true", "false"
                    "metadata"     = @{
                        "description" = "A flag to control the installation of Exchange mail services"
                    }
                }
                "installSQLServices"         = @{
                    "type"         = "string"
                    "defaultValue" = "false"
                    allowedValues  = "true", "false"
                    "metadata"     = @{
                        "description" = "A flag to control the installation of SQL services"
                    }
                }
                "installSharePointServices"  = @{
                    "type"         = "string"
                    "defaultValue" = "false"
                    allowedValues  = "true", "false"
                    "metadata"     = @{
                        "description" = "A flag to control the installation of SharePoint services"
                    }
                }
                "installCertificateServices" = @{
                    "type"         = "string"
                    "defaultValue" = "false"
                    allowedValues  = "true", "false"
                    "metadata"     = @{
                        "description" = "A flag to control the installation of Active Directory Certificate Services"
                    }
                }
                "pullServerRegistrationKey"  = @{
                    "defaultValue" = $configurationData.Datum.Roles.DscBaseline.LcmConfig.ConfigurationRepositoryWeb.Server.RegistrationKey
                    "type"         = "string"
                    "metadata"     = @{
                        "description" = "Key to register node with pull server"
                    }
                }
                "pullServerRegistrationUrl"  = @{
                    "defaultValue" = $configurationData.Datum.Roles.DscBaseline.LcmConfig.ConfigurationRepositoryWeb.Server.ServerURL
                    "type"         = "string"
                    "metadata"     = @{
                        "description" = "Key to register node with pull server"
                    }
                }
            }
            variables      = @{ }
            resources      = @()
        }

        foreach ($site in $locations)
        {
            # Hashtables to collect globally reused data like supernets
            $vnets = @{ }

            $filteredNodes = $rsopData.Where( { $_.Environment -eq $environmentName -and $_.Location -eq $site })
            foreach ($nodeRole in ($filteredNodes | Group-Object -Property { $_.Role }))
            {
                foreach ($node in $nodeRole.Group)
                {
                    $conditionParameterName = switch ($node.Role)
                    {
                        'DomainController'
                        { 
                            'installDirectoryServices'
                        }
                        'SharePoint'
                        {
                            'installSharePointServices'
                        }
                        'WebServer'
                        {
                            'installWebServices'
                        }
                        'FileServer'                    
                        {
                            'installFileServices'
                        }
                        default
                        {
                            $null
                        }
                    }
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
                            VnetName   = '{0}-{1}-{2}-VNET' -f $environmentName, $site, $superNet.Network.Replace('.', '')
                            Subnet     = '{0}/{1}' -f $net.Network, $net.MaskLength
                        }

                        [string[]]$dnsServers = if ($adapter.DnsServer.Count -eq 0)
                        {
                            'AzureProvidedDNS'
                        }
                        elseif ($adapter.DnsServer.Count -gt 0)
                        {
                            [string[]]$dns = '168.63.129.16' # At least for the lab scenario, prepend public Azure DNS
                            foreach ($ad in $adapter.DnsServer) { $dns += $ad }
                            $dns
                        }
                        else
                        {
                            'AzureProvidedDNS'
                        }

                        $adapters += "[resourceId('Microsoft.Network/networkInterfaces', '{0}-nic{1}')]" -f $node.NodeName, $count

                        $hasPublicIp = Resolve-NodeProperty -Node $node -PropertyPath ArmSettings/AssignPublicIpAddress -DefaultValue $null
                        if ($count -eq 1 -and $hasPublicIp)
                        {
                            $globalTemplate.resources += @{
                                apiVersion = "[providers('Microsoft.Network','publicIPAddresses').apiVersions[0]]"
                                type       = "Microsoft.Network/publicIPAddresses"
                                name       = "{0}-nic{1}-pip" -f $Node.NodeName, $count
                                location   = "[resourceGroup().location]"
                                properties = @{
                                    publicIPAllocationMethod = "Static"
                                }
                                sku        = @{
                                    name = 'Standard'
                                }
                            }
                        }

                        $nic = @{
                            "type"       = "Microsoft.Network/networkInterfaces"
                            "apiVersion" = "[providers('Microsoft.Network','networkInterfaces').apiVersions[0]]"
                            "name"       = "{0}-nic{1}" -f $node.NodeName, $count
                            "location"   = "[resourceGroup().location]"
                            "dependsOn"  = @(
                                "[resourceId('Microsoft.Network/virtualNetworks','{0}')]" -f $vnets[$superNet.Network]['VnetName']
                                if ($hasPublicIp) { "[resourceId('Microsoft.Network/publicIPAddresses', '{0}-nic{1}-pip')]" -f $Node.NodeName, $count }
                            )
                            "properties" = @{
                                "ipConfigurations"            = @(
                                    @{
                                        "name"       = "ipconfig1"
                                        "properties" = @{
                                            "privateIPAddress"          = $adapter.IPAddress
                                            "privateIPAllocationMethod" = "Static"
                                            "subnet"                    = @{
                                                "id" = "[resourceId('Microsoft.Network/virtualNetworks/subnets','{0}', 'sn')]" -f $vnets[$superNet.Network]['VnetName']
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

                        if ($conditionParameterName)
                        {
                            $nic["condition"] = "[equals(parameters('$conditionParameterName'),'true')]"
                        }
                        if ($hasPublicIp)
                        {                            
                            $nic.properties.ipconfigurations[0].properties["publicIPAddress"] = @{
                                "id" = "[resourceId('Microsoft.Network/publicIPAddresses', '{0}-nic{1}-pip')]" -f $Node.NodeName, $count
                            }
                        }
                        $globalTemplate.resources += $nic

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

                    $disks = @()
                    if (Resolve-NodeProperty -Node $Node -PropertyPath Disks -DefaultValue $null)
                    {
                        $diskObjects = Resolve-NodeProperty -Node $Node -PropertyPath Disks
                        $i = 1
                        $disks = foreach ($do in $diskObjects.Disks)
                        {
                            if ($do.DiskId -eq 0 -or $do.FileSystemLabel -eq 'System') { continue }
                            if (-not ($do.Size)) { continue }
                            @{
                                caching      = "ReadWrite"
                                diskSizeGB   = [int] ((Invoke-Expression $do.Size) / 1GB) + 5
                                lun          = $i;
                                name         = "$($node.NodeName)-data-disk-$i"
                                createOption = "Empty"
                            }
                            $i++
                        }
                    }

                    $vmTemplate = @{
                        "type"       = "Microsoft.Compute/virtualMachines"
                        "apiVersion" = "[providers('Microsoft.Compute','virtualMachines').apiVersions[0]]"
                        "name"       = $node.NodeName
                        "location"   = "[resourceGroup().location]"
                        "dependsOn"  = $adapters
                        "properties" = @{
                            "hardwareProfile" = @{
                                "vmSize" = Resolve-NodeProperty -Node $node -PropertyPath ArmSettings\VMSize
                            }
                            "storageProfile"  = @{
                                "imageReference" = @{
                                    sku       = Resolve-NodeProperty -Node $Node -PropertyPath ArmSettings\OSImage\sku
                                    publisher = Resolve-NodeProperty -Node $Node -PropertyPath ArmSettings\OSImage\publisher
                                    offer     = Resolve-NodeProperty -Node $Node -PropertyPath ArmSettings\OSImage\offer
                                    version   = Resolve-NodeProperty -Node $Node -PropertyPath ArmSettings\OSImage\version
                                }
                                "osDisk"         = @{
                                    "osType"       = "Windows"
                                    "createOption" = "FromImage"
                                    "caching"      = "ReadWrite"
                                }
                                "dataDisks"      = [object[]] $disks
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

                    if ($conditionParameterName)
                    {
                        $vmTemplate["condition"] = "[equals(parameters('$conditionParameterName'),'true')]"
                    }
                    $globalTemplate.resources += $vmTemplate
                    $lcmSettings = Resolve-NodeProperty -Node $Node -PropertyPath LcmConfig/Settings
                    $dscTemplate = @{
                        "comments"   = "DSC extension config for {0}" -f $node.NodeName
                        "type"       = "Microsoft.Compute/virtualMachines/extensions"
                        "name"       = "{0}/Microsoft.Powershell.DSC" -f $node.NodeName
                        "apiVersion" = "[providers('Microsoft.Compute','virtualMachines/extensions').apiVersions[0]]"
                        "location"   = "[resourceGroup().location]"
                        "dependsOn"  = @(
                            "[resourceId('Microsoft.Compute/virtualMachines', '{0}')]" -f $node.NodeName
                        )
                        "properties" = @{
                            "publisher"               = "Microsoft.Powershell"
                            "type"                    = "DSC"
                            "typeHandlerVersion"      = "2.77"
                            "autoUpgradeMinorVersion" = $true
                            
                            "protectedSettings"       = @{
                                "Items" = @{
                                    "registrationKeyPrivate" = "[parameters('pullServerRegistrationKey')]"
                                }
                            } 
                            "settings"                = @{
                                properties = @(
                                    @{
                                        Name       = 'RegistrationKey'
                                        Value      = @{
                                            UserName = 'PLACEHOLDER_DONOTUSE'
                                            Password = 'PrivateSettingsRef:registrationKeyPrivate'
                                        }
                                        
                                        "TypeName" = "System.Management.Automation.PSCredential"
                                    }
                                    
                                    @{
                                        "Name"     = "RegistrationUrl"
                                        "Value"    = "[parameters('pullServerRegistrationUrl')]"
                                        "TypeName" = "System.String"
                                    }
                                    @{
                                        "Name"     = "NodeConfigurationName"
                                        "Value"    = "$($Node.Environment).$($Node.NodeName)"
                                        "TypeName" = "System.String"
                                    }
                                    @{
                                        "Name"     = "RebootNodeIfNeeded"
                                        "Value"    = if ($lcmSettings.RebootNodeIfNeeded) { $lcmSettings.RebootNodeIfNeeded } else { $true }
                                        "TypeName" = "System.Boolean"
                                    }
                                    @{
                                        "Name"     = "RefreshFrequencyMins" # Azure DSC is always Pull
                                        "Value"    = if ($lcmSettings.RefreshFrequencyMins) { $lcmSettings.RefreshFrequencyMins } else { 30 }
                                        "TypeName" = "System.Int32"
                                    }
                                    @{
                                        "Name"     = "ActionAfterReboot"
                                        "Value"    = if ($lcmSettings.ActionAfterReboot) { $lcmSettings.ActionAfterReboot } else { 'ContinueConfiguration' }
                                        "TypeName" = "System.String"
                                    }
                                    @{
                                        "Name"     = "AllowModuleOverwrite"
                                        "Value"    = if ($lcmSettings.AllowModuleOverwrite) { $lcmSettings.AllowModuleOverwrite } else { $true }
                                        "TypeName" = "System.Boolean"
                                    }
                                    @{
                                        "Name"     = "ConfigurationMode"
                                        "Value"    = if ($lcmSettings.ConfigurationMode) { $lcmSettings.ConfigurationMode } else { 'ApplyAndMonitor' }
                                        "TypeName" = "System.String"
                                    }
                                    @{
                                        "Name"     = "ConfigurationModeFrequencyMins"
                                        "Value"    = if ($lcmSettings.ConfigurationModeFrequencyMins) { $lcmSettings.ConfigurationModeFrequencyMins } else { 15 }
                                        "TypeName" = "System.Boolean"
                                    }
                                )
                            }
                        }
                    }

                    <#
ActionAfterReboot: ContinueConfiguration
AllowModuleOverwrite: true
#CertificateID: ...
ConfigurationMode: ApplyAndMonitor
ConfigurationModeFrequencyMins: 30
                    #>

                    if ($dcDependencies)
                    {
                        $dscTemplate.dependsOn += $dcDependencies
                    }

                    if ($conditionParameterName)
                    {
                        $dscTemplate["condition"] = "[equals(parameters('$conditionParameterName'),'true')]"
                    }
                    $globalTemplate.resources += $dscTemplate
                }
            }

            foreach ($vnet in $vnets.GetEnumerator())
            {
                $nsg = Resolve-NodeProperty -PropertyPath ArmSettings\NetworkSecurityGroups -DefaultValue $null
                if ($nsg)
                {
                    [object[]]$rules = $nsg.Where( { ([pscustomobject]$_).Name -eq "$($vnet.Value.VnetName)-nsg" }).SecurityRules
                    
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

                    $globalTemplate.resources += $nsgResource
                }

                $globalTemplate.resources += @{
                    "type"       = "Microsoft.Network/virtualNetworks"
                    "apiVersion" = "[providers('Microsoft.Network','virtualNetworks').apiVersions[0]]"
                    "name"       = $vnet.Value.VnetName
                    "location"   = "[resourceGroup().location]"
                    "dependsOn"  = @(
                        if ($nsg) { "[resourceId('Microsoft.Network/networkSecurityGroups','{0}-nsg')]" -f $vnet.Value.VnetName }
                    )
                    "properties" = @{
                        "addressSpace" = @{
                            "addressPrefixes" = @(
                                '{0}/{1}' -f $vnet.Key, $vnet.Value.MaskLength
                            )
                        }
                        "subnets"      = @(
                            @{
                                "type"       = "Microsoft.Network/virtualNetworks/subnets"
                                "name"       = 'sn'
                                "properties" = @{
                                    "addressPrefix"        = $vnet.Value.Subnet
                                    "networkSecurityGroup" = @{
                                        "id" = "[resourceId('Microsoft.Network/networkSecurityGroups','{0}-nsg')]" -f $vnet.Value.VnetName
                                    }
                                }
                            }
                        )
                    }            
                }
            }
        }

        $peerings = Get-FullMesh -List $vnets.Values.VnetName
        [string[]] $dependencies = $vnets.Values.VnetName.ForEach( { "[resourceId('Microsoft.Network/virtualNetworks', '{0}')]" -f $_ })

        # Peerings
        foreach ($peer in $peerings)
        {
            $peerTemplate = @{
                "apiVersion" = "[providers('Microsoft.Network','virtualNetworks').apiVersions[0]]"
                "type"       = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings"
                "name"       = "[concat('{0}', '/{0}-to-{1}')]" -f $peer.Source, $peer.Destination
                "location"   = "[resourceGroup().location]"
                dependsOn    = $dependencies
                "properties" = @{
                    "allowVirtualNetworkAccess" = $true
                    "allowForwardedTraffic"     = $false
                    "allowGatewayTransit"       = $false
                    "useRemoteGateways"         = $false
                    "remoteVirtualNetwork"      = @{
                        "id" = "[resourceId('Microsoft.Network/virtualNetworks', '{0}')]" -f $peer.Destination
                    }
                }
            }

            $globalTemplate.resources += $peerTemplate
        }
        $globalTemplate | ConvertTo-JsonNewtonsoft | Set-Content -Path $globalTemplateName
    }
}