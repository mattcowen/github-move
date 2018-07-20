# workplace

This project brings together several Azure Quickstart Templates to demonstrate deploying and configuring domain controllers, SQL Server, SharePoint Server and Exchange Server to Azure.

To be able to deploy this yourself you need to do the following:

1. Install the DSC modules locally by running the /useful/InstallModulesLocally.ps1 script.
2. Update parameters to link to your Key Vault secrets.
3. Update the DNS name for SharePoint
4. Update the storage account names so they are globally unique

If the DSC fails, you can use the test scripts to trigger DSC manually via the DSC extension or see the examples of running DSC directly on a VM.
