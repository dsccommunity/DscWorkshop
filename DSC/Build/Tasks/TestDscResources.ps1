task TestDscResources {

    try {
        Start-Transcript -Path "$BuildOutput\Logs\TestDscResources.log"

        foreach ($configModule in (Get-Dependency -Path $ProjectPath/PSDepend.DscConfigurations.psd1).DependencyName) {
            Write-Host ------------------------------------------------------------
            Write-Host 'Currently loaded modules:'
            $env:PSModulePath -split ';' | Write-Host
            Write-Host ------------------------------------------------------------
            Write-Host "The '$configModule' module provides the following configurations (DSC Composite Resources)"
            $m = Get-Module -Name $configModule -ListAvailable
            if (-not $m) {
                Write-Error "The module '$configModule' containing the configurations could not be found. Please check the file 'PSDepend.DscConfigurations.psd1' and verify if the module is available in the given repository" -ErrorAction Stop
            }
            $resources = dir -Path "$($m.ModuleBase)\DscResources"
            $resourceCount = $resources.Count
            Write-Host "ResourceCount $resourceCount"

            $maxIterations = 5
            while ($resourceCount -ne (Get-DscResource -Module $configModule).Count -and $maxIterations -gt 0) {
                $dscResources = Get-DscResource -Module $configModule
                Write-Host "ResourceCount DOES NOT match, currently '$($dscResources.Count)'. Resources missing:"
                Write-Host (Compare-Object -ReferenceObject $resources.Name -DifferenceObject $dscResources.Name).InputObject
                Start-Sleep -Seconds 5
                $maxIterations--
            }
            if ($maxIterations -eq 0) {
                throw 'Could not get the expected DSC Resource count'
            }

            Write-Host "ResourceCount matches ($resourceCount)"
            Write-Host ------------------------------------------------------------
            Write-Host 'Known DSC Composite Resources'
            Write-Host ------------------------------------------------------------
            Get-DscResource -Module $configModule | Out-String | Write-Host

            Write-Host ------------------------------------------------------------
            Write-Host 'Known DSC Resources'
            Write-Host ------------------------------------------------------------
            Write-Host
            Import-LocalizedData -BindingVariable requiredResources -FileName PSDepend.DscResources.psd1 -BaseDirectory $ProjectPath
            $requiredResources = @($requiredResources.GetEnumerator() | Where-Object { $_.Name -ne 'PSDependOptions' })
            $requiredResources.GetEnumerator() | Foreach-Object {
                $rr = $_
                try {
                    Get-DscResource -Module $rr.Name -WarningAction Stop
                }
                catch {
                    Write-Error "DSC Resource '$($rr.Name)' cannot be found" -ErrorAction Stop
                }
            } | Group-Object -Property ModuleName, Version |
            Select-Object -Property Name, Count | Write-Host
            Write-Host ------------------------------------------------------------
        }
    }
    catch {
        Write-Error -ErrorRecord $_
    }
    finally {
        Stop-Transcript
    }
}
