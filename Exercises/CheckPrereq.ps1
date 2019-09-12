#requires -Module @{ModuleName = "Pester"; ModuleVersion="4.0"}

describe "Prerequisite check" {

    Context "Task 1" {
        it "Should have git installed and in path" {
            Get-Command git -ea SilentlyContinue | Should -Not -Be $null -Because "We require git for many lab exercises"
        }

        it "Should not be executed on PowerShell Core" {
            $PSVersionTable.PSVersion -lt '6.0' | Should -Be $true -Because "Currently the build process is not capable of running with PowerShell Core"
        }

        it "Should be using VS Code" {
            Get-Command code.cmd -ErrorAction SilentlyContinue | Should -Not -Be $null
        }

        it "Should have the PowerShell extension installed" {
            (Get-ChildItem -Path $home\.vscode\extensions).Name -Match "ms-vscode\.powershell" | Should -Not -Be $null
        }

        it "Should have the yaml extension installed" {
            (Get-ChildItem -Path $home\.vscode\extensions).Name -Match "redhat\.vscode-yaml" | Should -Not -Be $null
        }
    }

    Context "Task 2" {
        it "Should have Az module installed" {
            (Get-Module -List Az.*).Count | Should -BeGreaterOrEqual 45 -Because "We need the module Az installed with all its components"
        }

        it "Should be logged in to Azure (use Login-AzAccount)" {
            { Get-AzContext } | Should -Not -Throw
            Get-AzContext | Should -Not -Be $null
        }
    }
}
