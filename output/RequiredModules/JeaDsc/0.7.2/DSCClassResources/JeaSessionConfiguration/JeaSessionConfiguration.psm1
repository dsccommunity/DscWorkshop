enum Ensure
{
    Present
    Absent
}

$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath Modules

Import-Module -Name (Join-Path -Path $modulePath -ChildPath DscResource.Common)
Import-Module -Name (Join-Path -Path $modulePath -ChildPath (Join-Path -Path JeaDsc.Common -ChildPath JeaDsc.Common.psm1))

$script:localizedData = Get-LocalizedData -DefaultUICulture en-US

[DscResource()]
class JeaSessionConfiguration
{
    ## The optional state that ensures the endpoint is present or absent. The defualt value is [Ensure]::Present.
    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    ## The mandatory endpoint name. Use 'Microsoft.PowerShell' by default.
    [DscProperty(Key)]
    [string] $Name = 'Microsoft.PowerShell'

    ## The role definition map to be used for the endpoint. This
    ## should be a string that represents the Hashtable used for the RoleDefinitions
    ## property in New-PSSessionConfigurationFile, such as:
    ## RoleDefinitions = '@{ Everyone = @{ RoleCapabilities = "BaseJeaCapabilities" } }'
    [Dscproperty()]
    [string] $RoleDefinitions

    ## run the endpoint under a Virtual Account
    [DscProperty()]
    [bool] $RunAsVirtualAccount

    ## The optional groups to be used when the endpoint is configured to
    ## run as a Virtual Account
    [DscProperty()]
    [string[]] $RunAsVirtualAccountGroups

    ## The optional Group Managed Service Account (GMSA) to use for this
    ## endpoint. If configured, will disable the default behaviour of
    ## running as a Virtual Account
    [DscProperty()]
    [string] $GroupManagedServiceAccount

    ## The optional directory for transcripts to be saved to
    [DscProperty()]
    [string] $TranscriptDirectory

    ## The optional startup script for the endpoint
    [DscProperty()]
    [string[]] $ScriptsToProcess

    ## The optional session type for the endpoint
    [DscProperty()]
    [string] $SessionType

    ## The optional switch to enable mounting of a restricted user drive
    [Dscproperty()]
    [bool] $MountUserDrive

    ## The optional size of the user drive. The default is 50MB.
    [Dscproperty()]
    [long] $UserDriveMaximumSize

    ## The optional expression declaring which domain groups (for example,
    ## two-factor authenticated users) connected users must be members of. This
    ## should be a string that represents the Hashtable used for the RequiredGroups
    ## property in New-PSSessionConfigurationFile, such as:
    ## RequiredGroups = '@{ And = "RequiredGroup1", @{ Or = "OptionalGroup1", "OptionalGroup2" } }'
    [Dscproperty()]
    [string[]] $RequiredGroups

    ## The optional modules to import when applied to a session
    ## This should be a string that represents a string, a Hashtable, or array of strings and/or Hashtables
    ## ModulesToImport = "'MyCustomModule', @{ ModuleName = 'MyCustomModule'; ModuleVersion = '1.0.0.0'; GUID = '4d30d5f0-cb16-4898-812d-f20a6c596bdf' }"
    [Dscproperty()]
    [string[]] $ModulesToImport

    ## The optional aliases to make visible when applied to a session
    [Dscproperty()]
    [string[]] $VisibleAliases

    ## The optional cmdlets to make visible when applied to a session
    ## This should be a string that represents a string, a Hashtable, or array of strings and/or Hashtables
    ## VisibleCmdlets = "'Invoke-Cmdlet1', @{ Name = 'Invoke-Cmdlet2'; Parameters = @{ Name = 'Parameter1'; ValidateSet = 'Item1', 'Item2' }, @{ Name = 'Parameter2'; ValidatePattern = 'L*' } }"
    [Dscproperty()]
    [string[]] $VisibleCmdlets

    ## The optional functions to make visible when applied to a session
    ## This should be a string that represents a string, a Hashtable, or array of strings and/or Hashtables
    ## VisibleFunctions = "'Invoke-Function1', @{ Name = 'Invoke-Function2'; Parameters = @{ Name = 'Parameter1'; ValidateSet = 'Item1', 'Item2' }, @{ Name = 'Parameter2'; ValidatePattern = 'L*' } }"
    [Dscproperty()]
    [string[]] $VisibleFunctions

    ## The optional external commands (scripts and applications) to make visible when applied to a session
    [Dscproperty()]
    [string[]] $VisibleExternalCommands

    ## The optional providers to make visible when applied to a session
    [Dscproperty()]
    [string[]] $VisibleProviders

