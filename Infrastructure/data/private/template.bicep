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

@description('Name of SQL Server')
param sqlServerName string = '${solutionAbbreviation}-data-${environmentAbbreviation}-private'

@description('Name of Azure Data Factory')
param azureDataFactoryName string = '${solutionAbbreviation}-data-${environmentAbbreviation}-adf'

@description('User(s) and/or Group(s) AAD Object Ids to which access to the keyvault will be granted to.')
param keyVaultReaders array

@description('Administrator user name')
param sqlAdminUserName string = 'SQLDBAdmin'

@secure()
@description('Administrator password')
param sqlAdminPassword string = 'ADMN${toLower(newGuid())}!$#'

@description('Administrators Azure AD Group Object Id')
param sqlAdministratorsGroupId string

@description('Administrators Azure AD Group Name')
param sqlAdministratorsGroupName string

module sqlServer 'sqlServer.bicep' =  {
  name: 'sqlServerTemplate'
  params: {
    environmentAbbreviation: environmentAbbreviation
    location: location
    solutionAbbreviation: solutionAbbreviation    
    sqlAdminUserName:  sqlAdminUserName
    sqlAdminPassword: sqlAdminPassword
    sqlAdministratorsGroupId: sqlAdministratorsGroupId
    sqlAdministratorsGroupName: sqlAdministratorsGroupName
    tenantId: tenantId
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
  }
  dependsOn: [
    sqlServer
  ]
}
