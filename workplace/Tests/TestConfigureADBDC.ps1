$creds = (Get-Credential -Message "Domain Admin user" -UserName "mcowen")

$configData =@{
    AllNodes = @(
        @{
            NodeName = "localhost"
            PSDscAllowDomainUser = $true
            #PsDscAllowPlainTextPassword = $true
            Thumbprint = Read-Host "Enter the thumbprint for the DSC extension cert"
            CertificateFile = "path to exported DSC extension cert (.cer file)"
         }
    );

}
# Save ConfigurationData in a file with .psd1 file extension

$paramHash = @{
    configurationData = $configData
    DomainName = "mgc.local"
    InstanceName = "adBDC"
    Admincreds = $creds
    
}

ConfigureBackupDC @paramHash -Verbose


Start-DscConfiguration -ComputerName localhost -Credential $creds -Path .\ConfigureBackupDC -Verbose -Wait -Force