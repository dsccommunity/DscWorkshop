AppVeyor Build
DevOps Build

AppVeyor Release (AfterBuild step)
DevOps Release (Pipeline)

Release OnPrem (Copy to pull server)
Release OnAzure (Copy modules + MOF to Azure Automation)
  Copy Azure Blob, get URLs
  New-AzAutomationModule mit URLs
  Publish MOF
  