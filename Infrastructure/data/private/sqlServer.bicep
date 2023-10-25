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

@description('Administrator user name')
param sqlAdminUserName string

@secure()
@description('Administrator password')
param sqlAdminPassword string

@description('Administrators Azure AD Group Object Id')
param sqlAdministratorsGroupId string

@description('Administrators Azure AD Group Name')
param sqlAdministratorsGroupName string

var dataKeyVaultName = '${solutionAbbreviation}-data-${environmentAbbreviation}'
var sqlServerName = '${solutionAbbreviation}-data-${environmentAbbreviation}-private'
var logAnalyticsName = '${solutionAbbreviation}-data-${environmentAbbreviation}'

resource sqlServer 'Microsoft.Sql/servers@2022-11-01-preview' = {
  name: sqlServerName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: sqlAdminUserName
    administratorLoginPassword: sqlAdminPassword
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: sqlAdministratorsGroupName
      sid: sqlAdministratorsGroupId
      tenantId: tenantId
    }
  }

  resource sqlServerFirewall 'firewallRules@2022-11-01-preview' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }

  resource masterDataBase 'databases@2022-11-01-preview' = {
    location: location
    name: 'master'
    properties: {}
  }

  resource auditingSettings 'auditingSettings@2022-11-01-preview' = {
    name: 'default'
    properties: {
      state: 'Enabled'
      isAzureMonitorTargetEnabled: true
    }
  }
}

resource sqlSourceDataBase 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name: 'SourceDataBase'
  parent: sqlServer
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    family: ''
    capacity: 0
  }
}

resource sqlDestinationDataBase 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name: 'DestinationDataBase'
  parent: sqlServer
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    family: ''
    capacity: 0
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsName
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: sqlServer::masterDataBase
  name: 'diagnosticSettings'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
  dependsOn: [
    sqlServer
  ]
}

module secureKeyvaultSecrets 'keyVaultSecretsSecure.bicep' = {
  name: 'secureKeyvaultSecrets'
  params: {
    keyVaultName: dataKeyVaultName
    keyVaultSecrets: {
      secrets: [
        {
          name: 'sqlServerAdminUserName'
          value: sqlAdminUserName
        }
        {
          name: 'sqlServerAdminPassword'
          value: sqlAdminPassword
        }
      ]
    }
  }
}
