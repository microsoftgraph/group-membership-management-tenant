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

resource factoryName_DestinationDatabase 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${factoryName}/DestinationDatabase'
  properties: {
    annotations: []
    type: 'SqlServer'
    typeProperties: {
      connectionString: 'Server=tcp:${sqlServerName}.database.windows.net,1433;Initial Catalog=DestinationDataBase;Persist Security Info=False;User ID=SQLDBAdmin;Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    }
  }
  dependsOn: [
    dataFactory
  ]
}

resource factoryName_SourceDatabase 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${factoryName}/SourceDatabase'
  properties: {
    annotations: []
    type: 'SqlServer'
    typeProperties: {
      connectionString: 'Server=tcp:${sqlServerName}.database.windows.net,1433;Initial Catalog=SourceDataBase;Persist Security Info=False;User ID=SQLDBAdmin;Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    }
  }
  dependsOn: [
    dataFactory
  ]
}

resource factoryName_NewPipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${factoryName}/NewPipeline'
  properties: {
    activities: [
      {
        name: 'Create Source Table A'
        type: 'Script'
        dependsOn: []
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        linkedServiceName: {
          referenceName: 'SourceDatabase'
          type: 'LinkedServiceReference'
        }
        typeProperties: {
          scripts: [
            {
              type: 'Query'
              text: {
                value: '@concat(\'\nIF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = \'\'SourceTableA\'\')\nBEGIN\n    CREATE TABLE SourceTableA (\n    EmployeeIdentification int NOT NULL PRIMARY KEY,\n    ManagerIdentification int,\n    Email varchar(255)\n);\nEND;\n\')'
                type: 'Expression'
              }
            }
          ]
          scriptBlockExecutionTimeout: '02:00:00'
        }
      }
      {
        name: 'Create Source Table B'
        type: 'Script'
        dependsOn: [
          {
            activity: 'Create Source Table A'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
        policy: {
          timeout: '0.12:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        userProperties: []
        linkedServiceName: {
          referenceName: 'SourceDatabase'
          type: 'LinkedServiceReference'
        }
        typeProperties: {
          scripts: [
            {
              type: 'Query'
              text: {
                value: '@concat(\'\nIF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = \'\'SourceTableB\'\')\nBEGIN\n    CREATE TABLE SourceTableB (\n    Id int NOT NULL PRIMARY KEY,\n    Profession varchar(255),\n    Level varchar(255),\n    Location varchar(255),\n    AzureObjectId varchar(255),\n    EmployeeIdentification int FOREIGN KEY REFERENCES SourceTableA(EmployeeIdentification)\n);\nEND;\n\')'
                type: 'Expression'
              }
            }
          ]
          scriptBlockExecutionTimeout: '02:00:00'
        }
      }
      {
        name: 'NewDataFlow'
        type: 'ExecuteDataFlow'
        dependsOn: [
          {
            activity: 'Create Source Table B'
            dependencyConditions: [
              'Succeeded'
            ]
          }
        ]
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
            referenceName: 'NewDataFlow'
            type: 'DataFlowReference'
            parameters: {}
            datasetParameters: {
              SourceTableA: {}
              SourceTableB: {}
              DestinationTable: {
                TableName: {
                  value: 'tbl@{replace(pipeline().RunId,\'-\',\'\')}'
                  type: 'Expression'
                }
              }
            }
            linkedServiceParameters: {}
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
    factoryName_SourceDatabase
    factoryName_NewDataFlow
  ]
}

resource factoryName_SourceTableA 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${factoryName}/SourceTableA'
  properties: {
    linkedServiceName: {
      referenceName: 'SourceDatabase'
      type: 'LinkedServiceReference'
    }
    annotations: []
    type: 'SqlServerTable'
    schema: [
      {
        name: 'EmployeeIdentification'
        type: 'int'
        precision: 10
      }
      {
        name: 'ManagerIdentification'
        type: 'int'
        precision: 10
      }
      {
        name: 'Email'
        type: 'varchar'
      }
    ]
    typeProperties: {
      schema: 'dbo'
      table: 'SourceTableA'
    }
  }
  dependsOn: [
    dataFactory
    factoryName_SourceDatabase
  ]
}

resource factoryName_SourceTableB 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${factoryName}/SourceTableB'
  properties: {
    linkedServiceName: {
      referenceName: 'SourceDatabase'
      type: 'LinkedServiceReference'
    }
    annotations: []
    type: 'SqlServerTable'
    schema: [
      {
        name: 'EmployeeIdentification'
        type: 'int'
        precision: 10
      }
      {
        name: 'ManagerIdentification'
        type: 'int'
        precision: 10
      }
      {
        name: 'Email'
        type: 'varchar'
      }
    ]
    typeProperties: {
      schema: 'dbo'
      table: 'SourceTableB'
    }
  }
  dependsOn: [
    dataFactory
    factoryName_SourceDatabase
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
    dataFactory
    factoryName_DestinationDatabase
  ]
}

resource factoryName_NewDataFlow 'Microsoft.DataFactory/factories/dataflows@2018-06-01' = {
  name: '${factoryName}/NewDataFlow'
  properties: {
    type: 'MappingDataFlow'
    typeProperties: {
      sources: [
        {
          dataset: {
            referenceName: 'SourceTableA'
            type: 'DatasetReference'
          }
          name: 'SourceTableA'
        }
        {
          dataset: {
            referenceName: 'SourceTableB'
            type: 'DatasetReference'
          }
          name: 'SourceTableB'
        }
      ]
      sinks: [
        {
          dataset: {
            referenceName: 'DestinationTable'
            type: 'DatasetReference'
          }
          name: 'DestinationTable'
        }
      ]
      transformations: [
        {
          name: 'Join'
        }
      ]
      scriptLines: [
        'source(output('
        '          EmployeeIdentification as integer,'
        '          ManagerIdentification as integer,'
        '          Email as string'
        '     ),'
        '     allowSchemaDrift: true,'
        '     validateSchema: false,'
        '     isolationLevel: \'READ_UNCOMMITTED\','
        '     format: \'table\') ~> SourceTableA'
        'source(output('
        '          Id as integer,'
        '          Profession as string,'
        '          Level as string,'
        '          Location as string,'
        '          AzureObjectId as string,'
        '          EmployeeIdentification as integer'
        '     ),'
        '     allowSchemaDrift: true,'
        '     validateSchema: false,'
        '     isolationLevel: \'READ_UNCOMMITTED\','
        '     format: \'table\') ~> SourceTableB'
        'SourceTableA, SourceTableB join(SourceTableA@EmployeeIdentification == SourceTableB@EmployeeIdentification,'
        '     joinType:\'left\','
        '     matchType:\'exact\','
        '     ignoreSpaces: false,'
        '     broadcast: \'auto\')~> Join'
        'Join sink(allowSchemaDrift: true,'
        '     validateSchema: false,'
        '     deletable:false,'
        '     insertable:true,'
        '     updateable:false,'
        '     upsertable:false,'
        '     format: \'table\','
        '     skipDuplicateMapInputs: true,'
        '     skipDuplicateMapOutputs: true,'
        '     mapColumn('
        '          EmployeeId = SourceTableA@EmployeeIdentification,'
        '          ManagerId = ManagerIdentification,'
        '          Email,'
        '          Profession,'
        '          Level,'
        '          Location,'
        '          AzureObjectId'
        '     ),'
        '     partitionBy(\'hash\', 1)) ~> DestinationTable'
      ]
    }
  }
  dependsOn: [
    dataFactory
    factoryName_SourceTableA
    factoryName_SourceTableB
    factoryName_DestinationTable
  ]
}

output systemAssignedIdentityId string = dataFactory.identity.principalId
