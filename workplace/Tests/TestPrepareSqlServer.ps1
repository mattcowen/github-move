# find the VM
$VM = Get-AzureRmVm -ResourceGroupName "enterprise" -Name "sql"

$paramHash = 
@{ 
    DomainName = "cowen.me"
    AdminCreds = (Get-Credential -Message "Domain Admin user" -UserName "azureuser")
	SQLServicecreds = (Get-Credential -Message "Sql service creds" -UserName "sqlservice")
    SharePointSetupUserAccountcreds = (Get-Credential -Message "Sharepoint Setup creds" -UserName "SpSetup")
    sqlInstallationISOUri = Read-Host 'What is your ISO url?'

}
# publish the configuration with resources"
Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSC\PrepareSqlServer.ps1" -ResourceGroupName "CowenRg" `
	-StorageAccountName "mgcdeployment" -ContainerName "dsctesting" -Force -Verbose

Set-AzureRmVMDscExtension -Name PrepareSqlServer -ArchiveBlobName PrepareSqlServer.ps1.zip -ArchiveStorageAccountName mgcdeployment -ArchiveContainerName dsctesting -ArchiveResourceGroupName CowenRg `
-ResourceGroupName enterprise -Version 2.21 -VMName sql -ConfigurationArgument $paramHash -ConfigurationName PrepareSqlServer

