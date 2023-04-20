Configuration UserAmyNotPresent {
    Import-DSCResource -ModuleName 'xPSDesiredStateConfiguration'

    Node UserAmyNotPresent
    {
        xUser 'UserAmyNotPresent'
        {
            Ensure   = 'Absent'
            UserName = 'amy'
        }
    }
}
