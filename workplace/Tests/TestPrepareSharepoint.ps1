$workplacerg = 'mgc'

$paramHash = 
@{ 
    DomainName = "cowen.me"
	primaryAdIpAddress = "14.1.1.4"
    AdminCreds = (Get-Credential -Message "Domain Admin user" -UserName "azureuser")
	SharePointSetupUserAccountcreds = (Get-Credential -Message "Sharepoint Setup creds" -UserName "SpSetup")
	SharePointFarmAccountcreds = (Get-Credential -Message "Sharepoint Farm creds" -UserName "SpFarm")
	Passphrase = (Get-Credential -Message "Sharepoint Farm passphrase creds" -UserName "ignore")
	DatabaseName = "SP_Content"
	DatabaseServer = "sql"
	InstallSourceDrive = "F:"
	InstallSourceFolderName = "installer" # ignored atm
	ProductKey = Read-Host 'What is your SharePoint product key?'
	SPDLLink = Read-Host 'What is your ISO url?'
}

# publish the configuration with resources"
Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSC\PrepareSharePoint.ps1" -ResourceGroupName "CowenRg" `
 	-StorageAccountName "mgcdeployment" -ContainerName "dsctesting" -Force -Verbose


Set-AzureRmVMDscExtension -Name PrepareSharepoint -ArchiveBlobName PrepareSharePoint.ps1.zip -ArchiveStorageAccountName mgcdeployment `
    -ArchiveContainerName dsctesting -ArchiveResourceGroupName 'CowenRg' -ResourceGroupName $workplacerg -Version 2.21 -VMName sharePoint `
	-ConfigurationArgument $paramHash -ConfigurationName PrepareSharepoint
