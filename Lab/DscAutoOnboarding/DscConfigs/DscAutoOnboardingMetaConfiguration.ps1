[DSCLocalConfigurationManager()]
configuration LcmConfig
{
    Node localhost
    {
        Settings {
            RefreshMode                    = 'Push'
            RebootNodeIfNeeded             = $true
            ConfigurationMode              = 'ApplyAndAutoCorrect'
            ConfigurationModeFrequencyMins = 15
        }
    }
}
