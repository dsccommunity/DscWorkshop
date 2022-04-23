#TODO: Test if a composite resource needs/imports a dsc resource that is currently not available/physically existent

BeforeDiscovery {
    $here = $PSScriptRoot
    $moduleFindPattern = 'Import-DscResource -ModuleName (?<ModuleName>\w+)( -ModuleVersion (?<ModuleVersion>(\d|\.)+))?'
    $rootPath = Split-Path -Path (Split-Path -Path $here -Parent) -Parent

    $dscCompositeResourceModules = $BuildInfo.'Sampler.DscPipeline'.DscCompositeResourceModules

    foreach ($dscCompositeResourceModule in $dscCompositeResourceModules.GetEnumerator())
    {
        $compositeResourceModuleName, $compositeResourceModuleVersion = if ($dscCompositeResourceModule -is [hashtable])
        {
            $dscCompositeResourceModule.Name
            $dscCompositeResourceModule.Version
        }
        else
        {
            $dscCompositeResourceModule
        }

        if ($compositeResourceModuleName -eq 'PSDesiredStateConfiguration')
        {
            continue
        }

        if ($compositeResourceModuleVersion)
        {
            $compositeResourceModulePath = Join-Path -Path $RequiredModulesDirectory -ChildPath "$compositeResourceModuleName\$compositeResourceModuleVersion\DscResources"
        }
        else
        {
            $compositeResourceModulePath = Join-Path -Path $RequiredModulesDirectory -ChildPath "$compositeResourceModuleName\*\DscResources"
        }

        $compositeResourceModulePath = (Resolve-Path -Path $compositeResourceModulePath).Path
        $compResources = (Get-ChildItem -Path $compositeResourceModulePath)
        $psDependPath = Join-Path -Path $rootPath -ChildPath RequiredModules.psd1
        $psDepend = Get-Item -Path $psDependPath

        $dscResources = Import-PowerShellDataFile -Path $psDepend.FullName
        $dscResources.Remove('PSDependOptions')

        [hashtable[]]$testCases = @()

        Write-Host "DSC Composite / Resource Module Table for '$compositeResourceModuleName' with version '$(if ($compositeResourceModuleVersion) { $compositeResourceModuleVersion } else { 'NA' })'" -ForegroundColor Green
        Write-Host '-------------------------------------' -ForegroundColor Green
        foreach ($compRes in $compResources)
        {
            $files = Get-ChildItem -Path $compRes.FullName -File -Recurse -Include '*.psm1'
            foreach ($file in $files)
            {
                $importHash = @{}
                $moduleMatches = Select-String -Path $file.FullName -Pattern $moduleFindPattern
                foreach ($moduleMatch in $moduleMatches)
                {
                    $moduleVersion = $moduleMatch.Matches[0].Groups['ModuleVersion'].Value
                    $importHash.Add($moduleMatch.Matches[0].Groups['ModuleName'].Value, $moduleVersion)
                }

                $importHash.Remove('PSDesiredStateConfiguration') #standard module available on every Windows machine.

                [PSCustomObject]$dscResourceModuleTable = @()
                if ($importHash -ne $null)
                {
                    $testCases += $importHash.GetEnumerator() | ForEach-Object {
                        @{
                            PSDependFileName           = $psDepend.Name
                            DscResourceFileName        = $file.Name
                            DscResourceName            = $_.Key
                            VersionInCompositeResource = $_.Value
                            VersionInPSDependFile      = $dscResources[$_.Key]
                        }
                    }
                }
            }
        }
        $testCases.GetEnumerator() | ForEach-Object { [pscustomobject]$_ } |
            Sort-Object -Property DscResourceName |
                Format-Table -Property DscResourceFileName, DscResourceName, VersionInCompositeResource, VersionInPSDependFile, PSDependFileName |
                    Out-String | Write-Host -ForegroundColor DarkGray
        Write-Host '-------------------------------------' -ForegroundColor Green
    }
}

Describe 'Resources matching between Composite Resources and PSDepend file' {

    Context 'Composite Resources import correct DSC Resources' -Tag Integration {
        It "DSC Resource Module '<DscResourceName>' is defined in '<PSDependFileName>'" -TestCases $testCases {
            $VersionInPSDependFile | Should -Not -BeNullOrEmpty
        }

        It "Version of '<DscResourceName>' in '<DscResourceFileName>' is equal to version in '<PSDependFileName>'" -TestCases $testCases {
            if ($VersionInCompositeResource)
            {
                $VersionInCompositeResource | Should -Be $VersionInPSDependFile
            }
        }
    }
}
