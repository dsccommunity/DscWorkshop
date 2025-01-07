param (
    [Parameter()]
    [string]$LabName = 'DscWorkshop'
)

if ((Get-Lab -ErrorAction SilentlyContinue).Name -ne $LabName)
{
    try
    {
        Write-host "Importing lab '$LabName'"
        Import-Lab -Name $LabName -NoValidation -ErrorAction Stop
    }
    catch
    {
        Write-Host "Lab '$LabName' could not be imported. Trying to find a lab with a name starting with 'DscWorkshop*'"
        $possibleLabs = Get-Lab -List | Where-Object { $_ -like 'DscWorkshop*' }
        if ($possibleLabs.Count -gt 1)
        {
            Write-Error "There are multiple 'DscWorkshop' labs ($($possibleLabs -join ', ')). Please remove the ones you don't need."
            exit
        }
        else
        {
            Write-Host "Importing lab '$possibleLabs'"
            Import-Lab -Name $possibleLabs -NoValidation -ErrorAction Stop
        }
    }
}

$pullServer = Get-LabVM -Role DSCPullServer
$sqlServer = Get-LabVM -Role SQLServer2017, SQLServer2019

Get-LabInternetFile -Uri https://download.microsoft.com/download/5/E/B/5EB40744-DC0A-47C0-8B0A-1830E74D3C23/ReportBuilder.msi -Path $labSources\SoftwarePackages\ReportBuilder.msi
Get-LabInternetFile -Uri https://download.microsoft.com/download/E/6/4/E6477A2A-9B58-40F7-8AD6-62BB8491EA78/SQLServerReportingServices.exe -Path $labSources\SoftwarePackages\SQLServerReportingServices.exe
Install-LabSoftwarePackage -Path $labsources\SoftwarePackages\ReportBuilder.msi -ComputerName $sqlServer
Install-LabSoftwarePackage -Path $labsources\SoftwarePackages\SQLServerReportingServices.exe -CommandLine '/Quiet /IAcceptLicenseTerms' -ComputerName $sqlServer

Invoke-LabCommand -ActivityName 'Configuring SSRS' -ComputerName $sqlServer -FilePath $labSources\PostInstallationActivities\SqlServer\SetupSqlServerReportingServices.ps1

if (-not (Get-Module -Name ReportingServicesTools -ListAvailable))
{
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
