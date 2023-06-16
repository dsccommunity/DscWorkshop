#Region '.\Enum\checksumType.ps1' 0
enum checksumType
{
    md5
    LastModifiedTime
    CreationTime
}
#EndRegion '.\Enum\checksumType.ps1' 7
#Region '.\Enum\encoding.ps1' 0
enum encoding
{
    ASCII
    Latin1
    UTF7
    UTF8
    UTF32
    BigEndianUnicode
    Default
    Unicode
}
#EndRegion '.\Enum\encoding.ps1' 12
#Region '.\Enum\ensure.ps1' 0
enum ensure
{
    present
    absent
}

#EndRegion '.\Enum\ensure.ps1' 7
#Region '.\Enum\linkBehavior.ps1' 0
enum linkBehavior
{
    follow
    manage
}
#EndRegion '.\Enum\linkBehavior.ps1' 6
#Region '.\Enum\objectType.ps1' 0
enum objectType
{
    file
    directory
    symboliclink
}
#EndRegion '.\Enum\objectType.ps1' 7
#Region '.\Classes\002.FileSystemObject.ps1' 0
class FileSystemDscReason
{
    [DscProperty()]
    [System.String]
    $Code

    [DscProperty()]
    [System.String]
    $Phrase
}

<#
    .SYNOPSIS
        The File resource enables file system operations on Linux and Windows.
        With regards to parameters and globbing, it behaves like the Item and Content
        cmdlets.

    .PARAMETER DestinationPath
        The path to create/copy to.

    .PARAMETER SourcePath
        If data should be copied, the source path to copy from.
    .PARAMETER Ensure
        Indicates if destination should be created or removed. Values: Absent, Present. Default: Present.

    .PARAMETER Type
        The type of the object to create. Values: file, directory, symboliclink. Default: directory

    .PARAMETER Contents
        The file contents. Unused if type is directory

    .PARAMETER Checksum
        The type of checksum to use for copy operations. Values: md5, CreationTime, LastModifiedTime. Default: md5

    .PARAMETER Recurse
        Indicates that recurse should be used if data is copied.

    .PARAMETER Force
        Indicates that folder structures should be created and existing files overwritten

    .PARAMETER Links
        Link behavior, currently not implemented. Values: follow, manage. Default: follow

    .PARAMETER Group
        Linux group name for chown, currently not implemented.

    .PARAMETER Mode
        Linux mode for chmod, currently not implemented.

    .PARAMETER Owner
        Linux owner name for chown, currently not implemented.

    .PARAMETER Encoding
        File encoding, used with Contents. Values: ASCII, Latin1, UTF7, UTF8, UTF32, BigEndianUnicode, Default, Unicode. Default: Default

    .PARAMETER IgnoreTrailingWhitespace
        Indicates that trailing whitespace should be ignored when comparing file contents.
#>
[DscResource()]
class FileSystemObject
{
    [DscProperty(Key)]
    [string]
    $DestinationPath

    [DscProperty()]
    [string]
    $SourcePath

    [DscProperty()]
    [ensure]
    $Ensure = [ensure]::present

    [DscProperty()]
    [objectType]
    $Type = [objectType]::directory

    [DscProperty()]
    [string]
    $Contents

    [DscProperty()]
    [checksumType]
    $Checksum = [checksumType]::md5

    [DscProperty()]
    [bool]
    $Recurse = $false

    [DscProperty()]
    [bool]
    $Force = $false

    [DscProperty()]
    [linkBehavior]
    $Links = [linkBehavior]::follow

    [DscProperty()]
    [string]
    $Group

    [DscProperty()]
    [string]
    $Mode

    [DscProperty()]
    [string]
    $Owner

    [DscProperty(NotConfigurable)]
    [datetime]
    $CreatedDate

    [DscProperty(NotConfigurable)]
    [datetime]
    $ModifiedDate

    [DscProperty()]
    [encoding]
    $Encoding = 'Default'

    [DscProperty()]
    [bool]
    $IgnoreTrailingWhitespace

    [DscProperty(NotConfigurable)]
    [FileSystemDscReason[]]
    $Reasons

