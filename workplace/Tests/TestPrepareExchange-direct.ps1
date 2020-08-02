$creds = (Get-Credential -Message "Domain Admin user" -UserName "mcowen")

$configData =@{
    AllNodes = @(
        @{
            NodeName = "localhost";
			PSDscAllowDomainUser = $true;
			RebootNodeIfNeeded = $true;
			ActionAfterReboot = "ContinueConfiguration";
            #PsDscAllowPlainTextPassword = $true
            Thumbprint = Read-Host "What is the thumbprint of the DSC extension cert on the VM?"
            CertificateFile = "C:\cert.cer"
         }
    );

}


$paramHash = @{
    configurationData = $configData
    DomainName = "cowen.me"
    StorageSize = "10"
    VMAdminCreds = $creds
    
}

PrepareExchange @paramHash -Verbose

Start-DscConfiguration -ComputerName localhost -Credential $creds -Path .\PrepareExchange -Verbose -Wait -Force