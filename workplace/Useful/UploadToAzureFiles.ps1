#Install-Module Azure.storage

$context = New-AzureStorageContext -StorageAccountName "mgcdeployment" -StorageAccountKey "enter the storage key"

Set-AzureStorageBlobContent -Container "enter container name" -File "path to .iso" -Context $context

