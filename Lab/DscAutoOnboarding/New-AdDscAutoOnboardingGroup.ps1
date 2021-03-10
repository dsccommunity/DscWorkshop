param (
    [Parameter(Mandatory)]
    [string]$DevOpsServer
)

Invoke-LabCommand -ActivityName 'Create AD Group for DscAutoOnboarding' -ComputerName $devOpsServer -ScriptBlock {
    $ou = Get-ADOrganizationalUnit -Filter { Name -eq 'DscAutoOnboarding' }
    if (-not $ou)
    {
        $ou = New-ADOrganizationalUnit -Name DscAutoOnboarding -ProtectedFromAccidentalDeletion $false -PassThru
    }

    $g = Get-ADGroup -Filter { Name -eq 'DscNodes' }
    if (-not $g) {
        $g = New-ADGroup -Name DscNodes -GroupScope Global -Path $ou -PassThru
    }
    else {
        Write-Warning "The group 'DscNodes' does already exist."
    }

    $id = New-Object System.Security.Principal.NTAccount("$($devOpsServer)$")
    $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $id,
        [System.DirectoryServices.ActiveDirectoryRights]::WriteProperty,
        [System.Security.AccessControl.AccessControlType]::Allow,
        "bf9679c0-0de6-11d0-a285-00aa003049e2",
        [DirectoryServices.ActiveDirectorySecurityInheritance]::All
    )

    $g = [adsi]("LDAP://" + $g.DistinguishedName)
    $g.ObjectSecurity.AddAccessRule($ace)
    $g.CommitChanges()

} -Variable (Get-Variable -Name DevOpsServer)
