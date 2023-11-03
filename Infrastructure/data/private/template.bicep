@minLength(2)
@maxLength(3)
@description('Enter an abbreviation for the solution.')
param solutionAbbreviation string

@minLength(2)
@maxLength(6)
@description('Enter an abbreviation for the environment.')
param environmentAbbreviation string

@description('Resource location.')
param location string

@description('Tenant Id.')
param tenantId string

@description('Name of storage account that stores adf data')
param storageAccountName string = '${solutionAbbreviation}${environmentAbbreviation}adf'

@description('Enter storage account sku.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageAccountSku string = 'Standard_LRS'

@description('Name of blob container')
param storageAccountContainerName string = 'csvcontainer'

@description('Name of SQL Server')
param sqlServerName string = '${solutionAbbreviation}-data-${environmentAbbreviation}-destination'

@description('Name of Azure Data Factory')
param azureDataFactoryName string = '${solutionAbbreviation}-data-${environmentAbbreviation}-adf'

@description('Administrator user name')
param sqlAdminUserName string = 'SQLDBAdmin'

@secure()
@description('Administrator password')
param sqlAdminPassword string = 'ADMN${toLower(newGuid())}!$#'

@description('Administrators Azure AD Group Object Id')
param sqlAdministratorsGroupId string

@description('Administrators Azure AD Group Name')
param sqlAdministratorsGroupName string

var dataKeyVaultName = '${solutionAbbreviation}-data-${environmentAbbreviation}'

resource dataKeyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: dataKeyVaultName
  scope: resourceGroup()
}

module sqlServer 'sqlServer.bicep' =  {
  name: 'sqlServerTemplate'
  params: {
    environmentAbbreviation: environmentAbbreviation
    location: location
    solutionAbbreviation: solutionAbbreviation    
    keyVaultName: dataKeyVaultName
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlServerName
    sqlAdminUserName:  sqlAdminUserName
    sqlAdminPassword: sqlAdminPassword
    sqlAdministratorsGroupId: sqlAdministratorsGroupId
    sqlAdministratorsGroupName: sqlAdministratorsGroupName
    tenantId: tenantId
  }
}

module storageAccountTemplate 'storageAccount.bicep' = {
  name: 'storageAccountTemplate'
  params: {
    storageAccountName: storageAccountName
    containerName: storageAccountContainerName
    sku: storageAccountSku
    keyVaultName: dataKeyVaultName
    location: location
  }
}

module azureDataFactoryTemplate 'azureDataFactory.bicep' = {
  name: 'azureDataFactoryTemplate'
  params: {
    factoryName: azureDataFactoryName
    environmentAbbreviation: environmentAbbreviation
    location: location
    sqlAdminPassword: sqlAdminPassword
    sqlServerName: sqlServerName
    storageAccountConnectionString: dataKeyVault.getSecret('storageAccountConnectionString')
  }
  dependsOn: [
    sqlServer
  ]
}

module keyVaultPoliciesTemplate 'keyVaultAccessPolicies.bicep' = {
  name: 'keyVaultPoliciesTemplate-${solutionAbbreviation}'
  params: {
    name: dataKeyVaultName
    policies: [
      {
        objectId: azureDataFactoryTemplate.outputs.systemAssignedIdentityId
        secrets: [
          'list'
          'get'
        ]
      }
    ]
    tenantId: tenantId
  }
  dependsOn: [
    azureDataFactoryTemplate
  ]
}
