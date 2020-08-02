#
# Run the following to download and install modules on your dev machine
#
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Find-Module -Name xActiveDirectory -Repository PSGallery | Install-Module -SkipPublisherCheck -Scope AllUsers
Find-Module -Name xPendingReboot -Repository PSGallery | Install-Module -SkipPublisherCheck -Scope AllUsers
Find-Module -Name NetworkingDsc -Repository PSGallery | Install-Module -SkipPublisherCheck -Scope AllUsers
Find-Module -Name StorageDsc -Repository PSGallery | Install-Module -SkipPublisherCheck -Scope AllUsers
Find-Module -Name ComputerManagementDsc -Repository PSGallery | Install-Module -SkipPublisherCheck -Scope AllUsers
Find-Module -Name FileDownloadDSC -Repository PSGallery | Install-Module -SkipPublisherCheck -Scope AllUsers
Find-Module -Name xExchange -Repository PSGallery | Install-Module -SkipPublisherCheck -Scope AllUsers
Find-Module -Name SqlServerDsc -Repository PSGallery | Install-Module -SkipPublisherCheck -Scope AllUsers
Find-Module -Name SharePointDSC -Repository PSGallery | Install-Module -SkipPublisherCheck -Scope AllUsers
Find-Module -Name xDownloadISO -Repository PSGallery | Install-Module -SkipPublisherCheck -Scope AllUsers
Set-PSRepository -Name PSGallery -InstallationPolicy Untrusted