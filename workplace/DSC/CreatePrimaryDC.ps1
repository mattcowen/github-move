configuration CreatePrimaryDC
{
   param
   (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

	    [Parameter(Mandatory = $false)] 
		[ValidateNotNullorEmpty()] 
		[String]$SystemTimeZone="GMT Standard Time",
        
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xActiveDirectory, NetworkingDsc, StorageDsc, FileDownloadDsc, ComputerManagementDsc, PSDesiredStateConfiguration
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

		TimeZone TimeZoneExample 
		{ 
			IsSingleInstance = 'Yes'
			TimeZone = $SystemTimeZone 
		} 

        WindowsFeature DNS
        {
            Ensure = "Present"
            Name = "DNS"
        }

        WindowsFeature DnsTools
        {
            Ensure = "Present"
            Name = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
        }

        DnsServerAddress DnsServerAddress
        {
            Address        = '127.0.0.1'
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn = "[WindowsFeature]DNS"
        }

        Script script1
        {
      	    SetScript = {
                Set-DnsServerDiagnostics -All $true
                Write-Verbose -Verbose "Enabling DNS client diagnostics"
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = "[WindowsFeature]DNS"
        }

        WaitforDisk Disk2
        {
            DiskId = 2
            RetryIntervalSec =$RetryIntervalSec
            RetryCount = $RetryCount
            DependsOn = "[Script]script1"
        }

        Disk ADDataDisk
        {
            DiskId = 2
            DriveLetter = "F"
            DependsOn="[WaitforDisk]Disk2"
        }

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
            DependsOn="[Disk]ADDataDisk"
        }

        xADDomain FirstDS
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

		#xDnsRecord SharePointSiteDns
		#{
		#	Name = "sites"
		#	Zone = $DomainName
		#	Target = "sharepoint.${DomainName}."
		#	Type = "CName"
		#	Ensure = "Present"
  #          DependsOn = "[WindowsFeature]DNS"
		#}

		WindowsFeature RsatAdds {
			Name = "RSAT-ADDS"
            Ensure = "Present"
			DependsOn = "[xADDomain]FirstDS"
		}
		
		WindowsFeature RsatAddsTools {
			Name = "RSAT-ADDS-Tools"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]RsatAdds"
		}

   }
}
