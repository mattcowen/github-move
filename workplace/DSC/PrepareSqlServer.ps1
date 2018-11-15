configuration PrepareSqlServer
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,
        
        [String]$primaryAdIpAddress,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SQLServicecreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SharePointSetupUserAccountcreds,
				
		[string]$sqlInstallationISOUri,

        [UInt32]$DatabaseEnginePort = 1433,

        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),
		
	    [Parameter(Mandatory = $false)] 
		[ValidateNotNullorEmpty()] 
		[String]$SystemTimeZone="GMT Standard Time",
        
        [Int]$RetryCount=10,
        [Int]$RetryIntervalSec=5
    )

    Import-DscResource -ModuleName ComputerManagementDsc,xActiveDirectory,StorageDsc, SqlServerDsc, NetworkingDsc, FileDownloadDsc, xDownloadISO
    $spSetupUsername = "SpSetup"
	
	[System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$SPSCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SharePointSetupUserAccountcreds.UserName)", $SharePointSetupUserAccountcreds.Password)
    [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SQLServicecreds.UserName)", $SQLServicecreds.Password)

	
	$dataDisks = Get-Disk | where{$_.PartitionStyle -eq "RAW"}
	$dataDiskNumberOne = $dataDisks[0].Number
	$dataDiskNumberTwo = $dataDisks[1].Number
	

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
             DiskId = $dataDiskNumberOne
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        Disk DataDisk
        {
            DiskId = $dataDiskNumberOne
            DriveLetter = "F"
            DependsOn = '[WaitforDisk]Disk2'
        }

        WaitforDisk Disk3
        {
             DiskId = $dataDiskNumberTwo
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
             DependsOn = '[Disk]DataDisk'
        }

        Disk LogDisk
        {
            DiskId = $dataDiskNumberTwo
            DriveLetter = "G"
            DependsOn = '[WaitforDisk]Disk3'
        }

        WindowsFeature FC
        {
            Name = "Failover-Clustering"
            Ensure = "Present"
            DependsOn = '[Disk]LogDisk'
        }

        WindowsFeature FCPS
        {
            Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
            DependsOn = '[WindowsFeature]FC'
        }

        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
            DependsOn = '[WindowsFeature]FCPS'
        }
		
		
		WindowsFeature DotNet45
        {
            Name   = 'NET-Framework-45-Core'
            Ensure = 'Present'
            DependsOn = '[WindowsFeature]ADPS'
        }

        xDownloadISO Download
        {
            SourcePath               = $sqlInstallationISOUri
            DestinationDirectoryPath = "C:\SQL2016"
            DependsOn                = '[WindowsFeature]DotNet45'
        }

        xWaitForADDomain DscForestWait 
        { 
            DomainName           = $DomainName 
            DomainUserCredential = $DomainCreds
            RetryCount           = $RetryCount 
            RetryIntervalSec     = $RetryIntervalSec 
            DependsOn            = '[xDownloadISO]Download'
        }

        Computer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
            DependsOn = '[xWaitForADDomain]DscForestWait'
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


        File SQLUpdatesFolder
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "C:\SQL2016\Updates"
            DependsOn = '[WindowsFeature]RsatAddsTools'
        }

		
        xADUser CreateSqlServerServiceAccount
        {
            DomainAdministratorCredential = $DomainCreds
			DomainController = "adPDC.$DomainName"
            DomainName = $DomainName
            UserName = $SQLServicecreds.UserName
			UserPrincipalName = "$($SQLServicecreds.UserName)@${DomainName}"
            Password = $SQLCreds
            Ensure = "Present"
			DependsOn = '[File]SQLUpdatesFolder'
        }
		
        SqlSetup InstallSqlServer
        {
            InstanceName =  "MSSQLSERVER"
            SourcePath = 'C:\SQL2016'
            UpdateSource = ".\Updates"
            UpdateEnabled = "False"
			SQMReporting = "False"
			SQLSvcAccount = $SQLCreds
            SQLSysAdminAccounts = $DomainCreds.username
            Features= "SQLENGINE"
            SecurityMode="SQL"
            SAPwd=$SQLCreds
            SQLUserDBDir = "F:\SQL\Data"
            SQLUserDBLogDir = "G:\SQL\Log"
            DependsOn = '[xADUser]CreateSqlServerServiceAccount'
        }

		SqlServerMaxDop SetMaxDop
        {
            InstanceName = "MSSQLSERVER"
            MaxDop = 1
			Ensure = 'Present'
            DependsOn = "[SqlSetup]InstallSqlServer"
        }
		
		SqlServerNetwork SetNetwork
		{
            InstanceName =  "MSSQLSERVER"
			ProtocolName = "tcp"
			IsEnabled = $true
			TcpPort = "1433"
			RestartService = $true
            DependsOn = '[SqlSetup]InstallSqlServer'
		}
		
        SqlWindowsFirewall Create_FirewallRules_For_SQL2016
        {
            Ensure        = 'Present'
            Features      = 'SQLENGINE'
            InstanceName  = 'MSSQLSERVER'
            SourcePath    = 'C:\SQL2016'
            DependsOn     = '[SqlServerNetwork]SetNetwork'
        }
		
		#SSMS is no longer included with SQL Server
		FileDownload 'DownloadSSMS17-8-1'
		{
			Url = 'https://go.microsoft.com/fwlink/?linkid=875802'
			FileName = 'C:\SSMS17-8-1.exe'
			DependsOn = '[SqlSetup]InstallSqlServer'
		}

		Package SSMSInstall
		{
			Ensure = 'Present'
			Name = 'SSMS-Setup-ENU'
			Path = 'C:\SSMS17-8-1.exe'
			Arguments = "/install /passive /norestart"
			ProductId = "945B6BB0-4D19-4E0F-AE57-B2D94DA32313"
			Credential = $DomainCreds
			DependsOn = '[FileDownload]DownloadSSMS17-8-1'
		}
				

		xADUser CreateSpSetupAccount
        {
            DomainAdministratorCredential = $DomainCreds
			DomainController = "adPDC.$DomainName"
			UserPrincipalName = "$($SharePointSetupUserAccountcreds.UserName)@${DomainName}"
            DomainName = $DomainName
            UserName = $SharePointSetupUserAccountcreds.UserName
            Password = $SPSCreds
			Enabled = $True
            Ensure = "Present"
            DependsOn = '[SqlSetup]InstallSqlServer'
        }

		SqlServerLogin AddDomainAdminAccountToSysadminServerRole
        {
			ServerName = "localhost"
			InstanceName = "MSSQLSERVER"
            Name = $DomainCreds.UserName
			LoginType = "WindowsUser"
            DependsOn = "[xADUser]CreateSpSetupAccount"
        }

        SqlServerLogin AddSqlServerServiceAccountToSysadminServerRole
        {
			#ServerName = "sql.$DomainName"
			ServerName = "localhost"
			InstanceName = "MSSQLSERVER"
            Name = $SQLCreds.UserName
			LoginType = "WindowsUser"
            DependsOn = "[SqlServerLogin]AddDomainAdminAccountToSysadminServerRole"
        }
		
		SqlServerLogin AddSpSetupAccountToSysadminServerRole
        {
            #ServerName = "sql.$DomainName"
            ServerName = "localhost"
			InstanceName = "MSSQLSERVER"
			Name = $SPSCreds.UserName
            LoginType = "WindowsUser"
            DependsOn = "[SqlServerLogin]AddSqlServerServiceAccountToSysadminServerRole"
        }

		SqlServerRole Add_ServerRole_AdminSqlforBI
        {
            Ensure               = 'Present'
            ServerRoleName       = 'sysadmin'
            MembersToInclude     = @($SQLCreds.UserName, $SPSCreds.UserName)
            ServerName           = "sql"
            InstanceName         = 'MSSQLSERVER'
            PsDscRunAsCredential = $DomainCreds
            DependsOn = "[SqlServerLogin]AddSpSetupAccountToSysadminServerRole"
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
        return $DomainName.Substring(0,$length).ToUpperInvariant()
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15).ToUpperInvariant()
        }
        else {
            return $DomainName.ToUpperInvariant()
        }
    }
}

function WaitForSqlSetup
{
    # Wait for SQL Server Setup to finish before proceeding.
    while ($true)
    {
        try
        {
            Get-ScheduledTaskInfo "\ConfigureSqlImageTasks\RunConfigureImage" -ErrorAction Stop
            Start-Sleep -Seconds 5
        }
        catch
        {
            break
        }
    }
}
