configuration RootConfiguration
{
    #<importStatements>

    $rsopCache = Get-DatumRsopCache

    $module = Get-Module -Name PSDesiredStateConfiguration
    & $module {
        param(
            [string]$BuildVersion,
            [string]$Environment
        )
        $Script:PSTopConfigurationName = "MOF_$($Environment)_$($BuildVersion)"
    } $ModuleVersion, $environment

    node $ConfigurationData.AllNodes.NodeName {
        Write-Host -Object "`r`n$('-'*75)`r`n$($Node.Name) : $($Node.NodeName) : $(&$module { $Script:PSTopConfigurationName })" -ForegroundColor Yellow

        $configurationNames = $rsopCache."$($Node.Name)".Configurations
        $global:node = $node #this makes the node variable being propagated into the configurations

        foreach ($configurationName in $configurationNames)
        {
            Write-Debug -Message "`tLooking up params for $configurationName"
            $dscError = [System.Collections.ArrayList]::new()

            $clonedProperties = $rsopCache."$($Node.Name)".$configurationName

            (Get-DscSplattedResource -ResourceName $configurationName -ExecutionName $configurationName -Properties $clonedProperties -NoInvoke).Invoke($clonedProperties)

            if ($Error[0] -and $lastError -ne $Error[0])
            {
                $lastIndex = [Math]::Max(($Error.LastIndexOf($lastError) - 1), -1)
                if ($lastIndex -gt 0)
                {
                    $Error[0..$lastIndex].Foreach{
                        if ($message = Get-DscErrorMessage -Exception $_.Exception)
                        {
                            $null = $dscError.Add($message)
                        }
                    }
                }
                else
                {
                    if ($message = Get-DscErrorMessage -Exception $Error[0].Exception)
                    {
                        $null = $dscError.Add($message)
                    }
                }
                $lastError = $Error[0]
            }

            if ($dscError.Count -gt 0)
            {
                $warningMessage = "    $($Node.Name) : $($Node.Role) ::> $configurationName "
                $n = [System.Math]::Max(1, 100 - $warningMessage.Length)
                Write-Host -Object "$warningMessage$('.' * $n)FAILED" -ForegroundColor Yellow
                $dscError.Foreach{
                    Write-Host -Object "`t$message" -ForegroundColor Yellow
                }
            }
            else
            {
                $okMessage = "    $($Node.Name) : $($Node.Role) ::> $configurationName "
                $n = [System.Math]::Max(1, 100 - $okMessage.Length)
                Write-Host -Object "$okMessage$('.' * $n)OK" -ForegroundColor Green
            }
        }
    }
}
