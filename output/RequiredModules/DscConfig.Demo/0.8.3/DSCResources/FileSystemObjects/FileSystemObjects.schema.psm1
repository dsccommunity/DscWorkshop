configuration FileSystemObjects
{
    param (
        [Parameter()]
        [hashtable[]]
        $Items
    )

    <#
    FileSystemObject [String] #ResourceName
    {
        DestinationPath = [string]
        [Checksum = [string]{ CreationTime | LastModifiedTime | md5 }]
        [Contents = [string]]
        [DependsOn = [string[]]]
        [Encoding = [string]{ ASCII | BigEndianUnicode | Default | Latin1 | Unicode | UTF32 | UTF7 | UTF8 }]
        [Ensure = [string]{ absent | present }]
        [Force = [bool]]
        [Group = [string]]
        [IgnoreTrailingWhitespace = [bool]]
        [Links = [string]{ follow | manage }]
        [Mode = [string]]
        [Owner = [string]]
        [PsDscRunAsCredential = [PSCredential]]
        [Recurse = [bool]]
        [SourcePath = [string]]
        [Type = [string]{ directory | file | symboliclink }]
    }
    #>

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName FileSystemDsc

    foreach ($item in $Items)
    {
        $executionName = "FileSystemObject_$($item.DestinationPath)" -replace '[\s(){}/\\:-]', '_'
        (Get-DscSplattedResource -ResourceName FileSystemObject -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
    }
}
