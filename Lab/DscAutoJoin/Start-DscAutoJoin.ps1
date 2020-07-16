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

. $PSScriptRoot\DscConfigs\DscAutoJoinConfiguration.ps1
. $PSScriptRoot\DscConfigs\DscAutoJoinMetaConfiguration.ps1


if (-not (Test-Path -Path HKLM:\SOFTWARE\DscAutoJoin)) {
    New-Item -Path HKLM:\SOFTWARE\DscAutoJoin -Force | Out-Null
}
Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoJoin -Name Environment -Value $Environment -Type String -Force
Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoJoin -Name Role -Value $Role -Type String -Force
Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoJoin -Name Location -Value $Location -Type String -Force
Set-ItemProperty -Path HKLM:\SOFTWARE\DscAutoJoin -Name Description -Value $Description -Type String -Force

LcmConfig -OutputPath C:\DSC
DscAutoJoin -OutputPath C:\DSC

Set-DscLocalConfigurationManager -Path C:\DSC -Verbose
Start-DscConfiguration -Path C:\DSC -Wait -Verbose -Force