Write-Verbose -Message "Using build system $env:BuildSystem"

if ($env:BuildSystem -ne 'unknown')
{
    Deploy DeployMofs {
        By FileSystem {
            FromSource 'BuildOutput\MOF'
            To 'C:\Program Files\WindowsPowerShell\DscService\Configuration'
        }
    }
    Deploy DeployModules {
        By FileSystem {
            FromSource 'BuildOutput\DscModules'
            To 'C:\Program Files\WindowsPowerShell\DscService\Modules'
        }
    }
}
