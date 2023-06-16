configuration LocalUsers {
    param (
        [Parameter()]
        [hashtable[]]
        $Users
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    function AddMemberOf
    {
        param (
            [Parameter()]
            [string]
            $ExecutionName,

            [Parameter()]
            [string]
            $ExecutionType,

            [Parameter()]
            [string]
            $AccountName,

            [Parameter()]
            [string[]]
            $MemberOf
        )

        if ( $null -ne $MemberOf -and $MemberOf.Count -gt 0 )
        {
            Script "$($ExecutionName)_MemberOf"
            {
                TestScript =
                {
                    # get current member groups of the local user
                    $currentGroups = Get-LocalGroup | Where-Object { (Get-LocalGroupMember $_ -Member $using:AccountName -ErrorAction SilentlyContinue).Count -eq 1 } | Select-Object -ExpandProperty Name

                    Write-Verbose "Principal '$using:AccountName' is member of local groups: $($currentGroups -join ', ')"

                    $missingGroups = $using:MemberOf | Where-Object { -not ($currentGroups -contains $_) }

                    if ( $missingGroups.Count -eq 0 )
                    {
                        return $true
                    }

                    Write-Verbose "Principal '$using:AccountName' is not member of required local groups: $($missingGroups -join ', ')"
                    return $false
                }
                SetScript  =
                {
                    $missingGroups = $using:MemberOf | Where-Object { (Get-LocalGroupMember $_ -Member $using:AccountName -ErrorAction SilentlyContinue).Count -eq 0 }

                    Write-Verbose "Adding principal '$using:AccountName' to local groups: $($missingGroups -join ', ')"

                    foreach ( $group in $missingGroups )
                    {
                        Add-LocalGroupMember -Group $group -Member $using:AccountName -Verbose
                    }
                }
                GetScript  = { return 'NA' }
                DependsOn  = "[$ExecutionType]$ExecutionName"
            }
        }
    }

    foreach ($user in $Users)
    {
        # save group list
        $memberOf = $user.MemberOf
        $user.Remove( 'MemberOf' )

        $executionName = "localUser_$($user.UserName)" -replace '[\s(){}/\\:-]', '_'
        (Get-DscSplattedResource -ResourceName xUser -ExecutionName $executionName -Properties $user -NoInvoke).Invoke($user)

        AddMemberOf -ExecutionName $executionName -ExecutionType xUser -AccountName $user.UserName -MemberOf $memberOf
    }
}
