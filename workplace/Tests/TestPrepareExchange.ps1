$workplacerg = 'workplace'

$paramHash = 
@{ 
    DomainName = "cowen.me"
	StorageSize = 10
    DnsServerIpAddress = "10.14.1.4"
    VMAdminCreds = (Get-Credential -Message "Domain Admin user" -UserName "azureuser")
    ExchangeLink = 'https://download.microsoft.com/download/B/C/9/BC9C77DA-97D9-43D8-A3F8-50D8AF89E3FA/ExchangeServer2016-x64-cu10.iso'
}

# publish the configuration with resources
Publish-AzureRmVMDscConfiguration -ConfigurationPath ..\DSC\PrepareExchange.ps1 -ResourceGroupName "CowenRg" `
	-StorageAccountName "mgcdeployment" -ContainerName "dsctesting" -Force -Verbose

Set-AzureRmVMDscExtension -Name PrepareExchange -ArchiveBlobName PrepareExchange.ps1.zip -ArchiveStorageAccountName mgcdeployment -ArchiveContainerName dsctesting -ArchiveResourceGroupName CowenRg `
-ResourceGroupName $workplacerg -Version 2.76 -VMName exchange -ConfigurationArgument $paramHash -ConfigurationName PrepareExchange -Verbose
