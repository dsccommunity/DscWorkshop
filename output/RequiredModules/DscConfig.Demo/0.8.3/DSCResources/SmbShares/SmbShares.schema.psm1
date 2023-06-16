configuration SmbShares
{
    param (
        [Parameter()]
        [ValidateSet('Server', 'Client')]
        $HostOS = 'Server',

        [Parameter()]
        [hashtable]
        $ServerConfiguration,

        [Parameter()]
        [hashtable[]]
        $Shares
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc

    if ($HostOS -eq 'Server')
    {
        WindowsFeature featureFileServer
        {
            Name   = 'FS-FileServer'
            Ensure = 'Present'
        }

        $featureFileServer = '[WindowsFeature]featureFileServer'
    }

    if ($null -ne $ServerConfiguration)
    {
        if ($HostOS -eq 'Server')
        {
            if ($ServerConfiguration.EnableSMB1Protocol -eq $false)
            {
                WindowsFeature removeSMB1
                {
                    Name      = 'FS-SMB1'
                    Ensure    = 'Absent'
                    DependsOn = $featureFileServer
                }
            }

            $ServerConfiguration.DependsOn = $featureFileServer
        }

        $ServerConfiguration.IsSingleInstance = 'Yes'

        (Get-DscSplattedResource -ResourceName SmbServerConfiguration -ExecutionName 'smbServerConfig' -Properties $ServerConfiguration -NoInvoke).Invoke($ServerConfiguration)
    }

    if ($null -ne $Shares)
    {
        foreach ($share in $Shares)
        {
            # Remove Case Sensitivity of ordered Dictionary or Hashtables
            $share = @{} + $share

            $shareId = $share.Name -replace '[:$\s]', '_'

            $share.DependsOn = $featureFileServer

            if (-not $share.ContainsKey('Ensure'))
            {
                $share.Ensure = 'Present'
            }

            if ($share.Ensure -eq 'Present')
            {
                if ([string]::IsNullOrWhiteSpace($share.Path))
                {
                    throw "ERROR: Missing path of the SMB share '$($share.Name)'."
                }

                # skip root paths
                $dirInfo = New-Object -TypeName System.IO.DirectoryInfo -ArgumentList $share.Path

                if ($null -ne $dirInfo.Parent)
                {
                    File "Folder_$shareId"
                    {
                        DestinationPath = $share.Path
                        Type            = 'Directory'
                        Ensure          = 'Present'
                        DependsOn       = $featureFileServer
                    }

                    $share.DependsOn = "[File]Folder_$shareId"
                }
            }
            elseif ([string]::IsNullOrWhiteSpace($share.Path))
            {
                $share.Path = 'Unused'
            }

            # remove duplicates from access rights
            $share.FullAccess = $() + $share.FullAccess
            $share.ChangeAccess = $() + ($share.ChangeAccess | Where-Object { $share.FullAccess -notcontains $_ })
            $share.ReadAccess = $() + ($share.ReadAccess | Where-Object { $share.FullAccess -notcontains $_ -and `
                        $share.ChangeAccess -notcontains $_ })
            $share.NoAccess = $() + ($share.NoAccess | Where-Object { $share.FullAccess -notcontains $_ -and `
                        $share.ChangeAccess -notcontains $_ -and `
                        $share.ReadAccess -notcontains $_ })

            (Get-DscSplattedResource -ResourceName SmbShare -ExecutionName "SmbShare_$shareId" -Properties $share -NoInvoke).Invoke($share)
        }
    }
}
