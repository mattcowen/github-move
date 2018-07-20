#
# TestPrepareSharepoint_invoke.ps1
#
$paramHash = 
@{ 
    
    Ensure                   = "Present"
    DatabaseServer           = "sql"
    AdminContentDatabaseName = "SP_AdminContent"
    FarmConfigDatabaseName   = "SP_Config"
    Passphrase               = (Get-Credential -Message "Sharepoint Farm passphrase creds" -UserName "ignore")
    FarmAccount              = (Get-Credential -Message "Sharepoint Farm creds" -UserName "SpFarm")
    #PsDscRunAsCredential     = (Get-Credential -Message "Sharepoint Setup creds" -UserName "SpSetup")
	ServerRole               = "SingleServerFarm"
    RunCentralAdmin          = $true
}

Invoke-DscResource -Name SPFarm -Method Test -Property $paramHash -ModuleName SharePointDSC
Invoke-DscResource -Name SPFarm -Method Set -Property $paramHash -ModuleName SharePointDSC
Invoke-DscResource -Name SPFarm -Method Get -Property $paramHash -ModuleName SharePointDSC


#Import-Module "C:\Program Files\WindowsPowerShell\Modules\SharePointDSC\DSCResources\MSFT_SPFarm\MSFT_SPFarm.psm1"
#Set-TargetResource @paramHash
