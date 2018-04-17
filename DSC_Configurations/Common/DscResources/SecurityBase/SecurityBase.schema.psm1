Configuration SecurityBase {
    Param(
        [ValidateSet(1, 2, 3)]
        [Parameter(Mandatory)]
        [int]$SecurityLevel
    )
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    $lmCompatibilityLevel = switch ($SecurityLevel) {
        1 { 3 }
        2 { 4 }
        3 { 5 }
    }

    if ($SecurityLevel -ge 2) {
        Registry DisableLmHash {
            Key       = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa'
            ValueName = 'NoLmHash'
            ValueData = 1
            ValueType = 'Dword'
            Ensure    = 'Present'
        }

        Registry LmCompatibilityLevel {
            Key       = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa'
            ValueName = 'LmCompatibilityLevel'
            ValueData = $lmCompatibilityLevel
            ValueType = 'Dword'
            Ensure    = 'Present'
        }
    }
}