    [FileSystemObject] Get ()
    {
        $returnable = @{
            DestinationPath          = $this.DestinationPath
            SourcePath               = $this.SourcePath
            Ensure                   = $this.Ensure
            Type                     = $this.Type
            Contents                 = ''
            Checksum                 = $this.Checksum
            Recurse                  = $this.Recurse
            Force                    = $this.Force
            Links                    = $this.Links
            Encoding                 = $this.Encoding
            Group                    = ''
            Mode                     = ''
            Owner                    = ''
            IgnoreTrailingWhitespace = $this.IgnoreTrailingWhitespace
            CreatedDate              = [datetime]::new(0)
            ModifiedDate             = [datetime]::new(0)
            Reasons                  = @()
        }

        if ($this.Type -eq [objectType]::directory -and -not [string]::IsNullOrWhiteSpace($this.Contents))
        {
            Write-Verbose -Message "Type is directory, yet parameter Contents was used."
            $returnable.Reasons += @{
                Code   = "File:File:ParameterMismatch"
                Phrase = "Type is directory, yet parameter Contents was used."
            }
            return [FileSystemObject]$returnable
        }

        $object = Get-Item -ErrorAction SilentlyContinue -Path $this.DestinationPath -Force
        if ($null -eq $object -and $this.Ensure -eq [ensure]::present)
        {
            Write-Verbose -Message "Object $($this.DestinationPath) does not exist, but Ensure is set to 'Present'"
            $returnable.Reasons += @{
                Code   = "File:File:ObjectMissingWhenItShouldExist"
                Phrase = "Object $($this.DestinationPath) does not exist, but Ensure is set to 'Present'"
            }
            return [FileSystemObject]$returnable
        }

        if ($null -ne $object -and $this.Ensure -eq [ensure]::absent)
        {
            Write-Verbose -Message "Object $($this.DestinationPath) exists, but Ensure is set to 'Absent'"
            $returnable.Reasons += @{
                Code   = "File:File:ObjectExistsWhenItShouldNot"
                Phrase = "Object $($this.DestinationPath) exists, but Ensure is set to 'Absent'"
            }
            return [FileSystemObject]$returnable
        }

        if ($object.Count -eq 1 -and ($object.Attributes -band 'ReparsePoint') -eq 'ReparsePoint')
        {
            $returnable.Type = 'SymbolicLink'
        }
        elseif ($object.Count -eq 1 -and ($object.Attributes -band 'Directory') -eq 'Directory')
        {
            $returnable.Type = 'Directory'
        }
        elseif ($object.Count -eq 1)
        {
            $returnable.Type = 'File'
        }

        if ($returnable.Type -ne $this.Type)
        {
            $returnable.Reasons += @{
                Code   = "File:File:TypeMismatch"
                Phrase = "Type of $($object.FullName) has type '$($returnable.Type)', should be '$($this.Type)'"
            }
        }

        $returnable.DestinationPath = $object.FullName
        if ([string]::IsNullOrWhiteSpace($this.SourcePath) -and $object -and $this.Type -eq [objectType]::file)
        {
            $returnable.Contents = Get-Content -Raw -Path $object.FullName -Encoding $this.Encoding.ToString()
        }

        if (-not $this.Ensure -eq 'Absent' -and -not [string]::IsNullOrWhiteSpace($returnable.Contents) -and $this.IgnoreTrailingWhitespace)
        {
            $returnable.Contents = $returnable.Contents.Trim()
        }

        if (-not [string]::IsNullOrWhiteSpace($this.Contents) -and $returnable.Contents -ne $this.Contents)
        {
            $returnable.Reasons += @{
                Code   = "File:File:ContentMismatch"
                Phrase = "Content of $($object.FullName) different from parameter Contents"
            }
        }

        if ($object.Count -eq 1)
        {
            $returnable.CreatedDate = $object.CreationTime
            $returnable.ModifiedDate = $object.LastWriteTime
            $returnable.Owner = $object.User
            $returnable.Mode = $object.Mode
            $returnable.Group = $object.Group
        }

        if (-not [string]::IsNullOrWhiteSpace($this.SourcePath))
        {
            if (-not $this.Recurse -and $this.Type -eq [objectType]::directory)
            {
                Write-Verbose -Message "Directory is copied without Recurse parameter. Skipping file checksum"
                return [FileSystemObject]$returnable
            }

            #$destination = if (-not $this.Recurse -and $this.SourcePath -notmatch '\*\?\[\]')
            #{
            #    Join-Path $this.DestinationPath (Split-Path $this.SourcePath -Leaf)
            #}
            #else
            #{
            #    $this.DestinationPath
            #}
            $destination = $this.DestinationPath

            if (-not (Test-Path -Path $destination))
            {
                Write-Verbose -Message "The destination path '$destination' does not exist"
                $returnable.Reasons += @{
                    Code   = "File:File:DestinationPathNotFound"
                    Phrase = "The destination path '$destination' does not exist"
                }
            }

            if (-not (Test-Path -Path $this.SourcePath))
            {
                Write-Verbose -Message "The source path '$($this.SourcePath)' does not exist"
                $returnable.Reasons += @{
                    Code   = "File:File:SourcePathNotFound"
                    Phrase = "The source path '$($this.SourcePath)' does not exist"
                }
            }

            if ((Test-Path -Path $destination) -and (Test-Path -Path $this.SourcePath))
            {
                $currHash = $this.CompareHash($destination, $this.SourcePath, $this.Checksum, $this.Recurse)

                if ($currHash.Count -gt 0)
                {
                    Write-Verbose -Message "Hashes of files in $($this.DestinationPath) (comparison path used: $destination) different from hashes in $($this.SourcePath)"
                    $returnable.Reasons += @{
                        Code   = "File:File:HashMismatch"
                        Phrase = "Hashes of files in $($this.DestinationPath) different from hashes in $($this.SourcePath)"
                    }
                }
            }
        }
        return [FileSystemObject]$returnable
    }

