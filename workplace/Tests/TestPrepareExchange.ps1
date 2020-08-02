$workplacerg = 'workplace'

$paramHash = 
@{ 
    DomainName = "cowen.me"
	StorageSize = 10
    DnsServerIpAddress = "10.14.1.4"
    VMAdminCreds = (Get-Credential -Message "Domain Admin user" -UserName "mcowen")
    ExchangeLink = 'https://download.microsoft.com/download/5/9/6/59681DAE-AB62-4854-8DEC-CA25FFEFE3B3/ExchangeServer2016-x64-cu13.iso'
}

# publish the configuration with resources
Publish-AzVMDscConfiguration -ConfigurationPath ..\DSC\PrepareExchange.ps1 -ResourceGroupName "CowenRg" `
	-StorageAccountName "mgcdeployment" -ContainerName "dsctesting" -Force -Verbose

Set-AzVMDscExtension -Name PrepareExchange -ArchiveBlobName PrepareExchange.ps1.zip -ArchiveStorageAccountName mgcdeployment -ArchiveContainerName dsctesting -ArchiveResourceGroupName CowenRg - `
-ResourceGroupName $workplacerg -Version 2.76 -VMName exchange -ConfigurationArgument $paramHash -ConfigurationName PrepareExchange -Verbose
