$pullServer = Get-LabVM -Role DSCPullServer
$sqlServer = Get-LabVM -Role SQLServer2017, SQLServer2019

Get-LabInternetFile -Uri https://download.microsoft.com/download/5/E/B/5EB40744-DC0A-47C0-8B0A-1830E74D3C23/ReportBuilder.msi -Path $labSources\SoftwarePackages\ReportBuilder.msi
Get-LabInternetFile -Uri https://download.microsoft.com/download/E/6/4/E6477A2A-9B58-40F7-8AD6-62BB8491EA78/SQLServerReportingServices.exe -Path $labSources\SoftwarePackages\SQLServerReportingServices.exe
Install-LabSoftwarePackage -Path $labsources\SoftwarePackages\ReportBuilder.msi -ComputerName $sqlServer
Install-LabSoftwarePackage -Path $labsources\SoftwarePackages\SQLServerReportingServices.exe -CommandLine '/Quiet /IAcceptLicenseTerms' -ComputerName $sqlServer

Invoke-LabCommand -ActivityName 'Configuring SSRS' -ComputerName $sqlServer -FilePath $labSources\PostInstallationActivities\SqlServer\SetupSqlServerReportingServices.ps1

if (-not (Get-Module -Name ReportingServicesTools -ListAvailable)) {
    Install-Module -Name ReportingServicesTools -Force
}
$s = New-LabPSSession -ComputerName $sqlServer
Send-ModuleToPSSession -Module (Get-Module -Name ReportingServicesTools -ListAvailable | Select-Object -First 1) -Session $s

Copy-LabFileItem -Path $PSScriptRoot\Reports -ComputerName $sqlServer -DestinationFolderPath C:\ -Recurse -UseAzureLabSourcesOnAzureVm $false

Invoke-LabCommand -ActivityName 'Add DSC Reports to Reporting Server' -ComputerName $sqlServer -ScriptBlock {

    New-RsFolder -ReportServerUri http://localhost/ReportServer -Path / -Name DSC

    New-RsDataSource -Name DSCDS -ConnectionString 'Server=localhost;Database=DSC;Trusted_Connection=True;' -RsFolder /DSC -Extension SQL -CredentialRetrieval Integrated
    New-RsDataSource -Name DSCDS -ConnectionString 'Server=localhost;Database=DSC;Trusted_Connection=True;' -RsFolder / -Extension SQL -CredentialRetrieval Integrated

    Write-RsFolderContent -ReportServerUri http://localhost/ReportServer -Path C:\Reports -Destination /DSC
}

Checkpoint-LabVM -All -SnapshotName AfterSqlReporting
Write-Host "4. - Creating Snapshot 'AfterSqlReporting'" -ForegroundColor Magenta