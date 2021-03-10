param(
    [Parameter(Mandatory)]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$Role,

    [Parameter(Mandatory)]
    [string]$Location,

    [Parameter()]
    [string]$Description
)

$repository = Get-PSRepository | Where-Object InstallationPolicy -eq Trusted
Install-Module -Name ComputerManagementDsc, CertificateDsc -Repository $repository.Name -ErrorAction Stop

. $PSScriptRoot\DscConfigs\DscAutoOnboardingConfiguration.ps1
. $PSScriptRoot\DscConfigs\DscAutoOnboardingMetaConfiguration.ps1


if (-not (Test-Path -Path HKLM:\SOFTWARE\DscAutoOnboarding)) {
    New-Item -Path HKLM:\SOFTWARE\DscAutoOnboarding -Force | Out-Null
}
Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name Environment -Value $Environment -Type String -Force
Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name Role -Value $Role -Type String -Force
Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name Location -Value $Location -Type String -Force
Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoOnboarding -Name Description -Value $Description -Type String -Force

LcmConfig -OutputPath C:\DSC
DscAutoOnboarding -OutputPath C:\DSC

Set-DscLocalConfigurationManager -Path C:\DSC -Verbose
Start-DscConfiguration -Path C:\DSC -Wait -Verbose -Force