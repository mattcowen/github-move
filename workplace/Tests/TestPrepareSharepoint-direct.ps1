
$configData =@{
    AllNodes = @(
        @{
            NodeName = "localhost";
			PSDscAllowDomainUser = $true;
			RebootNodeIfNeeded = $true;
			ActionAfterReboot = "ContinueConfiguration";
            Thumbprint = Read-Host "Enter the thumbprint for the DSC extension cert"
            CertificateFile = "path to exported DSC extension cert (.cer)"
         }
    );

}


$paramHash = 
@{ 
    configurationData = $configData
    DomainName = "cowen.me"
	primaryAdIpAddress = "10.14.1.4"
    AdminCreds = (Get-Credential -Message "Domain Admin user" -UserName "azureuser")
	SharePointSetupUserAccountcreds = (Get-Credential -Message "Sharepoint Setup creds" -UserName "SpSetup")
	SharePointFarmAccountcreds = (Get-Credential -Message "Sharepoint Farm creds" -UserName "SpFarm")
	Passphrase = (Get-Credential -Message "Sharepoint Farm passphrase creds" -UserName "ignore")
	DatabaseName = "SP_Content"
	DatabaseServer = "sql"
	InstallSourceDrive = "F:"
	InstallSourceFolderName = "installer" # ignored atm
	ProductKey = Read-Host 'What is your SharePoint product key?'
	SPDLLink = Read-Host "What is the URI for your SharePoint ISO?"


}

PrepareSharepoint @paramHash -Verbose

$creds = (Get-Credential -Message "Domain Admin user")

Start-DscConfiguration -ComputerName localhost -Credential $creds -Path .\PrepareSharepoint -Verbose -Wait -Force