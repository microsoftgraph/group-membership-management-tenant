@description('Name of Azure Data Factory')
param factoryName string

@description('Enter an abbreviation for the environment')
param environmentAbbreviation string

@description('Location for Azure Data Factory account')
param location string

@description('Name of SQL Server')
param sqlServerName string

@secure()
param sqlAdminPassword string

@description('Connection string of adf storage account')
@secure()
param storageAccountConnectionString string

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: factoryName
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    globalParameters: {
      environment: {
        type: 'String'
        value: environmentAbbreviation
      }
    }
  }
  location: location
}

resource factoryName_AzureBlobStorage 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${factoryName}/AzureBlobStorage'
  properties: {
    annotations: []
    type: 'AzureBlobStorage'
    typeProperties: {
      connectionString: storageAccountConnectionString
    }
  }
  dependsOn: [
    dataFactory
  ]
}

resource factoryName_DestinationDatabase 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${factoryName}/DestinationDatabase'
  properties: {
    annotations: []
    type: 'SqlServer'
    typeProperties: {
      connectionString: 'Server=tcp:${sqlServerName}.database.windows.net,1433;Initial Catalog=DestinationDatabase;Persist Security Info=False;User ID=SQLDBAdmin;Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    }
  }
  dependsOn: [
    dataFactory
  ]
}

resource factoryName_PopulateDestinationPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${factoryName}/PopulateDestinationPipeline'
  properties: {
    activities: [
      {
        name: 'Data flow1'
        type: 'ExecuteDataFlow'
        dependsOn: []
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        typeProperties: {
          dataFlow: {
            referenceName: 'PopulateDestinationDataFlow'
            type: 'DataFlowReference'
            parameters: {}
            datasetParameters: {
              memberids: {}
              memberHRData: {}
              sink: {
                TableName: {
                  value: 'tbl@{replace(pipeline().RunId,\'-\',\'\')}'
                  type: 'Expression'
                }
              }
            }
          }
          staging: {}
          compute: {
            coreCount: 8
            computeType: 'General'
          }
          traceLevel: 'Fine'
        }
      }
    ]
    policy: {
      elapsedTimeMetric: {}
    }
    annotations: []
  }
  dependsOn: [
    dataFactory
    factoryName_PopulateDestinationDataFlow
  ]
}

resource factoryName_DestinationTable 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${factoryName}/DestinationTable'
  properties: {
    linkedServiceName: {
      referenceName: 'DestinationDatabase'
      type: 'LinkedServiceReference'
    }
    parameters: {
      TableName: {
        type: 'String'
      }
    }
    annotations: []
    type: 'SqlServerTable'
    schema: []
    typeProperties: {
      table: {
        value: '@dataset().TableName'
        type: 'Expression'
      }
    }
  }
  dependsOn: [
    factoryName_DestinationDatabase
  ]
}

resource factoryName_memberHRDatainput 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${factoryName}/memberHRDatainput'
  properties: {
    linkedServiceName: {
      referenceName: 'AzureBlobStorage'
      type: 'LinkedServiceReference'
    }
    annotations: []
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'AzureBlobStorageLocation'
        fileName: 'memberHRData.csv'
        container: 'csvcontainer'
      }
      columnDelimiter: ','
      escapeChar: '\\'
      firstRowAsHeader: true
      quoteChar: '"'
    }
    schema: [
      {
        name: 'EmployeeId'
        type: 'String'
      }
      {
        name: 'Position'
        type: 'String'
      }
      {
        name: 'Level'
        type: 'String'
      }
      {
        name: 'Country'
        type: 'String'
      }
      {
        name: 'Email'
        type: 'String'
      }
    ]
  }
  dependsOn: [
    dataFactory
    factoryName_AzureBlobStorage
  ]
}

resource factoryName_memberidsinput 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${factoryName}/memberidsinput'
  properties: {
    linkedServiceName: {
      referenceName: 'AzureBlobStorage'
      type: 'LinkedServiceReference'
    }
    annotations: []
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'AzureBlobStorageLocation'
        fileName: 'memberids.csv'
        container: 'csvcontainer'
      }
      columnDelimiter: ','
      escapeChar: '\\'
      firstRowAsHeader: true
      quoteChar: '"'
    }
    schema: [
      {
        name: 'EmployeeId'
        type: 'String'
      }
      {
        name: 'ManagerId'
        type: 'String'
      }
      {
        name: 'AzureObjectId'
        type: 'String'
      }
    ]
  }
  dependsOn: [
    dataFactory
    factoryName_AzureBlobStorage
  ]
}

resource factoryName_PopulateDestinationDataFlow 'Microsoft.DataFactory/factories/dataflows@2018-06-01' = {
  name: '${factoryName}/PopulateDestinationDataFlow'
  properties: {
    type: 'MappingDataFlow'
    typeProperties: {
      sources: [
        {
          dataset: {
            referenceName: 'memberidsinput'
            type: 'DatasetReference'
          }
          name: 'memberids'
        }
        {
          dataset: {
            referenceName: 'memberHRDatainput'
            type: 'DatasetReference'
          }
          name: 'memberHRData'
        }
      ]
      sinks: [
        {
          dataset: {
            referenceName: 'DestinationTable'
            type: 'DatasetReference'
          }
          name: 'sink'
        }
      ]
      transformations: [
        {
          name: 'join'
        }
      ]
      scriptLines: [
        'source(output('
        '          EmployeeId as string,'
        '          ManagerId as string,'
        '          AzureObjectId as string'
        '     ),'
        '     allowSchemaDrift: true,'
        '     validateSchema: false,'
        '     ignoreNoFilesFound: false) ~> memberids'
        'source(output('
        '          EmployeeId as string,'
        '          Position as string,'
        '          Level as string,'
        '          Country as string,'
        '          Email as string'
        '     ),'
        '     allowSchemaDrift: true,'
        '     validateSchema: false,'
        '     ignoreNoFilesFound: false) ~> memberHRData'
        'memberids, memberHRData join(memberids@EmployeeId == memberHRData@EmployeeId,'
        '     joinType:\'inner\','
        '     matchType:\'exact\','
        '     ignoreSpaces: false,'
        '     broadcast: \'auto\')~> join'
        'join sink(allowSchemaDrift: true,'
        '     validateSchema: false,'
        '     input('
        '          ObjectId as string,'
        '          EmployeeId as integer,'
        '          ManagerId as integer,'
        '          Country as string,'
        '          Position as string,'
        '          Level as integer,'
        '          Email as string'
        '     ),'
        '     deletable:false,'
        '     insertable:true,'
        '     updateable:false,'
        '     upsertable:false,'
        '     format: \'table\','
        '     skipDuplicateMapInputs: true,'
        '     skipDuplicateMapOutputs: true,'
        '     errorHandlingOption: \'stopOnFirstError\','
        '     mapColumn('
        '          ObjectId = AzureObjectId,'
        '          EmployeeId = memberids@EmployeeId,'
        '          ManagerId,'
        '          Country,'
        '          Position,'
        '          Level,'
        '          Email'
        '     )) ~> sink'
      ]
    }
  }
  dependsOn: [
    factoryName_memberHRDatainput
    factoryName_DestinationTable
    factoryName_memberidsinput
  ]
}

output systemAssignedIdentityId string = dataFactory.identity.principalId
