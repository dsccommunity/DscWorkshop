function Add-AzStorageBlob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $ArmTemplatePath,

        [Parameter(Mandatory)]
        [string]
        $Environment
    )

    $storageAccount = Get-AzStorageAccount -ResourceGroupName $env:StorageAccountResourceGroup -Name $env:StorageAccountName
    $templateContainer = Get-AzStorageContainer -Name $env:TemplateBlobContainer -Context $storageAccount.Context
    foreach ($file in (Get-ChildItem -Path "$ArmTemplatePath\$($Environment)*.json" ))
    {
        Set-AzStorageBlobContent -File $file.FullName -CloudBlobContainer $templateContainer.CloudBlobContainer -Blob "$($env:BHProjectName)/$($Environment)/$($file.Name)" -Context $storageAccount.Context -Force -Confirm:$false
    }
}