task CompileRootConfiguration {

    $tid = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    Start-Transcript -Path "$BuildOutput\Logs\Compile_Root_Configuration$tid-Log.txt"
    Import-Module xPSDesiredStateConfiguration

    try
    {
        $mofs = . (Join-Path -Path $ProjectPath -ChildPath 'RootConfiguration.ps1')
        Write-Build Green "Successfully compiled $($mofs.Count) MOF files"
    }
    catch
    {
        Write-Build Red "ERROR OCCURED DURING COMPILATION: $($_.Exception.Message)"
        $relevantErrors = $Error | Where-Object {
            $_.Exception -isnot [System.Management.Automation.ItemNotFoundException]
        }
        Write-Build Red ($relevantErrors[0..2] | Out-String)
    }

    Stop-Transcript

}