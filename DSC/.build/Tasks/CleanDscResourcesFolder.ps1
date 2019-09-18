task CleanDscResourcesFolder {
    Get-ChildItem -Path "$ResourcesFolder" -Recurse | Remove-Item -Force -Recurse -Exclude README.md
}
