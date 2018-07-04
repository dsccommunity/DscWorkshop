if ($Env:BuildSystems -eq 'AppVeyor' -and $Env:BranchName -in @('DEV', 'PROD'))
{
    Write-Warning "This where I'd deploy from AppVeyor"
}
elseif ($Env:USERDOMAIN -eq 'CONTOSO' -and $Env:BranchName -in @('DEV', 'PROD'))
{
    # How you can move MOFs and Zipped modules for DSC PULL to a file share
    Deploy DeployMofs {
        By FileSystem {
            FromSource 'BuildOutput\MOF'
            To '\\contoso\dfs\DSC\MOF'
        }
    }
    Deploy DeployMofs {
        By FileSystem {
            FromSource 'BuildOutput\DscModules'
            To '\\contoso\dfs\DSC\DscModules'
        }
    }
}