    ## The optional aliases to be defined when applied to a session
    ## This should be a string that represents a Hashtable or array of Hashtable
    ## AliasDefinitions = "@{ Name = 'Alias1'; Value = 'Invoke-Alias1'}, @{ Name = 'Alias2'; Value = 'Invoke-Alias2'}"
    [Dscproperty()]
    [string[]] $AliasDefinitions

    ## The optional functions to define when applied to a session
    ## This should be a string that represents a Hashtable or array of Hashtable
    ## FunctionDefinitions = "@{ Name = 'MyFunction'; ScriptBlock = { param($MyInput) $MyInput } }"
    [Dscproperty()]
    [string[]] $FunctionDefinitions

    ## The optional variables to define when applied to a session
    ## This should be a string that represents a Hashtable or array of Hashtable
    ## VariableDefinitions = "@{ Name = 'Variable1'; Value = { 'Dynamic' + 'InitialValue' } }, @{ Name = 'Variable2'; Value = 'StaticInitialValue' }"
    [Dscproperty()]
    [string] $VariableDefinitions

    ## The optional environment variables to define when applied to a session
    ## This should be a string that represents a Hashtable
    ## EnvironmentVariables = "@{ Variable1 = 'Value1'; Variable2 = 'Value2' }"
    [Dscproperty()]
    [string] $EnvironmentVariables

    ## The optional type files (.ps1xml) to load when applied to a session
    [Dscproperty()]
    [string[]] $TypesToProcess

    ## The optional format files (.ps1xml) to load when applied to a session
    [Dscproperty()]
    [string[]] $FormatsToProcess

    ## The optional assemblies to load when applied to a session
    [Dscproperty()]
    [string[]] $AssembliesToLoad

    ## The optional number of seconds to wait for registering the endpoint to complete.
    ## 0 for no timeout
    [Dscproperty()]
    [int] $HungRegistrationTimeout = 10

    [void] Set()
    {
        $ErrorActionPreference = 'Stop'

        $this.TestParameters()

        $psscPath = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName() + '.pssc')
        Write-Verbose "Storing PSSessionConfigurationFile in file '$psscPath'"
        $desiredState = Convert-ObjectToHashtable -Object $this
        $desiredState.Add('Path', $psscPath)

        if ($this.Ensure -eq [Ensure]::Present)
        {
            foreach ($parameter in $desiredState.Keys.Where( { $desiredState[$_] -match '@{' }))
            {
                $desiredState[$parameter] = Convert-StringToObject -InputString $desiredState[$parameter]
            }
        }

