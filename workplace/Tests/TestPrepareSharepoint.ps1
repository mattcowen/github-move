$workplacerg = 'workplace'

$paramHash = 
@{ 
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
	ProductKey = 'x'
	SPDLLink = 'x'
}

# publish the configuration with resources"
Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSC\PrepareSharePoint.ps1" -ResourceGroupName "CowenRg" `
 	-StorageAccountName "mgcdeployment" -ContainerName "dsctesting" -Force -Verbose


Set-AzureRmVMDscExtension -Name PrepareSharepoint -ArchiveBlobName PrepareSharePoint.ps1.zip -ArchiveStorageAccountName mgcdeployment `
    -ArchiveContainerName dsctesting -ArchiveResourceGroupName 'CowenRg' -ResourceGroupName $workplacerg -Version 2.76 -AutoUpdate -VMName sharePoint `
	-ConfigurationArgument $paramHash -ConfigurationName PrepareSharepoint
