task CleanDscConfigurationsFolder {
    Get-ChildItem -Path "$ConfigurationsFolder" -Recurse | Remove-Item -Force -Recurse -Exclude README.md
}
