# workplace

This project brings together several Azure Quickstart Templates to demonstrate deploying and configuring domain controllers, SQL Server, SharePoint Server and Exchange Server to Azure.

To be able to deploy this yourself you need to do the following:

1. Install the DSC modules locally by running the /useful/InstallModulesLocally.ps1 script.
2. Update parameters to link to your Key Vault secrets.
3. Update the DNS name for SharePoint
4. Update the storage account names so they are globally unique

If the DSC fails, you can use the test scripts to trigger DSC manually via the DSC extension or see the examples of running DSC directly on a VM.

Known issues

1. SharePoint deployment has not been tested since upgrading SharePointDsc module to the latest
2. Exchange deployment may give false failure message due to xExchInstall resource and /PrepareAD and /PrepareSchema setup tasks not recognising a successful completion. This has been recognised by the ExchangeDsc dev tea and I will update once I have a workaround.
3. Ensure you use a routable domain name if you plan on using AD Connect to sync users to Azure AD.
