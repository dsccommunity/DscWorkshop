function FlattenArray
{
    param (
        [Parameter(Mandatory)]
        [array]$InputObject
    )
    ,@($InputObject | ForEach-Object { $_ })
}