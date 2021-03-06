﻿Configuration PrepareExchange
{
    param
    (
		
		[Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()] 
		[String]$DomainName,

		[Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()] 
		[String]$StorageSize,
		
		[Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()] 
		[PSCredential]$VMAdminCreds,
		
		[Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()] 
		[String]$DnsServerIpAddress,
		
		[parameter(Mandatory)]
		[String]$ExchangeLink,
		
		[Parameter(Mandatory = $false)] 
		[ValidateNotNullorEmpty()] 
		[String]$SystemTimeZone="GMT Standard Time",
        
		[Int]$RetryCount=5,
        [Int]$RetryIntervalSec=10
    )
	$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName)

	$DomainCreds = [System.Management.Automation.PSCredential]$DomainFQDNCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($VMAdminCreds.UserName)", $VMAdminCreds.Password)

    Import-DscResource -ModuleName  StorageDsc, NetworkingDsc, ComputerManagementDsc, PSDesiredStateConfiguration, FileDownloadDSC, xExchange, xPendingReboot, xDownloadISO
    
	

	# Downloaded file storage location
	$exchangeInstallerPath = "$env:SystemDrive\Exchange";
	$diskNumber = 2;
	$Interface = (Get-NetAdapter|Where Name -Like "Ethernet*" | Select-Object -First 1)
    $InterfaceAlias=$($Interface.Name)


	Node localhost
    {
        LocalConfigurationManager
        {
			RebootNodeIfNeeded = $true;
			ActionAfterReboot = "ContinueConfiguration";
        }
		
		TimeZone TimeZoneExample 
		{ 
			IsSingleInstance = 'Yes'
			TimeZone = $SystemTimeZone 
		} 

        WaitforDisk Disk2
        {
            DiskId = 2
            RetryIntervalSec =$RetryIntervalSec
            RetryCount = $RetryCount
        }
        Disk ExchangeDataDisk
        {
            DiskId = 2
            DriveLetter = "F"
            DependsOn = "[WaitforDisk]Disk2"
        }
		DnsServerAddress domainDNS
		{
			Address = $DnsServerIpAddress
			InterfaceAlias = $InterfaceAlias
			AddressFamily = 'IPv4'
			Validate = $true
			DependsOn = "[Disk]ExchangeDataDisk"
		}
        Computer JoinDomain
		{
			Name = $env:COMPUTERNAME
			DomainName = $DomainName
			Credential = $DomainCreds
			DependsOn = "[DnsServerAddress]domainDNS"
		}


		# Install Exchange 2016 Pre-requisits | Reference: https://technet.microsoft.com/en-us/library/bb691354(v=exchg.160).aspx
		
		WindowsFeature Net45Features {
			Name = "NET-Framework-45-Features"
            Ensure = "Present"
			DependsOn = "[Computer]JoinDomain"
		}
		WindowsFeature WebAspNet45 {
			Name = "Web-Asp-Net45"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]Net45Features"
		}
		
		FileDownload DownloadDotNetFx472
		{
			Url = "http://go.microsoft.com/fwlink/?LinkId=863262"
			FileName = "$env:SystemDrive\dotnet.exe"
			DependsOn = "[WindowsFeature]Net45Features"
		}

		Script dotNet472 {
            GetScript = { }
            SetScript = {
                Start-Process -FilePath "$env:SystemDrive\dotnet.exe" -ArgumentList '/q' -Wait
            }
            TestScript = {
                Get-ChildItem 'HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\' |
                    Get-ItemPropertyValue -Name Release |
                        ForEach-Object {$_ -ge 461814}
            }
			DependsOn = "[FileDownload]DownloadDotNetFx472"
			}

		<#
		I had to add the following registry key to prevent Hybrid Detection during setup. I
		think this was caused by my AAD being linked at some point to a demo office 365 env.

		## TODO: add the following registry key to disable Hybrid Detection during setup
		Path:  HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ExchangeServer\v15\Setup
		Type: REG_SZ
		Name: RunHybridDetection
		Value: 1  

		#>
		Script disableHybridDetectionRegKey {
            GetScript = { }
            SetScript = {
				$registryPath = 'HKLM:SOFTWARE\Microsoft\ExchangeServer\v15\Setup\'
				$name = 'RunHybridDetection'
				$value = '1'
                New-Item -Path $registryPath -Force | Out-Null
				New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType String -Force | Out-Null
            }
            TestScript = {
                Test-Path 'HKLM:SOFTWARE\Microsoft\ExchangeServer\v15\Setup\'
            }
			DependsOn = "[Script]dotNet472"
        }

		WindowsFeature RPCOverHTTPProxy {
			Name = "RPC-over-HTTP-proxy"
            Ensure = "Present"
			DependsOn = "[Script]disableHybridDetectionRegKey"
		}
		WindowsFeature RSATClustering {
			Name = "RSAT-Clustering"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]RPCOverHTTPProxy"
		}
		WindowsFeature RSATClusteringCmd {
			Name = "RSAT-Clustering-CmdInterface"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]RSATClustering"
		}
		WindowsFeature RSATClusteringMgmt {
			Name = "RSAT-Clustering-Mgmt"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]RSATClusteringCmd"
		}
		WindowsFeature RSATClusteringPS {
			Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]RSATClusteringMgmt"
		}
		WindowsFeature WASProcessModel {
			Name = "WAS-Process-Model"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]RSATClusteringPS"
		}
		WindowsFeature WebBasicAuth {
			Name = "Web-Basic-Auth"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WASProcessModel"
		}
		WindowsFeature WebClientAuth {
			Name = "Web-Client-Auth"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebBasicAuth"
		}
		WindowsFeature WebDigestAuth {
			Name = "Web-Digest-Auth"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebClientAuth"
		}
		WindowsFeature WebDirBrowsing {
			Name = "Web-Dir-Browsing"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebDigestAuth"
		}
		WindowsFeature WebDynCompression {
			Name = "Web-Dyn-Compression"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebDirBrowsing"
		}
		WindowsFeature WebHttpErrors {
			Name = "Web-Http-Errors"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebDynCompression"
		}
		WindowsFeature WebHttpLogging {
			Name = "Web-Http-Logging"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebHttpErrors"
		}
		WindowsFeature WebHttpRedirect {
			Name = "Web-Http-Redirect"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebHttpLogging"
		}
		WindowsFeature WebHttpTracing {
			Name = "Web-Http-Tracing"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebHttpRedirect"
		}
		WindowsFeature WebISAPIExt {
			Name = "Web-ISAPI-Ext"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebHttpTracing"
		}
		WindowsFeature WebISAPIFilter {
			Name = "Web-ISAPI-Filter"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebISAPIExt"
		}
		WindowsFeature WebLgcyMgmtConsole {
			Name = "Web-Lgcy-Mgmt-Console"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebISAPIFilter"
		}
		WindowsFeature WebMetabase {
			Name = "Web-Metabase"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebLgcyMgmtConsole"
		}
		WindowsFeature WebMgmtConsole {
			Name = "Web-Mgmt-Console"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebMetabase"
		}
		WindowsFeature WebMgmtService {
			Name = "Web-Mgmt-Service"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebMgmtConsole"
		}
		WindowsFeature WebNetExt45 {
			Name = "Web-Net-Ext45"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebMgmtService"
		}
		WindowsFeature NetWcfActivation {
			Name = "NET-WCF-HTTP-Activation45"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebNetExt45"
		}
		WindowsFeature WebRequestMonitor {
			Name = "Web-Request-Monitor"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]NetWcfActivation"
		}
		WindowsFeature WebServer {
			Name = "Web-Server"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebRequestMonitor"
		}
		WindowsFeature WebStatCompression {
			Name = "Web-Stat-Compression"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebServer"
		}
		WindowsFeature WebStaticContent {
			Name = "Web-Static-Content"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebStatCompression"
		}
		WindowsFeature WebWindowsAuth {
			Name = "Web-Windows-Auth"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebStaticContent"
		}
		WindowsFeature WebWMI {
			Name = "Web-WMI"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebWindowsAuth"
		}
		WindowsFeature WindowsIdentityFoundation {
			Name = "Windows-Identity-Foundation"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WebWMI"
		}
		WindowsFeature RsatAdds {
			Name = "RSAT-ADDS"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]WindowsIdentityFoundation"
		}
		
		WindowsFeature RsatAddsTools {
			Name = "RSAT-ADDS-Tools"
            Ensure = "Present"
			DependsOn = "[WindowsFeature]RsatAdds"
		}

		FileDownload DownloadUnifiedCommsManager
		{
			Url = "https://download.microsoft.com/download/2/C/4/2C47A5C1-A1F3-4843-B9FE-84C0032C61EC/UcmaRuntimeSetup.exe"
			FileName = "$env:SystemDrive\UcmaRuntimeSetup.exe"
			DependsOn = "[WindowsFeature]RsatAddsTools"
		}


		# Install Unified Communication Manager API 4.0
        Package InstallUCMA4
		{
			Ensure = "Present"
			Name = "Microsoft Unified Communications Managed API 4.0, Runtime"
			Path = "$env:SystemDrive\UcmaRuntimeSetup.exe"
			ProductId = '41D635FE-4F9D-47F7-8230-9B29D6D42D31'
			Arguments = '-q' # args for silent mode
			DependsOn = "[FileDownload]DownloadUnifiedCommsManager"
		}
		
		# Reboot node if necessary
		xPendingReboot RebootPostInstallUCMA4
        {
            Name      = "AfterUCMA4"
            DependsOn = "[Package]InstallUCMA4"
        }
		
		# if running again manually you may need to remove the directory 
		# $exchangeInstallerPath otherwise the ISO isn't downloaded
		File SetupFolder
		{
			Ensure = "Absent"
			DestinationPath = $exchangeInstallerPath
			Force = $true
			Type = "Directory"
		   DependsOn = "[xPendingReboot]RebootPostInstallUCMA4"
		}
		
		xDownloadISO DownloadExchangeImage
        {
            SourcePath = $ExchangeLink
            DestinationDirectoryPath = $exchangeInstallerPath
            DependsOn = "[xPendingReboot]RebootPostInstallUCMA4"
        }

		File ExchangeFolder
		{
			Ensure = "Present"
			DestinationPath = "F:\Exchange"
			Type = "Directory"
			DependsOn = "[xDownloadISO]DownloadExchangeImage"
		}

		# prepare AD will also prepare the schema
		# we only have one domain so we don't need to prepare domains (it was done in PrepareAD)
		xExchInstall PrepAD
		{
			Path = "$exchangeInstallerPath\setup.exe"
            Arguments = "/PrepareAD /OrganizationName:MCSC /DomainController:adPDC.$DomainName /IAcceptExchangeServerLicenseTerms"
            Credential = $DomainCreds
            DependsOn = '[xDownloadISO]DownloadExchangeImage'

		}

		
		# For version integers see 
		# https://docs.microsoft.com/en-us/Exchange/plan-and-deploy/prepare-ad-and-domains?view=exchserver-2016#step-2-prepare-active-directory
		xExchWaitForADPrep WaitPrepAD
		{
			Identity            = "not used"
			Credential          = $DomainCreds
			SchemaVersion       = 15332
            OrganizationVersion = 16217
            DomainVersion       = 13237
            DependsOn           = '[xExchInstall]PrepAD'
		}
        

		## Install Exchange 2016 CU6
        xExchInstall InstallExchange
        {
            Path         = "$exchangeInstallerPath\setup.exe"
            Arguments    = "/Mode:Install /Role:Mailbox /OrganizationName:MCSC /TargetDir:F:\Exchange /IAcceptExchangeServerLicenseTerms"
            Credential   = $DomainCreds
			PsDscRunAsCredential = $DomainCreds
            DependsOn    = '[xExchWaitForADPrep]WaitPrepAD'
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