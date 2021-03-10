configuration DscAutoOnboarding
{
    Import-DscResource -ModuleName CertificateDsc
    Import-DscResource -ModuleName ComputerManagementDsc
    $hostname = [System.Environment]::MachineName

    Script AddToAdGroup {
        TestScript = {
            $dscNodesGroup = (New-Object System.Security.Principal.NTAccount('DscNodes')).Translate([System.Security.Principal.SecurityIdentifier]).Value

            $wi = Invoke-Command -ComputerName localhost -ScriptBlock {
                [System.Security.Principal.WindowsIdentity]::GetCurrent()
            }
            [bool]($wi.Groups | Where-Object { $_ -eq $dscNodesGroup })
        }

        GetScript  = {
            $wi = Invoke-Command -ComputerName localhost -ScriptBlock {
                [System.Security.Principal.WindowsIdentity]::GetCurrent()
            }
            @{
                Result = $wi
            }
        }

        SetScript  = {
            $s = New-PSSession -ComputerName DSCDO01 -ConfigurationName DSC
            $hostname = [System.Environment]::MachineName
            $hostname = "$($hostname)$"

            Invoke-Command -Session $s -ScriptBlock {
                Add-NodeToAdGroup -Identity $args[0]
            } -ArgumentList $hostname

            $global:DSCMachineStatus = 1 
        }
    }

    CertReq MofEncryptionCertRequest {
        CAServerFQDN        = 'DSCCASQL01.contoso.com'
        CARootName          = 'LabRootCA1'
        Subject             = "$hostname.contoso.com"
        KeyLength           = '4096'
        CertificateTemplate = 'DscMofFileEncryption'
        AutoRenew           = $true
        FriendlyName        = 'DSC MOF Encryption'
        DependsOn           = '[Script]AddToAdGroup'
    }

    Script DscJoinRequest {
        TestScript = {
            $Result = @{
                JoinRequestDate = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name JoinRequestDate -ErrorAction SilentlyContinue | Select-Object -ExpandProperty JoinRequestDate
                NodeYaml        = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name NodeYaml -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NodeYaml
                MetaMofContent  = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name MetaMofContent -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MetaMofContent
            }

            return [bool]$Result.JoinRequestDate
        }

        GetScript  = {
            
            @{
                Result = @{
                    JoinRequestDate = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name JoinRequestDate -ErrorAction SilentlyContinue | Select-Object -ExpandProperty JoinRequestDate
                    NodeYaml        = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name NodeYaml -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NodeYaml
                    MetaMofContent  = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name MetaMofContent -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MetaMofContent
                }
            }
        }

        SetScript  = {

            $s = New-PSSession -ComputerName DSCDO01 -ConfigurationName DSC
            $hostname = [System.Environment]::MachineName
            
            $ipAddress = Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress
            $certificate = dir -Path Cert:\LocalMachine\My | Where-Object { $_.FriendlyName -eq 'DSC MOF Encryption' } | Sort-Object -Property NotBefore -Descending | Select-Object -First 1
            $certificateBytes = $certificate.GetRawCertData()

            $environment = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name Environment | Select-Object -ExpandProperty Environment
            $location = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name Location | Select-Object -ExpandProperty Location
            $role = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name Role | Select-Object -ExpandProperty Role
            $description = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name Description | Select-Object -ExpandProperty Description

            $yaml = Invoke-Command -Session $s -ScriptBlock {
                Add-DscNode -NodeName $args[0] `
                    -Environment $args[1] `
                    -Role $args[2] `
                    -Location $args[3] `
                    -Description $args[4] `
                    -Ipaddress $args[5] `
                    -Certificate $args[6]
            } -ArgumentList $hostname, $environment, $role, $location, 'Some Description', $ipAddress, $certificateBytes -ErrorAction Stop

            Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name NodeYaml -Value $yaml -Type MultiString -Force
            Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name JoinRequestDate -Value (Get-Date) -Type String -Force

            $s | Remove-PSSession
        }
        DependsOn = '[CertReq]MofEncryptionCertRequest'
    }

    Script GetMetaMofContent {
        TestScript = {
            [datetime]$joinRequstDate = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name JoinRequestDate -ErrorAction SilentlyContinue | Select-Object -ExpandProperty JoinRequestDate
            $Result = @{
                JoinRequestDate = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name JoinRequestDate -ErrorAction SilentlyContinue | Select-Object -ExpandProperty JoinRequestDate
                NodeYaml        = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name NodeYaml -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NodeYaml
                MetaMofContent  = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name MetaMofContent -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MetaMofContent
                MetaMofCreationTime = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name MetaMofCreationTime -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MetaMofCreationTime
            }

            return [bool]$Result.MetaMofContent -and [datetime]$Result.MetaMofCreationTime -gt $joinRequstDate
        }

        GetScript  = {
            
            @{
                Result = @{
                    JoinRequestDate = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name JoinRequestDate -ErrorAction SilentlyContinue | Select-Object -ExpandProperty JoinRequestDate
                    NodeYaml        = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name NodeYaml -ErrorAction SilentlyContinue | Select-Object -ExpandProperty NodeYaml
                    MetaMofContent  = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name MetaMofContent -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MetaMofContent
                }
            }
        }

        SetScript  = {
            [datetime]$joinRequstDate = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name JoinRequestDate -ErrorAction SilentlyContinue | Select-Object -ExpandProperty JoinRequestDate
            
            $s = New-PSSession -ComputerName DSCDO01 -ConfigurationName DSC
            $hostname = [System.Environment]::MachineName
            
            $metaMof = Invoke-Command -Session $s -ScriptBlock {
                Get-DscMetaMofFile -NodeName $args[0] -After $args[1]
            } -ArgumentList $hostname, $joinRequstDate -ErrorAction Stop

            Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name MetaMofContent -Value $metaMof.Content -Type MultiString -Force
            Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name MetaMofCreationTime -Value $metaMof.CreationTime -Type String -Force

            $s | Remove-PSSession
        }
        DependsOn  = '[CertReq]MofEncryptionCertRequest'
    }

    Script WriteMetaMofContent {
        TestScript = {
            if (-not (Test-Path -Path C:\DscAutoOnboarding\localhost.meta.mof)) {
                return $false
            }

            [string]$metaFileContent = (Get-Content C:\DscAutoOnboarding\localhost.meta.mof) -like '@GenerationDate*'
            $metaRegistryContentTemp = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name MetaMofContent -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MetaMofContent
            [string]$metaRegistryContent = $metaRegistryContentTemp -like '@GenerationDate*'

            $metaFileContent -eq $metaRegistryContent
        }

        GetScript  = {
            
            [string]$metaFileContent = (Get-Content C:\DscAutoOnboarding\localhost.meta.mof) -like '@GenerationDate*'
            $metaRegistryContentTemp = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name MetaMofContent -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MetaMofContent
            [string]$metaRegistryContent = $metaRegistryContentTemp -like '@GenerationDate*'

            @{
                
                Result = @{
                    MetaFileContentGenerationDate = $metaFileContent
                    MetaRegistryContentGenerationDate = $metaRegistryContent
                }
            }
        }

        SetScript  = {

            $metaMofContent  = Get-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name MetaMofContent -ErrorAction SilentlyContinue | Select-Object -ExpandProperty MetaMofContent

            $temp = 'C:\DscAutoOnboarding'
            mkdir -Path $temp -Force | Out-Null
            $metaMofContent | Set-Content -Path "$temp\localhost.meta.mof" -Force

        }
        DependsOn = '[Script]GetMetaMofContent'
    }

    $date = Get-Date
    ScheduledTask ApplyMetaMof
    {
        TaskName = 'DscAutoOnboarding'
        ScheduleType = 'Once'
        ActionExecutable = 'C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe'
        ActionArguments = '-Command Set-DscLocalConfigurationManager -Path C:\DscAutoOnboarding -Force; $t = Get-ScheduledTask -TaskName DscAutoOnboarding; $t.Settings.Enabled = $false; $t | Set-ScheduledTask'
        RepeatInterval        = '00:01:00'
        RepetitionDuration = '07.00:00:00'        
        StartTime = $date
        DependsOn = '[Script]WriteMetaMofContent'
    }
}
