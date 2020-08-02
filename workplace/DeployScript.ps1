#
# DeployScript.ps1
#
.\Deploy-AzureResourceGroup.ps1 -StorageAccountName 'mgcdeployment' -ResourceGroupName 'workplace' `
	-ResourceGroupLocation 'northeurope' -TemplateFile '.\azuredeploy.json' `
	-TemplateParametersFile '.\azuredeploy.parameters2.json' -ArtifactStagingDirectory '.' -DSCSourceFolder '.\DSC' -UploadArtifacts