    [void] Set()
    {
        if ($this.Ensure -eq 'Absent')
        {
            Write-Verbose -Message "Removing $($this.DestinationPath) with Recurse and Force"
            Remove-Item -Recurse -Force -Path $this.DestinationPath
            return
        }

        if ($this.Type -in [objectType]::file, [objectType]::directory -and [string]::IsNullOrWhiteSpace($this.SourcePath))
        {
            Write-Verbose -Message "Creating new $($this.Type) $($this.DestinationPath), Force"
            $param = @{
                ItemType = $this.Type
                Path     = $this.DestinationPath
            }
            if ($this.Force)
            {
                $param['Force'] = $true
            }
            $null = New-Item @param
        }

        if ($this.Type -eq [objectType]::SymbolicLink)
        {
            Write-Verbose -Message "Creating new symbolic link $($this.DestinationPath) --> $($this.SourcePath)"
            New-Item -ItemType SymbolicLink -Path $this.DestinationPath -Value $this.SourcePath
            return
        }

        if ($this.Contents)
        {
            Write-Verbose -Message "Setting content of $($this.DestinationPath) using $($this.Encoding)"
            $this.Contents | Set-Content -Path $this.DestinationPath -Force -Encoding $this.Encoding.ToString() -NoNewline
        }

        if ($this.SourcePath -and ($this.SourcePath -match '\*|\?\[\]') -and -not (Test-Path -Path $this.DestinationPath))
        {
            Write-Verbose -Message "Creating destination directory for wildcard copy $($this.DestinationPath)"
            $null = New-Item -ItemType Directory -Path $this.DestinationPath
        }

        if ($this.SourcePath)
        {
            Write-Verbose -Message "Copying from $($this.SourcePath) to $($This.DestinationPath), Recurse is $($this.Recurse), Using the Force: $($this.Force)"
            $copyParam = @{
                Path        = $this.SourcePath
                Destination = $this.DestinationPath
            }
            if ($this.Recurse)
            {
                $copyParam['Recurse'] = $this.Recurse
            }
            if ($this.Force)
            {
                $copyParam['Force'] = $this.Force
            }
            Copy-Item @copyParam
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()

        return ($currentState.Reasons.Count -eq 0)
    }

    [System.IO.FileInfo[]] CompareHash([string]$Path, [string]$ReferencePath, [checksumType]$Type = 'md5', [bool]$Recurse)
    {
        [object[]]$sourceHashes = $this.GetHash($ReferencePath, $Type, $Recurse)
        [object[]]$hashes = $this.GetHash($Path, $Type, $Recurse)

        if ($hashes.Count -eq 0)
        {
            return [System.IO.FileInfo[]]$sourceHashes.Path
        }

        $comparison = Compare-Object -ReferenceObject $sourceHashes -DifferenceObject $hashes -Property Hash -PassThru | Where-Object SideIndicator -eq '<='
        return [System.IO.FileInfo[]]$comparison.Path
    }

    # Return type unclear and either Microsoft.PowerShell.Commands.FileHashInfo or PSCustomObject
    # Might be better to create a custom class for this
    [object[]] GetHash([string]$Path, [checksumType]$Type, [bool]$Recurse)
    {
        $hashStrings = if ($Type -eq 'md5')
        {
            Get-ChildItem -Recurse:$Recurse -Path $Path -Force -File | Get-FileHash -Algorithm md5
        }
        else
        {
            $propz = @(
                @{
                    Name       = 'Path'
                    Expression = { $_.FullName }
                }
                @{
                    Name       = 'Algorithm'
                    Expression = { $Type }
                }
                @{
                    Name       = 'Hash'
                    Expression = { if ($Type -eq 'CreationTime')
                        {
                            $_.CreationTime
                        }
                        else
                        {
                            $_.LastWriteTime
                        }
                    }
                }
            )
            Get-ChildItem -Recurse:$Recurse -Path $Path -Force -File | Select-Object -Property $propz
        }

        return $hashStrings
    }
}
#EndRegion '.\Classes\002.FileSystemObject.ps1' 405

