$labName = 'DscLab1'
if (-not (Get-Lab -ErrorAction SilentlyContinue).Name -eq $labName)
{
    Import-Lab -Name $labName -NoValidation
}

$sqlServer = Get-LabVM -Role SQLServer2016 | Select-Object -First 1

#-------------------------------------------------------------------------------------------------

#report builder Url: https://download.microsoft.com/download/5/E/B/5EB40744-DC0A-47C0-8B0A-1830E74D3C23/ReportBuilder3.msi
#.\SQLServerReportingServices.exe /Quiet /IAcceptLicenseTerms
Install-LabSoftwarePackage -Path $labsources\SoftwarePackages\ReportBuilder3.msi -ComputerName $sqlServer
$s = New-LabPSSession -ComputerName $sqlServer
Send-ModuleToPSSession -Module (Get-Module -Name ReportingServicesTools -ListAvailable) -Session $s

Copy-LabFileItem -Path $PSScriptRoot\Reports -ComputerName $sqlServer -DestinationFolderPath C:\ -Recurse -UseAzureLabSourcesOnAzureVm $false

Invoke-LabCommand -ActivityName 'Add DSC Reports to Reporting Server' -ComputerName $sqlServer -ScriptBlock {

    New-RsFolder -ReportServerUri http://localhost/ReportServer -Path / -Name DSC -Verbose

    New-RsDataSource -Name DSCDS -ConnectionString 'Server=localhost;Database=DSC;Trusted_Connection=True;' -RsFolder /DSC -Extension SQL -CredentialRetrieval Integrated
    New-RsDataSource -Name DSCDS -ConnectionString 'Server=localhost;Database=DSC;Trusted_Connection=True;' -RsFolder / -Extension SQL -CredentialRetrieval Integrated

    Write-RsFolderContent -ReportServerUri http://localhost/ReportServer -Path .\Reports -Destination /DSC -Verbose
}

Get-RsFolderContent -RsFolder / | Remove-RsCatalogItem -Confirm:$false