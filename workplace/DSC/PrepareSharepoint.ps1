Configuration PrepareSharepoint
{
   param
    (
		[Parameter(Mandatory)]
        [String]$DomainName,
		
        [Parameter(Mandatory)]
		[String]$primaryAdIpAddress,

        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]$Admincreds,

        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]$SharePointSetupUserAccountcreds,

        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]$SharePointFarmAccountcreds,

        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]$Passphrase,

        [parameter(Mandatory)]
        [String]$DatabaseName,

        [parameter(Mandatory)]
        [String]$DatabaseServer,
		
		[parameter(Mandatory)]
		[String]$InstallSourceDrive,
		
		[parameter(Mandatory)]
		[String]$InstallSourceFolderName,
		
		[parameter(Mandatory)]
		[String]$ProductKey,
		
		[parameter(Mandatory)]
		[String]$SPDLLink,
		
		[Parameter(Mandatory = $false)] 
		[ValidateNotNullorEmpty()] 
		[String]$SystemTimeZone="GMT Standard Time",
        
        [Int]$RetryCount=10,
        [Int]$RetryIntervalSec=5
    )

	Write-Verbose "AzureExtensionHandler loaded continuing with configuration"
	$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName)

 	[System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    
	Write-Verbose -Message "Admin username = ${DomainNetbiosName}\$($Admincreds.UserName)"

	[System.Management.Automation.PSCredential ]$SPSetupAccount = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SharePointSetupUserAccountcreds.UserName)", $SharePointSetupUserAccountcreds.Password)
    
	Write-Verbose -Message "Setup username = ${DomainNetbiosName}\$($SharePointSetupUserAccountcreds.UserName)"

	[System.Management.Automation.PSCredential ]$FarmAccount = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SharePointFarmAccountcreds.UserName)", $SharePointFarmAccountcreds.Password)
	[System.Management.Automation.PSCredential ]$SpAdmin = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\SpAdmin", $Admincreds.Password)
	[System.Management.Automation.PSCredential ]$SpReader = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\SpReader", $Admincreds.Password)
	[System.Management.Automation.PSCredential ]$WebPoolManagedAccount = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\SpWebPool", $Admincreds.Password)
	[System.Management.Automation.PSCredential ]$ServicePoolManagedAccount = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\SpServicePool", $Admincreds.Password)

	
	$Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)
	
	# Get the disk number of the data disk
	$dataDisk = Get-Disk | where{$_.PartitionStyle -eq "RAW"}
	$dataDiskNumber = 2
	if($dataDisk){
		$dataDiskNumber = $dataDisk[0].Number
	}

    Import-DscResource -ModuleName ComputerManagementDsc, StorageDsc, NetworkingDsc, SharePointDSC, FileDownloadDSC, xPendingReboot, xActiveDirectory, xDownloadISO
    

    Node localhost
    {
		LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }
		
		TimeZone TimeZoneExample 
		{ 
			IsSingleInstance = 'Yes'
			TimeZone = $SystemTimeZone 
		} 

		WaitforDisk Disk2
        {
            DiskId = $dataDiskNumber
            RetryIntervalSec =$RetryIntervalSec
            RetryCount = $RetryCount
        }
        Disk SPDataDisk
        {
            DiskId = $dataDiskNumber
            DriveLetter = "F"
            DependsOn = "[WaitforDisk]Disk2"
        }
		DnsServerAddress domainDNS
		{
			Address = $primaryAdIpAddress
			InterfaceAlias = $InterfaceAlias
			AddressFamily = 'IPv4'
			DependsOn = "[Disk]SPDataDisk"
		}
        
        Computer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn = "[DnsServerAddress]domainDNS" 
        }

		WindowsFeature RsatAdds {
			Name = "RSAT-ADDS"
            Ensure = "Present"
			DependsOn = "[Computer]DomainJoin"
		}
		
		WindowsFeature RsatAddsTools {
			Name = "RSAT-ADDS-Tools"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]RsatAdds"
		}

		# N.B. The Setup Account was created in PrepareSQLServer and added to dbcreator 
		# and securityadmin roles but we need to make that user local admin on the SP box
		Group AddSetupUserAccountToLocalAdminsGroup
        {
            GroupName = "Administrators"
            Credential = $DomainCreds
            MembersToInclude = "${DomainNetbiosName}\$($SharePointSetupUserAccountcreds.UserName)"
            Ensure="Present"
            DependsOn = "[WindowsFeature]RsatAddsTools"
        }

		xADUser CreateSpAdminAccount
        {
            DomainAdministratorCredential = $DomainCreds
			DomainController = "adPDC.$DomainName"
            DomainName = $DomainName
            UserName = "SpAdmin"
			UserPrincipalName = "SpAdmin@${DomainName}"
            Password = $SpAdmin
            Ensure = "Present"
            DependsOn = '[WindowsFeature]RsatAddsTools'
        }
		xADUser CreateSpReaderAccount
        {
            DomainAdministratorCredential = $DomainCreds
			DomainController = "adPDC.$DomainName"
            DomainName = $DomainName
            UserName = "SpReader"
			UserPrincipalName = "SpReader@${DomainName}"
            Password = $SpReader
            Ensure = "Present"
            DependsOn = '[WindowsFeature]RsatAddsTools'
        }

		xADUser CreateSpFarmAccount
        {
            DomainAdministratorCredential = $DomainCreds
			DomainController = "adPDC.$DomainName"
            DomainName = $DomainName
            UserName = $SharePointFarmAccountcreds.UserName
            Password = $SharePointFarmAccountcreds
			UserPrincipalName = "$($SharePointFarmAccountcreds.UserName)@${DomainName}"
            Ensure = "Present"
            DependsOn = '[WindowsFeature]RsatAddsTools'
        }
        
		xADUser CreateWebPoolAccount
        {
            DomainAdministratorCredential = $DomainCreds
			DomainController = "adPDC.$DomainName"
            DomainName = $DomainName
            UserName = "SpWebPool"
            Password = $WebPoolManagedAccount
			UserPrincipalName = "$($WebPoolManagedAccount.UserName)@${DomainName}"
            Ensure = "Present"
            DependsOn = '[WindowsFeature]RsatAddsTools'
        }

		xADUser CreateServicePoolAccount
        {
            DomainAdministratorCredential = $DomainCreds
			DomainController = "adPDC.$DomainName"
            DomainName = $DomainName
            UserName = "SpServicePool"
            Password = $ServicePoolManagedAccount
			UserPrincipalName = "$($ServicePoolManagedAccount.UserName)@${DomainName}"
            Ensure = "Present"
            DependsOn = '[WindowsFeature]RsatAddsTools'
        }

		xDownloadISO DownloadSPImage
        {
            SourcePath = $SPDLLink
            DestinationDirectoryPath = "F:\installer\"
            DependsOn = '[Disk]SPDataDisk'
        }
		
		#**********************************************************
        # Install Binaries
        #
        # This section installs SharePoint and its Prerequisites
		#**********************************************************

		SPInstallPrereqs InstallPrereqs {
            Ensure            = "Present"
            InstallerPath     = "F:\installer\prerequisiteinstaller.exe"
			IsSingleInstance  = 'Yes'
            OnlineMode        = $true
			DependsOn = '[xDownloadISO]DownloadSPImage'
		}
			
		SPInstall InstallSharePoint {
            Ensure = "Present"
            BinaryDir = "F:\installer\"
			IsSingleInstance  = 'Yes'
            ProductKey = $ProductKey
            DependsOn = "[SPInstallPrereqs]InstallPrereqs"
		}

		#**********************************************************
        # Basic farm configuration
        #
        # This section creates the new SharePoint farm object, and
        # provisions generic services and components used by the
        # whole farm
        #**********************************************************
  
        SPFarm CreateSPFarm
        {
            Ensure                   = "Present"
			IsSingleInstance         = 'Yes'
            DatabaseServer           = "sql"
            AdminContentDatabaseName = "SP_AdminContent"
            FarmConfigDatabaseName   = "SP_Config"
            FarmAccount              = $FarmAccount
            Passphrase               = $Passphrase
            PsDscRunAsCredential     = $SPSetupAccount
  			ServerRole               = "SingleServerFarm"
            RunCentralAdmin          = $true
			CentralAdministrationPort = 2016
			CentralAdministrationAuth = "NTLM"
            DependsOn                = "[SPInstall]InstallSharePoint"
		}

		SPManagedAccount ServicePoolManagedAccount
        {
            AccountName          = "SpServicePool"
            Account              = $ServicePoolManagedAccount
            PsDscRunAsCredential = $SPSetupAccount
			Ensure               = "Present"
            DependsOn            = "[SPFarm]CreateSPFarm"
		}	
		SPManagedAccount WebPoolManagedAccount
        {
            AccountName          = "SpWebPool"
            Account              = $WebPoolManagedAccount
            PsDscRunAsCredential = $SPSetupAccount
			Ensure               = "Present"
            DependsOn            = "[SPManagedAccount]ServicePoolManagedAccount"
		}
		
		File CreateUsageLogs
		{
			DestinationPath = "F:\UsageLogs"
			Ensure = "Present"
			Type = "Directory"
			DependsOn = '[SPManagedAccount]WebPoolManagedAccount'
		}

		SPDiagnosticLoggingSettings ApplyDiagnosticLogSettings
        {
            PsDscRunAsCredential                        = $SPSetupAccount
			IsSingleInstance                            = 'Yes'
            LogPath                                     = "F:\ULS"
            LogSpaceInGB                                = 5
            AppAnalyticsAutomaticUploadEnabled          = $false
            CustomerExperienceImprovementProgramEnabled = $true
            DaysToKeepLogs                              = 7
            DownloadErrorReportingUpdatesEnabled        = $false
            ErrorReportingAutomaticUploadEnabled        = $false
            ErrorReportingEnabled                       = $false
            EventLogFloodProtectionEnabled              = $true
            EventLogFloodProtectionNotifyInterval       = 5
            EventLogFloodProtectionQuietPeriod          = 2
            EventLogFloodProtectionThreshold            = 5
            EventLogFloodProtectionTriggerPeriod        = 2
            LogCutInterval                              = 15
            LogMaxDiskSpaceUsageEnabled                 = $true
            ScriptErrorReportingDelay                   = 30
            ScriptErrorReportingEnabled                 = $true
            ScriptErrorReportingRequireAuth             = $true
            DependsOn                                   = "[SPManagedAccount]WebPoolManagedAccount"
		}
		SPUsageApplication UsageApplication 
        {
            Name                  = "Usage Service Application"
            DatabaseName          = "SP_Usage"
            UsageLogCutTime       = 5
            UsageLogLocation      = "F:\UsageLogs"
            UsageLogMaxFileSizeKB = 1024
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn            = "[SPDiagnosticLoggingSettings]ApplyDiagnosticLogSettings"
		}
        SPStateServiceApp StateServiceApp
        {
            Name                 = "State Service Application"
            DatabaseName         = "SP_State"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPUsageApplication]UsageApplication"
        }
        SPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            Ensure               = "Present"
            CacheSizeInMB        = 1024
            ServiceAccount       = "SpServicePool"
            PsDscRunAsCredential = $SPSetupAccount
            CreateFirewallRules  = $true
            DependsOn            = "[SPStateServiceApp]StateServiceApp"
		}

        #**********************************************************
        # Web applications
        #
        # This section creates the web applications in the 
        # SharePoint farm, as well as managed paths and other web
        # application settings
        #**********************************************************

        SPWebApplication SharePointSites
        {
            Name                   = "SharePoint Sites"
            ApplicationPool        = "SharePoint Sites"
            ApplicationPoolAccount = $WebPoolManagedAccount.UserName
            AllowAnonymous         = $false
            DatabaseName           = "SP_Content"
            WebAppUrl              = "http://sites.$DomainName"
			DatabaseServer         = "sql"
            Port                   = 80
            PsDscRunAsCredential   = $SPSetupAccount
            DependsOn              = "[SPDistributedCacheService]EnableDistributedCache"
		}
		

        SPCacheAccounts WebAppCacheAccounts
        {
            WebAppUrl              = "http://sites.$DomainName"
            SuperUserAlias         = "${DomainNetbiosName}\SpAdmin"
            SuperReaderAlias       = "${DomainNetbiosName}\SpReader"
            PsDscRunAsCredential   = $SPSetupAccount
            DependsOn              = "[SPWebApplication]SharePointSites"
        }

		
        SPSite TeamSite
        {
            Url                    = "http://sites.$DomainName"
            OwnerAlias             = $DomainCreds.UserName
            Name                   = "DSC Demo Site"
            Template               = "STS#0"
            PsDscRunAsCredential   = $SPSetupAccount
            DependsOn              = "[SPCacheAccounts]WebAppCacheAccounts"
        }

        #**********************************************************
        # Service instances
        #
        # This section describes which services should be running
        # and not running on the server
        #**********************************************************

        SPServiceInstance ClaimsToWindowsTokenServiceInstance
        {  
            Name                 = "Claims to Windows Token Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }   

        SPServiceInstance SecureStoreServiceInstance
        {  
            Name                 = "Secure Store Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }
        
        SPServiceInstance ManagedMetadataServiceInstance
        {  
            Name                 = "Managed Metadata Web Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPServiceInstance BCSServiceInstance
        {  
            Name                 = "Business Data Connectivity Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }
        
        SPServiceInstance SearchServiceInstance
        {  
            Name                 = "SharePoint Server Search"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        #**********************************************************
        # Service applications
        #
        # This section creates service applications and required
        # dependencies
        #**********************************************************

        $serviceAppPoolName = "SharePoint Service Applications"
        SPServiceAppPool MainServiceAppPool
        {
            Name                 = $serviceAppPoolName
            ServiceAccount       = "SpServicePool"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPSecureStoreServiceApp SecureStoreServiceApp
        {
            Name                  = "Secure Store Service Application"
            ApplicationPool       = $serviceAppPoolName
            AuditingEnabled       = $true
            AuditlogMaxSize       = 30
            DatabaseName          = "SP_SecureStore"
			Ensure                = "Present"
			PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }


        SPManagedMetaDataServiceApp ManagedMetadataServiceApp
        {  
            Name                 = "Managed Metadata Service Application"
            PsDscRunAsCredential = $SPSetupAccount
            ApplicationPool      = $serviceAppPoolName
            DatabaseName         = "SP_MMS"
			DatabaseServer       = "sql" 
			Ensure               = "Present"
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPBCSServiceApp BCSServiceApp
        {
            Name                  = "BCS Service Application"
            ApplicationPool       = $serviceAppPoolName
            DatabaseName          = "SP_BCS"
			DatabaseServer        = "sql"
			Ensure                = "Present"
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPSecureStoreServiceApp]SecureStoreServiceApp')
        }

        SPSearchServiceApp SearchServiceApp
        {  
            Name                  = "Search Service Application"
            DatabaseName          = "SP_Search"
            DatabaseServer        = "sql" 
			Ensure                = "Present"
            ApplicationPool       = $serviceAppPoolName
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }


		
        
        #**********************************************************
        # Local configuration manager settings
        #
        # This section contains settings for the LCM of the host
        # that this configuraiton is applied to
        #**********************************************************
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
			ActionAfterReboot = "ContinueConfiguration"
        }

    }
   
}


function Get-NetBIOSName
{ 
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
}