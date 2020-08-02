$paramHash = 
@{ 
    DomainName = "cowen.me"
    AdminCreds = (Get-Credential -Message "Domain Admin user" -UserName "mcowen")
	SQLServicecreds = (Get-Credential -Message "Sql service creds" -UserName "sqlservice")
    SharePointSetupUserAccountcreds = (Get-Credential -Message "Sharepoint Setup creds" -UserName "SpSetup")
    sqlInstallationISOUri = 'xx'

}
# publish the configuration with resources"
Publish-AzureRmVMDscConfiguration -ConfigurationPath "..\DSC\PrepareSqlServer.ps1" -ResourceGroupName "CowenRg" `
	-StorageAccountName "mgcdeployment" -ContainerName "dsctesting" -Force -Verbose

Set-AzureRmVMDscExtension -Name PrepareSqlServer -ArchiveBlobName PrepareSqlServer.ps1.zip -ArchiveStorageAccountName mgcdeployment `
    -ArchiveContainerName dsctesting -ArchiveResourceGroupName CowenRg -AutoUpdate `
    -ResourceGroupName workplace -Version 2.76 -VMName sql -ConfigurationArgument $paramHash -ConfigurationName PrepareSqlServer

