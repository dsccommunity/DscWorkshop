$latestBuild = dir C:\Artifacts\DscWorkshopBuild | Sort-Object -Property { [int]$_.Name } -Descending | Select-Object -First 1

#cd "$($latestBuild.FullName)\DscWorkshop\MetaMof"
#cd "$($latestBuild.FullName)\DscWorkshop\MOF"

start "$($latestBuild.FullName)\DscWorkshop"