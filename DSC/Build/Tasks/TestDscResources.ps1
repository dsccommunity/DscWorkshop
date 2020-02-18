task TestDscResources {
    $tid = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    Start-Transcript -Path "$BuildOutput\Logs\TestDscResources$tid-Log.txt"

    Write-Host ------------------------------------------------------------
    Write-Host 'Currently loaded modules:'
    $env:PSModulePath -split ';' | Write-Host
    Write-Host ------------------------------------------------------------
    Write-Host "The 'CommonTasks' module provides the following configurations (DSC Composite Resources)"
    $m = Get-Module -Name CommonTasks -ListAvailable
    $resourceCount = (dir -Path "$($m.ModuleBase)\DscResources").Count
    Write-Host "ResourceCount $resourceCount"

    $maxIterations = 5
    while ($resourceCount -ne (Get-DscResource -Module CommonTasks).Count -and $maxIterations -gt 0) {
        Start-Sleep -Seconds 5
        $maxIterations--
        Write-Host "ResourceCount DOES NOT match, currently '$((Get-DscResource -Module CommonTasks).Count)'"
    }
    if ($maxIterations -eq 0)
    {
        throw 'Could not get the expected DSC Resource count'
    }

    Write-Host "ResourceCount matches ($resourceCount)"
    Write-Host ------------------------------------------------------------
    Write-Host 'Known DSC Composite Resources'
    Write-Host ------------------------------------------------------------
    Get-DscResource -Module CommonTasks | Out-String | Write-Host

    Write-Host ------------------------------------------------------------
    Write-Host 'Knwon DSC Resources'
    Write-Host ------------------------------------------------------------
    Write-Host
    Import-LocalizedData -BindingVariable requiredResources -FileName PSDepend.DscResources.psd1 -BaseDirectory $ProjectPath
    $requiredResources = $requiredResources.GetEnumerator() | Where-Object { $_.Name -ne 'PSDependOptions' }
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

    Stop-Transcript

}
