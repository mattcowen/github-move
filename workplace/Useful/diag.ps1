#
# https://docs.microsoft.com/en-us/powershell/dsc/troubleshooting/troubleshooting
#

Get-xDscOperation -Newest 20
Trace-xDscOperation
Trace-xDscOperation -JobID 9e0bfb6b-3a3a-11e6-9165-00155d390509