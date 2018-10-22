$computers = Get-ADComputer -Filter { Name -like 'DSCWeb*' -or Name -like 'DSCFile*' } | Select-Object -ExpandProperty DNSHostName

Update-DscConfiguration -ComputerName $computers -Verbose -Wait

Start-DscConfiguration -UseExisting -Wait -Verbose -Force -ComputerName $computers