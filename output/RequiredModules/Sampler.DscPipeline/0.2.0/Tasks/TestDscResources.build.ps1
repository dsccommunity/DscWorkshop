task TestDscResources {
    Write-Build Yellow "Not implemented yet. We don't separate Composites from Resources or build dependencies anymore."
    return
    try
    {
        Start-Transcript -Path "$BuildOutput\Logs\TestDscResources.log"

        foreach ($configModule in (Get-Dependency -Path $ProjectPath/RequiredModules.psd1).DependencyName)
        {
            Write-Build DarkGray '------------------------------------------------------------'
            Write-Build DarkGray 'Currently loaded modules:'
            $env:PSModulePath -split ';' | Write-Build DarkGray
            Write-Build DarkGray '------------------------------------------------------------'
            Write-Build DarkGray "The '$configModule' module provides the following configurations (DSC Composite Resources)"
            $m = Get-Module -Name $configModule -ListAvailable
            if (-not $m)
            {
                Write-Error "The module '$configModule' containing the configurations could not be found. Please check the file 'PSDepend.DscConfigurations.psd1' and verify if the module is available in the given repository" -ErrorAction Stop
            }

            $resources = Get-ChildItem -Path "$($m.ModuleBase)\DscResources"
            $resourceCount = $resources.Count
            Write-Build DarkGray "ResourceCount $resourceCount"

            $maxIterations = 5
            while ($resourceCount -ne (Get-DscResource -Module $configModule).Count -and $maxIterations -gt 0)
            {
                $dscResources = Get-DscResource -Module $configModule
                Write-Build DarkGray "ResourceCount DOES NOT match, currently '$($dscResources.Count)'. Resources missing:"
                Write-Build DarkGray (Compare-Object -ReferenceObject $resources.Name -DifferenceObject $dscResources.Name).InputObject
                Start-Sleep -Seconds 5
                $maxIterations--
            }
            if ($maxIterations -eq 0)
            {
                throw 'Could not get the expected DSC Resource count'
            }

            Write-Build White "ResourceCount matches ($resourceCount)"
            Write-Build DarkGray ------------------------------------------------------------
            Write-Build White 'Known DSC Composite Resources'
            Write-Build DarkGray ------------------------------------------------------------
            Get-DscResource -Module $configModule | Out-String | Write-Build DarkGray

            Write-Build DarkGray ------------------------------------------------------------
            Write-Build DarkGray 'Known DSC Resources'
            Write-Build DarkGray ------------------------------------------------------------
            Write-Build DarkGray
            Import-LocalizedData -BindingVariable requiredResources -FileName PSDepend.DscResources.psd1 -BaseDirectory $ProjectPath
            $requiredResources = @($requiredResources.GetEnumerator() | Where-Object { $_.Name -ne 'PSDependOptions' })
            $requiredResources.GetEnumerator() | ForEach-Object {
                $rr = $_
                try
                {
                    Get-DscResource -Module $rr.Name -WarningAction Stop
                }
                catch
                {
                    Write-Error "DSC Resource '$($rr.Name)' cannot be found" -ErrorAction Stop
                }
            } | Group-Object -Property ModuleName, Version |
                Select-Object -Property Name, Count | Write-Build DarkGray
            Write-Build DarkGray ------------------------------------------------------------
        }
    }
    catch
    {
        Write-Error -ErrorRecord $_
    }
    finally
    {
        Stop-Transcript
    }
}
