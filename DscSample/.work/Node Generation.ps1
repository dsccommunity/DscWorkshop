$yaml = @"
NodeName: {0}
Environment: Dev
Role: {2}
Description: File Server in Dev
Location: Frankfurt

NetworkIpConfiguration:
  IpAddress: 192.168.111.{1}
  Prefix: 24
  Gateway: 192.168.111.50
  DnsServer: 192.168.111.10
  InterfaceAlias: Ethernet
  DisableNetbios: True

PSDscAllowPlainTextPassword: True
PSDscAllowDomainUser: True

LcmConfig:
  ConfigurationRepositoryWeb:
    Server:
      ConfigurationNames: {0}
"@

1..100 | ForEach-Object {
    $nodeName = 'DSCFile{0:D4}' -f $_
    $newYaml = $yaml -f $nodeName, $_, 'FileServer' 
    $newYaml | Out-File -FilePath "$PSScriptRoot\..\DSC_ConfigData\AllNodes\Dev\$nodeName.yml"
}