task WaitForMutex {

    $tid = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    Start-Transcript -Path "$BuildOutput\Logs\WaitForMutex$tid-Log.txt"
    
    Write-Host "MofCompilationTaskCount: $MofCompilationTaskCount"
    
    if ($MofCompilationTaskCount -gt 1)
    {
        $m = [System.Threading.Mutex]::OpenExisting('DscBuildProcessMutex')
        Write-Host "Mutex handle $($m.Handle.ToInt32())"
        $r = $m.WaitOne(300000) #timeout is 5 minutes
        if (-not $r)
        {
            Write-Error "Error getting the mutex 'DscBuildProcessMutex' in 5 minutes"
        }
        Start-Sleep -Seconds 5
        Write-Host "Releasing mutex at $(Get-Date)"
        $m.ReleaseMutex()
    }
    else
    {
        Write-Host "Not waiting, starting compilation job"
    }
        
    Stop-Transcript
    
}