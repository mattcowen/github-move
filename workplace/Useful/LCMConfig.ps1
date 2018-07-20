#
# Script.ps1
# Change LCM configuration. Execute this then 


[DSCLocalConfigurationManager()]
configuration LCMConfig
{
    Node localhost
    {
        Settings
        {
            RefreshMode = 'Push'
            ConfigurationMode = 'ApplyOnly'

        }
    }
} 


