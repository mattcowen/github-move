configuration ConfigureBackupDC
{
   param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    Import-DscResource -ModuleName xActiveDirectory, xPendingReboot

    Node localhost
    {
        
        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential= $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
        }
        xADDomainController BDC
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }
        Script script1
        {
            SetScript =
            {
				# remove the dns forwarding rule
				# modified to resolve error "Failed to get information for server ADBDC"
                $i = 0
				$dnsFwdRule
				do
				{
					$i++
					Start-Sleep 10
					$dnsFwdRule = Get-DnsServerForwarder
				}
				while ($i -lt 10 -and $dnsFwdRule.IPAddress -eq $null) 

                if ($dnsFwdRule -and $dnsFwdRule.IPAddress)
                {
					Write-Verbose -Verbose "Removing DNS forwarding rule"
                    Remove-DnsServerForwarder -IPAddress $dnsFwdRule.IPAddress -Force
					Write-Verbose -Verbose "Removed DNS forwarding rule"
                }
				else
				{
					Write-Verbose -Verbose "No DNS forwarding rule or no IP address"
				}
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = "[xADDomainController]BDC"
        }

		
		WindowsFeature RsatAdds {
			Name = "RSAT-ADDS"
            Ensure = "Present"
			DependsOn = "[Script]script1"
		}
		
		WindowsFeature RsatAddsTools {
			Name = "RSAT-ADDS-Tools"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]RsatAdds"
		}

		LocalConfigurationManager
        {
       	    ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
    }
}
