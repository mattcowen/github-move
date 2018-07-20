$workplacerg = 'mgc'

$paramHash = 
@{ 
    DomainName = "cowen.me"
	StorageSize = 10
    DnsServerIpAddress = "14.1.1.4"
    VMAdminCreds = (Get-Credential -Message "Domain Admin user" -UserName "azureuser")
    ExchangeLink = Read-Host 'What is your ISO url?'
}

# publish the configuration with resources
Publish-AzureRmVMDscConfiguration -ConfigurationPath ..\DSC\PrepareExchange.ps1 -ResourceGroupName "CowenRg" `
	-StorageAccountName "mgcdeployment" -ContainerName "dsctesting" -Force -Verbose

Set-AzureRmVMDscExtension -Name PrepareExchange -ArchiveBlobName PrepareExchange.ps1.zip -ArchiveStorageAccountName mgcdeployment -ArchiveContainerName dsctesting -ArchiveResourceGroupName CowenRg `
-ResourceGroupName $workplacerg -Version 2.21 -VMName exchange -ConfigurationArgument $paramHash -ConfigurationName PrepareExchange -Verbose
