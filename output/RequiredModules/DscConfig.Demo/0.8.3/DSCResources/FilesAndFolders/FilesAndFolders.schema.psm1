configuration FilesAndFolders
{
    param (
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Items
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName FileSystemDsc

    foreach ($item in $Items)
    {
        [string]$fileHash      = $null
        [string]$base64Content = $null

        $permissions = $null

        # Remove Case Sensitivity of ordered Dictionary or Hashtables
        $item = @{} + $item

        if (-not $item.ContainsKey('Ensure'))
        {
            $item.Ensure = 'Present'
        }

        if ($item.ContainsKey('Permissions'))
        {
            $permissions = $item.Permissions
            $item.Remove('Permissions')
        }

        if ($item.ContainsKey('ContentFromFile'))
        {
            if ( -not (Test-Path -Path $item.ContentFromFile) )
            {
                throw "ERROR: Content file '$($item.ContentFromFile)' not found. Current working directory is: $(Get-Location)"
            }
            else
            {
                if ( [string]::IsNullOrWhiteSpace( $item.Type ) -or $item.Type -eq 'File' )
                {
                    [string]$content = Get-Content -Path $item.ContentFromFile -Raw
                    $item.Contents += $content
                    $item.Type = 'File'
                }
                elseif ( $item.Type -eq 'BinaryFile' )
                {
                    $filePath      = Resolve-Path $item.ContentFromFile
                    $fileHash      = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash
                    $base64Content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePath))
                }
                else
                {
                    throw "ERROR: Type '$($item.Type)' is not supported with embedding file content of '$($item.ContentFromFile)'."
                }
            }
            $item.Remove('ContentFromFile')
        }

        $executionName = "file_$($item.DestinationPath)" -replace '[\s(){}/\\:-]', '_'

        if ($item.Type -ne 'BinaryFile')
        {
            (Get-DscSplattedResource -ResourceName File -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
        }
        else
        {
            if ( [string]::IsNullOrWhiteSpace( $fileHash ) -or [string]::IsNullOrWhiteSpace( $base64Content ) )
            {
                throw "ERROR: Type 'BinaryFile' requires an valid attribute 'ContentFromFile'."
            }

            [string]$destPath = $item.DestinationPath
            [string]$ensure   = $item.Ensure

            Script $executionName
            {
                TestScript = {
                    Write-Verbose "Testing file '$using:destPath'..."
                    if ( (Test-Path -Path $using:destPath) )
                    {
                        Write-Verbose "Verifying file content..."
                        if ( $using:fileHash -eq (Get-FileHash -Path $using:destPath -Algorithm SHA256).Hash )
                        {
                            Write-Verbose "OK"
                            return $true
                        }
                    }
                    elseif ( $using:ensure -eq 'Absent' )
                    {
                        Write-Verbose "OK (absent)"
                        return $true
                    }
                    Write-Verbose "Not OK"
                    return $false
                }
                SetScript  = {
                    if ( $using:ensure -eq 'Absent' )
                    {
                        Write-Verbose "Removing file '$using:destPath'..."
                        Remove-Item -Path $using:destPath -Force
                    }
                    else
                    {
                        $dirName = [System.IO.Path]::GetDirectoryName($using:destPath)
                        if ( -not (Test-Path -Path $dirName) )
                        {
                            Write-Verbose "Creating directory '$dirName'..."
                            New-Item -Path $dirName -ItemType Directory -Force
                        }
                        Write-Verbose "Writing file '$using:destPath'..."
                        Remove-Item -Path $using:destPath -Force -ErrorAction SilentlyContinue
                        [IO.File]::WriteAllBytes($using:destPath, [Convert]::FromBase64String($using:base64Content))
                    }
                }
                GetScript  = {
                    return @{
                        result = 'N/A'
                    }
                }
            }
        }

        if ($null -ne $permissions)
        {
            foreach ($perm in $permissions)
            {
                # Remove Case Sensitivity of ordered Dictionary or Hashtables
                $perm = @{} + $perm

                $perm.Path = $item.DestinationPath
                $perm.DependsOn = "[File]$executionName"

                if (-not $perm.ContainsKey('Ensure'))
                {
                    $perm.Ensure = 'Present'
                }

                $permExecName = "$($executionName)__$($perm.Identity)" -replace '[\s(){}/\\:-]', '_'

                (Get-DscSplattedResource -ResourceName FileSystemAccessRule -ExecutionName $permExecName -Properties $perm -NoInvoke).Invoke($perm)
            }
        }
    }
}
