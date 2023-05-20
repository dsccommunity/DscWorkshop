$softwarePackages = @{
    VsCode                    = @{
        Url         = 'https://az764295.vo.msecnd.net/stable/704ed70d4fd1c6bd6342c436f1ede30d1cff4710/VSCodeSetup-x64-1.77.3.exe'
        CommandLine = '/VERYSILENT /MERGETASKS=!runcode'
        Roles    = 'AzDevOps'
    }
    Git                       = @{
        Url         = 'https://github.com/git-for-windows/git/releases/download/v2.40.0.windows.1/Git-2.40.0-64-bit.exe'
        CommandLine = '/SILENT'
        Roles    = 'AzDevOps'
    }
    NotepadPlusPlus           = @{
        Url         = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.5.1/npp.8.5.1.Installer.x64.exe'
        CommandLine = '/S'
        Roles    = 'All'
    }
    PowerShell7               = @{
        Url         = 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.3/PowerShell-7.3.3-win-x64.msi'
        CommandLine = '/quiet'
        Roles    = 'AzDevOps'
    }
    Dotnet7Sdk                = @{
        Url         = 'https://download.visualstudio.microsoft.com/download/pr/89a2923a-18df-4dce-b069-51e687b04a53/9db4348b561703e622de7f03b1f11e93/dotnet-sdk-7.0.203-win-x64.exe'
        CommandLine = '/install /quiet /norestart'
        Roles    = 'AzDevOps'
    }
    DotNetCoreRuntime         = @{
        Url         = 'https://download.visualstudio.microsoft.com/download/pr/b92958c6-ae36-4efa-aafe-569fced953a5/1654639ef3b20eb576174c1cc200f33a/windowsdesktop-runtime-3.1.32-win-x64.exe'
        CommandLine = '/install /quiet /norestart'
        Roles    = 'AzDevOps'
    }
    '7zip'                    = @{
        Url         = 'https://7-zip.org/a/7z2201-x64.exe'
        CommandLine = '/S'
        Roles    = 'All'
    }
    VsCodePowerShellExtension = @{
        Url               = 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/PowerShell/2023.4.0/vspackage'
        DestinationFolder = 'VSCodeExtensions'
    }
}