        ## Register the endpoint
        try
        {
            ## If we are replacing Microsoft.PowerShell, create a 'break the glass' endpoint
            if ($this.Name -eq 'Microsoft.PowerShell')
            {
                $breakTheGlassName = 'Microsoft.PowerShell.Restricted'
                if (-not ($this.GetPSSessionConfiguration($breakTheGlassName)))
                {
                    $this.RegisterPSSessionConfiguration($breakTheGlassName, $null, $this.HungRegistrationTimeout)
                }
            }

            ## Remove the previous one, if any.
            if ($this.GetPSSessionConfiguration($this.Name))
            {
                $this.UnregisterPSSessionConfiguration($this.Name)
            }

            if ($this.Ensure -eq [Ensure]::Present)
            {
                ## Create the configuration file
                #New-PSSessionConfigurationFile @configurationFileArguments
                $desiredState = Sync-Parameter -Command (Get-Command -Name New-PSSessionConfigurationFile) -Parameters $desiredState
                New-PSSessionConfigurationFile @desiredState

                ## Register the configuration file
                $this.RegisterPSSessionConfiguration($this.Name, $psscPath, $this.HungRegistrationTimeout)
            }
        }
        catch
        {
            Write-Error -ErrorRecord $_
        }
        finally
        {
            if (Test-Path $psscPath)
            {
                Remove-Item $psscPath
            }
        }
    }

    # Tests if the resource is in the desired state.
    [bool] Test()
    {
        $this.TestParameters()

        $currentState = Convert-ObjectToHashtable -Object $this.Get()
        $desiredState = Convert-ObjectToHashtable -Object $this

        # short-circuit if the resource is not present and is not supposed to be present
        if ($currentState.Ensure -ne $desiredState.Ensure)
        {
            Write-Verbose "Desired state of session configuration named '$($currentState.Name)' is '$($desiredState.Ensure)', current state is '$($currentState.Ensure)' "
            return $false
        }
        if ($this.Ensure -eq [Ensure]::Absent)
        {
            if ($currentState.Ensure -eq [Ensure]::Absent)
            {
                return $true
            }

            Write-Verbose "Name present: $($currentState.Name)"
            return $false
        }

        $cmdlet = Get-Command -Name New-PSSessionConfigurationFile
        $desiredState = Sync-Parameter -Command $cmdlet -Parameters $desiredState
        $currentState = Sync-Parameter -Command $cmdlet -Parameters $currentState
        $propertiesAsObject = $cmdlet.Parameters.Keys |
        Where-Object { $_ -in $desiredState.Keys } |
        Where-Object { $cmdlet.Parameters.$_.ParameterType.FullName -in 'System.Collections.IDictionary', 'System.Collections.Hashtable', 'System.Collections.IDictionary[]', 'System.Object[]' }
        foreach ($p in $propertiesAsObject)
        {
            if ($cmdlet.Parameters.$p.ParameterType.FullName -in 'System.Collections.Hashtable', 'System.Collections.IDictionary', 'System.Collections.IDictionary[]', 'System.Object[]')
            {
                $desiredState."$($p)" = $desiredState."$($p)" | Convert-StringToObject
                $currentState."$($p)" = $currentState."$($p)" | Convert-StringToObject

            }
        }

        $compare = Test-DscParameterState -CurrentValues $currentState -DesiredValues $desiredState -TurnOffTypeChecking -SortArrayValues -ReverseCheck

        return $compare
    }

    hidden [bool] TestParameters()
    {
        if (-not $this.SessionType)
        {
            $this.SessionType = 'RestrictedRemoteServer'
        }

        if ($this.RunAsVirtualAccountGroups -and $this.GroupManagedServiceAccount)
        {
            throw $script:localizedData.ConflictRunAsVirtualAccountGroupsAndGroupManagedServiceAccount
        }

        if ($this.GroupManagedServiceAccount -and $this.RunAsVirtualAccount)
        {
            throw $script:localizedData.ConflictRunAsVirtualAccountAndGroupManagedServiceAccount
        }

        if (-not $this.GroupManagedServiceAccount)
        {
            $this.RunAsVirtualAccount = $true
            Write-Warning "'GroupManagedServiceAccount' and 'RunAsVirtualAccount' are not defined, setting 'RunAsVirtualAccount' to 'true'."
        }

        return $true
    }

    ## Get a PS Session Configuration based on its name
    hidden [object] GetPSSessionConfiguration($Name)
    {
        $winRMService = Get-Service -Name 'WinRM'
        if ($winRMService -and $winRMService.Status -eq 'Running')
        {
            # Temporary disabling Verbose as xxx-PSSessionConfiguration methods verbose messages are useless for DSC debugging
            $verbosePreferenceBackup = $Global:VerbosePreference
            $Global:VerbosePreference = 'SilentlyContinue'
            $psSessionConfiguration = Get-PSSessionConfiguration -Name $Name -ErrorAction SilentlyContinue
            $Global:VerbosePreference = $verbosePreferenceBackup

            if ($psSessionConfiguration)
            {
                return $psSessionConfiguration
            }
            else
            {
                return $null
            }
        }
        else
        {
            Write-Verbose 'WinRM service is not running. Cannot get PS Session Configuration(s).'
            return $null
        }
    }

    ## Unregister a PS Session Configuration based on its name
    hidden [void] UnregisterPSSessionConfiguration($Name)
    {
        $winRMService = Get-Service -Name 'WinRM'
        if ($winRMService -and $winRMService.Status -eq 'Running')
        {
            # Temporary disabling Verbose as xxx-PSSessionConfiguration methods verbose messages are useless for DSC debugging
            $verbosePreferenceBackup = $Global:VerbosePreference
            $Global:VerbosePreference = 'SilentlyContinue'
            $null = Unregister-PSSessionConfiguration -Name $Name -Force -WarningAction 'SilentlyContinue'
            $Global:VerbosePreference = $verbosePreferenceBackup
        }
        else
        {
            throw "WinRM service is not running. Cannot unregister PS Session Configuration '$Name'."
        }
    }

    ## Register a PS Session Configuration and handle a WinRM hanging situation
    hidden [Void] RegisterPSSessionConfiguration($Name, $Path, $Timeout)
    {
        $winRMService = Get-Service -Name 'WinRM'
        if ($winRMService -and $winRMService.Status -eq 'Running')
        {
            Write-Verbose "Will register PSSessionConfiguration with argument: Name = '$Name', Path = '$Path' and Timeout = '$Timeout'"
            # Register-PSSessionConfiguration has been hanging because the WinRM service is stuck in Stopping state
            # therefore we need to run Register-PSSessionConfiguration within a job to allow us to handle a hanging WinRM service

            # Save the list of services sharing the same process as WinRM in case we have to restart them
            $processId = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name LIKE 'WinRM'" | Select-Object -ExpandProperty ProcessId
            $serviceList = Get-CimInstance -ClassName 'Win32_Service' -Filter "ProcessId=$processId" | Select-Object -ExpandProperty Name
            foreach ($service in $serviceList.clone())
            {
                $dependentServiceList = Get-Service -Name $service | ForEach-Object { $_.DependentServices }
                foreach ($dependentService in $dependentServiceList)
                {
                    if ($dependentService.Status -eq 'Running' -and $serviceList -notcontains $dependentService.Name)
                    {
                        $serviceList += $dependentService.Name
                    }
                }
            }

            if ($Path)
            {
                $registerString = "`$null = Register-PSSessionConfiguration -Name '$Name' -Path '$Path' -NoServiceRestart -Force -ErrorAction 'Stop' -WarningAction 'SilentlyContinue'"
            }
            else
            {
                $registerString = "`$null = Register-PSSessionConfiguration -Name '$Name' -NoServiceRestart -Force -ErrorAction 'Stop' -WarningAction 'SilentlyContinue'"
            }

            $registerScriptBlock = [scriptblock]::Create($registerString)

            if ($Timeout -gt 0)
            {
                $job = Start-Job -ScriptBlock $registerScriptBlock
                Wait-Job -Job $job -Timeout $Timeout
                Receive-Job -Job $job
                Remove-Job -Job $job -Force -ErrorAction 'SilentlyContinue'

                # If WinRM is still Stopping after the job has completed / exceeded $Timeout, force kill the underlying WinRM process
                $winRMService = Get-Service -Name 'WinRM'
                if ($winRMService -and $winRMService.Status -eq 'StopPending')
                {
                    $processId = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name LIKE 'WinRM'" | Select-Object -ExpandProperty ProcessId
                    Write-Verbose "WinRM seems hanging in Stopping state. Forcing process $processId to stop"
                    $failureList = @()
                    try
                    {
                        # Kill the process hosting WinRM service
                        Stop-Process -Id $processId -Force
                        Start-Sleep -Seconds 5
                        Write-Verbose "Restarting services: $($serviceList -join ', ')"
                        # Then restart all services previously identified
                        foreach ($service in $serviceList)
                        {
                            try
                            {
                                Start-Service -Name $service
                            }
                            catch
                            {
                                $failureList += "Start service $service"
                            }
                        }
                    }
                    catch
                    {
                        $failureList += "Kill WinRM process"
                    }

                    if ($failureList)
                    {
                        Write-Verbose "Failed to execute following operation(s): $($failureList -join ', ')"
                    }
                }
                elseif ($winRMService -and $winRMService.Status -eq 'Stopped')
                {
                    Write-Verbose '(Re)starting WinRM service'
                    Start-Service -Name 'WinRM'
                }
            }
            else
            {
                Invoke-Command -ScriptBlock $registerScriptBlock
            }
        }
        else
        {
            throw "WinRM service is not running. Cannot register PS Session Configuration '$Name'"
        }
    }

    # Gets the resource's current state.
    [JeaSessionConfiguration] Get()
    {
        $currentState = New-Object JeaSessionConfiguration
        $CurrentState.Name = $this.Name
        $CurrentState.Ensure = [Ensure]::Present

        $sessionConfiguration = $this.GetPSSessionConfiguration($this.Name)
        if (-not $sessionConfiguration -or -not $sessionConfiguration.ConfigFilePath)
        {
            $currentState.Ensure = [Ensure]::Absent
            return $currentState
        }

        $configFile = Import-PowerShellDataFile $sessionConfiguration.ConfigFilePath

        'Copyright', 'GUID', 'Author', 'CompanyName', 'SchemaVersion' | Foreach-Object {
            $configFile.Remove($_)
        }

        foreach ($property in $configFile.Keys)
        {
            $propertyType = ($this | Get-Member -Name $property -MemberType Property).Definition.Split(' ')[0]
            $currentState.$property = foreach ($propertyValue in $configFile[$property])
            {
                if ($propertyValue -is [hashtable] -and $propertyType -ne 'hashtable')
                {
                    if ($propertyValue.ScriptBlock -is [scriptblock])
                    {
                        $code = $propertyValue.ScriptBlock.Ast.Extent.Text
                        $code -match '(?<=\{\{)(?<Code>((.|\s)*))(?=\}\})' | Out-Null
                        $propertyValue.ScriptBlock = [scriptblock]::Create($Matches.Code)
                    }

                    ConvertTo-Expression -Object $propertyValue
                }
                elseif ($propertyValue -is [hashtable] -and $propertyType -eq 'hashtable')
                {
                    $propertyValue
                }
                else
                {
                    $propertyValue
                }
            }
        }

        return $currentState
    }
}
