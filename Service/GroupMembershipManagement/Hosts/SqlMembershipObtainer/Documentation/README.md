# SqlMembershipObtainer Setup (Post-Deployment Tasks)

* Add <b>'Data Factory Contributor'</b> role to your `GMM SqlMembership - <EnvironmentAbbreviation>` application in the `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>` data factory resource.

## Grant Azure Data Factory access to SQL Server Database

Azure Data Factory needs access to the SQL Server DB where user data is stored.

Once your Azure Data Factory (`<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-adf`) has been created we need to grant it access to the SQL Server DB.

1. Connect to your SQL Server Database using Sql Server Management Studio (SSMS) or Azure Data Studio
- Server name : `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-destination.database.windows.net`
- User name: Use your @microsoft account.
- Authentication: Azure Active Directory - Universal with MFA
- Database name: `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-destination`

2. Run these SQL commands
- This script needs to run only once.
- Make sure you are connected to database: `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-destination`.

```
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-adf')
BEGIN
 CREATE USER [<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-adf] FROM EXTERNAL PROVIDER;
 ALTER ROLE db_ddladmin ADD MEMBER [<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-adf];
 ALTER ROLE db_datareader ADD MEMBER [<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-adf];
 ALTER ROLE db_datawriter ADD MEMBER [<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-adf];
END
```

Verify it ran successfully by running:
```
SELECT * FROM sys.database_principals WHERE name = N'<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-adf'
```
You should see one record for your ADF resource.

## Grant SqlMembershipObtainer function access to SQL Server Database

SqlMembershipObtainer needs access to the SQL Server DB where user data is stored.

Once your Function App (`<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-SqlMembershipObtainer`) has been created we need to grant it access to the SQL Server DB.

1. Connect to your SQL Server Database using Sql Server Management Studio (SSMS) or Azure Data Studio.
- Server name : `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>.database.windows.net`
- User name: Use your @microsoft account.
- Authentication: Azure Active Directory - Universal with MFA
- Database name: `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-destination`

2. Run these SQL commands
- This script needs to run only once.
- Make sure you are connected to database: `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-destination`.

```
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-SqlMembershipObtainer')
BEGIN
 CREATE USER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-SqlMembershipObtainer] FROM EXTERNAL PROVIDER;
 ALTER ROLE db_datareader ADD MEMBER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-SqlMembershipObtainer];
END
```

Verify it ran successfully by running:
```
SELECT * FROM sys.database_principals WHERE name = N'<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-SqlMembershipObtainer'
```
You should see one record for your function.

## HR driven sync setup

After completing the deployment, you should observe the following resources necessary for HR-driven syncs:

- `<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-SqlMembershipObtainer`
- `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-destination`
- `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-adf`

To enable HR-driven syncs, ensure that `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-destination` is populated with users from your tenant.

### HR driven sync demo setup

Below is an example of how GMM populates users in `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-destination`. Please note that this example uses a demo tenant. For the production environment, users should be within the tenant where your resources are deployed.

1. Create the demo tenant by following the [documentation](https://github.com/microsoftgraph/group-membership-management/blob/main/Documentation/CreateDemoTenant/CreateDemoTenant.md).
2. Create users in your demo tenant by running [this](https://github.com/microsoftgraph/group-membership-management/tree/main/Service/GroupMembershipManagement/Hosts/Console/DemoUserSetup) console app. By default, the console will create `10` users in your demo tenant. You can update this configurable value to add more users.
3. After running the console app, you should see users created within your demo tenant.
4. Within the console app's folder, locate the newly created `output` folder. This folder will contain two files: `memberids.csv` and `memberHRData.csv`. These files contain the ids of the users created and randomly generated HR data for each of these users respectively. We will use these files and Azure Data Factory to create a demo destination table. The purpose of doing this is to simulate the need to pull data from different sources to create the destination table and to showcase Azure Data Factory as a solution to this problem.

    Here are the columns in `memberids.csv`:

    - EmployeeIdentificationNumber
    - ManagerIdentificationNumber
    - AzureObjectId

    Here are the columns in `memberHRData.csv`:

    - EmployeeIdentificationNumber
    - Position
    - Level
    - Country
    - Email

    *Please note that `EmployeeIdentificationNumber`, `ManagerIdentificationNumber`, `AzureObjectId` are required columns within the source file to onboard a job successfully. The names of `EmployeeIdentificationNumber` and `ManagerIdentificationNumber` can be different. The names will be renamed to `EmployeeId` and `ManagerId` respectively in the destination table.*

5. Locate the `<SolutionAbbreviation><EnvironmentAbbreviation>adf` storage account in your `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>` resource group.
6. Within the storage account, locate the `csvcontainer` container and upload the `memberids.csv` and `memberHRData.csv` files to it. Azure Data Factory will access these files from this location.
7. Go to the `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-adf` Data factory (V2) resource within your `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>` resource group and launch the Azure Data Factory Studio.
8. Once in the Azure Data Factory Studio, go to `Author` -> `Pipelines` -> `PopulateDestinationPipeline` -> `Add trigger` -> `Trigger now` to trigger the pipeline. This pipeline will join the two csv files and create a SQL table with the result.
9. Once the pipeline run is complete, you should see a destination table created within the `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-destination` database. The name of the destination table will match the ADF pipeline Run ID.
10. Here are the columns in the destination table with the name `tbl<ADF-Pipeline-Run-Id>`:

- AzureObjectId
- EmployeeId
- ManagerId
- Country
- Position
- Level
- Email


Now you are ready to onboard a group!

Run [this script](/Scripts/New-GmmGroupMembershipSyncJob.ps1) to add a job to the jobs database.

Here are some examples of queries:

```json
[{"type":"SqlMembership","source":{"filter":"(Country = ''''United States'''')"}}]
[{"type":"SqlMembership","source":{"filter":"(Level > 2)"}}]
```

---