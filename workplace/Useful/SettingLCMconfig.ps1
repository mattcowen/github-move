#
# SettingLCMconfig.ps1

# get the current config
Get-DscLocalConfigurationManager

# generate MOF
LCMConfig

# trigger the config assuming the MOF are in a directory called "lcmconfig"
Set-DscLocalConfigurationManager -Path .\lcmconfig -ComputerName localhost