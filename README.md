# Group Membership Management (GMM) tool Overview

This tool enables admins to sync the membership of Microsoft 365 Groups using one or more security groups that may or may not be nested, and keep the memberships up to date by syncing with the source groups at regular intervals.

Please read before proceeding:

-   The tool is based on .Net, Azure Functions, and Azure Table Storage. All of these are requirements and must be deployed by the customer onto their Azure subscription.
-   The tool interacts with Microsoft cloud using Graph APIs as a data source. The app needs to be onboarded and granted permissions by the customer tenant admin.
-   The tool allows the user to specify: source security groups, the destination Microsoft 365 Group, frequency of syncs, and start date of sync.

<br>

# Table of Contents

1. [GMM Setup Overview](#gmm-setup-overview)
    * [Setup prerequisites](#setup-prerequisites)
    * [Resource groups overview](#resource-groups-overview)
    * [Prereqs keyvault overview](#prereqs-keyvault-overview)
    * [ARM templates and parameter files overview](#arm-templates-and-parameter-files-overview)
    * [GMM environments](#gmm-environments)
2. [GMM Setup](#gmm-Setup)
    * [Create Azure Devops Repositories](#create-azure-devops-repositories)
    * [Create resource groups and the prereqs keyvault](#create-resource-groups-and-the-prereqs-keyvault)
    * [Create the Graph application and populate prereqs keyvault](#create-the-graph-application-and-populate-prereqs-keyvault)
    * [Create the WebAPI application and populate prereqs keyvault](#create-the-webapi-application-and-populate-prereqs-keyvault)
    * [Adding a new GMM environment](#adding-a-new-gmm-environment)
    * [Create a Service Connection](#create-a-service-connection)
    * [Set up email notifications](#set-up-email-notifications)
    * [Create an Azure DevOps environment](#create-an-azure-devops-environment)
    * [Create an Azure DevOps pipeline](#create-an-azure-devops-pipeline)
    * [Post-Deployment tasks](#post-deployment-tasks)
    * [(Optional) Set up a production environment(s)](#optional-set-up-a-production-environment)
3. [Using GMM](#using-gmm)
    * [Adding Graph application as an owner to GMM managed destination group](#adding-graph-application-as-an-owner-to-gmm-managed-destination-group)
    * [Creating synchronization jobs for source groups](#creating-synchronization-jobs-for-source-groups)
    * [Dry Run Settings](#dry-run-settings)
4. [Setting AzureMaintenance function](#setting-azuremaintenance-function)
5. [Setting GMM in a demo tenant](#setting-gmm-in-a-demo-tenant)
6. [Setting up GMM UI](#setting-up-gmm-ui)
7. [Steps to debug and troubleshoot a failing sync](#steps-to-debug-and-troubleshoot-a-failing-sync)
8. [Breaking changes](#breaking-changes)

<br>


# GMM Setup Overview

This section aims to provide the background information needed to understand the GMM setup process. If you would like to skip this section and start setting up GMM, please see [GMM Setup](#GMM-Setup).

## Setup prerequisites:

-   Azure Subscription - [Try Azure](https://azure.microsoft.com/en-us/free/).
-   Azure DevOps - [Try Azure DevOps Services](https://azure.microsoft.com/en-us/pricing/details/devops/azure-devops-services/)

    Note: to follow these steps you will need to sign in to [Azure Portal](https://portal.azure.com/) and [Azure DevOps Portal](https://dev.azure.com/.) with an account that has permissions to create new Azure resources.

-   Powershell Core v7.x [Download and install Windows PowerShell 7.x](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)

- [Visual Studio](https://visualstudio.microsoft.com/downloads/) or [Visual Studio Code](https://visualstudio.microsoft.com/downloads/)
- [.NET SDK Version 6](https://dotnet.microsoft.com/en-us/download/dotnet/6.0)

    Note: the .NET version targeted by GMM can be changed in the ` global.json` file.

    To find out what .NET SDK versions you currently have installed run this command from the command line:

        dotnet --list-sdks

## Resource groups overview

GMM logically separates the resources it uses into three [resource groups](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#what-is-a-resource-group):

-   prereqs
-   data
-   compute

Throughout this document we will use the following tokens as place holders:

- `<SolutionAbbreviation>` - This is a name prefix (2 to 3 characters long). The current default value is '`gmm`'. See the Notes section below for information on how to change this value.
- `<EnvironmentAbbreviation>` - This is the name of your environment (2 to 6 characters long). Each environment should have an unique value to avoid name collisions. See the Notes section below for more information.

When setting up GMM, you will need to provide the value for each one of these as they will be used to name the Azure resources. Please Avoid using the names on this document as they are already in use and some Azure resources are required to have a unique name across all tenants globally.

The naming convention for the resource groups and other resources is `<SolutionAbbreviation>`-`<ResourceGroupName>`-`<EnvironmentAbbreviation>`, i.e gmm-data-ua, gmm-data-prod, gmm-compute-prod.

### Notes:

Both `<SolutionAbbreviation>` and `<EnvironmentAbbreviation>` must only contain numbers and/or lowercase letters! Using capital letters in either will cause problems!

Currently,  the default value for `<SolutionAbbreviation>` is `gmm`. To change this default, update the `solutionAbbreviation` variable in the `vsts-cicd.yml` file of your `Private` repo.

The length restrictions for both `<SolutionAbbreviation>` and `<EnvironmentAbbreviation>` can be changed by updating their `minLength` and `maxLength` variables in the ARM templates (`template.bicep`).

We recommend trying to use unique `<SolutionAbbreviation>` and `<EnvironmentAbbreviation>` names, since some resources in Azure require to have unique names globally so it is possible to have name collisions.


## Prereqs keyvault overview

Each resource group will have a corresponding keyvault; The naming convention for the keyvault is the same as the resource groups.

Initially, we will use a script to create the `<SolutionAbbreviation>`-prereqs-`<EnvironmentAbbreviation>` keyvault. This keyvault needs to be populated before deploying the ARM templates, as these rely on it to deploy the resources needed for GMM.  This keyvault must be created under its corresponding resource group: `<SolutionAbbreviation>`-prereqs-`<EnvironmentAbbreviation>`.

These two keyvaults will be created by the ARM templates, so no action is needed for these two:

-   `<SolutionAbbreviation>`-data-`<EnvironmentAbbreviation>`
-   `<SolutionAbbreviation>`-compute-`<EnvironmentAbbreviation>`

## ARM templates and parameter files overview

GMM leverages infrastructure as code through the use of ARM templates. Most of the Azure resources needed by GMM are created by the ARM templates on the `Public` repository. We use parameter files to pass user specific information or settings to the ARM templates. ARM templates and parameter files can be found within the `Infrastructure` folders of the parent project and each of the functions apps:

    -   Documentation
    -   Infrastructure
        -   data
            -   parameters
    -   Scripts
    -   Service
        -   Hosts
            -   JobTrigger
                -   Infrastructure
                    -   data
                        -   parameters
                    -   compute
                        -   parameters
            -   ...
    -   yaml

## GMM environments

A `GMM environment` is the collection of resource groups, resources, and operating tenant that make a GMM instance.

The code is provided with a sample environment, `env`. The [vsts-cicd.yml](https://github.com/microsoftgraph/group-membership-management-tenant/blob/main/vsts-cicd.yml) `yaml/deploy-pipeline.yml` template and parameter files for the `env` environment are provided to serve as a guide to create new environments. This name must not be reused.

The steps in this document will setup a single environment i.e. prodv2, if you would like to setup other environments i.e. int and ua, you will need to go through these steps again replacing `<EnvironmentAbbreviation>` accordingly.


# GMM Setup

## Create Azure Devops Repositories

### IMPORTANT: Make sure you have access to Azure DevOps Pipelines & Repos

1. ### Sign in to [Azure DevOps](https://azure.microsoft.com/en-us/services/devops/)

2. ### Create a private project:

    -   You can create a new project by following these instructions: [Create a project in AzureDevOps](https://docs.microsoft.com/en-us/azure/devops/organizations/projects/create-project?view=azure-devops&tabs=preview-page)
    -   You can also use an existing project in your organization.

3. ### Create two new repositories

    - `Public` repository:
        - Your `Public` repo will mimic [group-membership-management ](https://github.com/microsoftgraph/group-membership-management) GitHub repository.
        - Create the `Public` repo based off this GitHub repo by following the [Manually Importing a Repo](https://docs.microsoft.com/en-us/azure/devops/repos/git/import-git-repository?view=azure-devops#manually-import-a-repo) documentation.
        - Keep the commit history of your `Public` repo in sync with this GitHub repo by running the following commands from your `Public` repo:

                git remote add upstream https://github.com/microsoftgraph/group-membership-management.git
                git fetch upstream
                git checkout upstream/main -b main
                git merge upstream/main
                git push --set-upstream origin main -f

    - `Private` repository:
        - Your `Private` repo will refer to your `Public` repo as a submodule.
        - Create your `Private` repo based off [this](https://github.com/microsoftgraph/group-membership-management-tenant) repo by following the [Manually Importing a Repo](https://docs.microsoft.com/en-us/azure/devops/repos/git/import-git-repository?view=azure-devops#manually-import-a-repo) documentation.
        - You should see `public` submodule within your `Private` repo.
        - Run the following commands in PowerShell to clone `Private` repo with the submodule:

                git clone <url-of-private-repo>
                ls # you should see public submodule
                cd \public
                ls # no contents within public submodule
                git submodule update --init --recursive
                ls # you should see contents within public submodule

        - Let’s say that a new commit is added to the main branch of your `Public` repository. To add that new commit to the submodule in the `Private` repository, run the following commands:

                git submodule update --remote --merge
                git add *
                git commit -m “updated public submodule”
                git push

    Note: Make sure that you set the default branch by going to Azure DevOps -> Repos -> Branches

## Create resource groups and the prereqs keyvault

See [Resource Groups](#resource-groups-overview) and [Prereqs Keyvault](#prereqs-keyvault-overview).

The following script is going to create the Azure resource groups and the prereqs keyvault required to set up GMM. We create these resource groups and keyvault in order for the ARM templates to be able to create additional resources and deploy the code.

From your `PowerShell Core 7.x` command prompt navigate to the Scripts folder of your `Public` repo and type these commands:

    1. . ./Set-Environment.ps1
    2. Set-Environment  -solutionAbbreviation "<solutionAbbreviation>" `
                        -environmentAbbreviation "<environmentAbbreviation>" `
                        -objectId "<objectId>" `
                        -resourceGroupLocation "<resourceGroupLocation>" `
                        -overwrite $true

Where:
* `<objectId>` - the Azure Object Id of the user, group or service principal to which access to the prereqs keyvault is going to be granted. To find your Object Id go to `Azure Portal -> AAD -> Search Tenant Search Bar`, look up your Microsoft email, and click on your profile. Your Object Id should be under the `Identity` section.
* `<resourceGroupLocation>` - the Azure location where the resources are going to be created. Please refer to [this](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/resource-location?tabs=azure-powershell) documentation to know the available resource locations.

<b>Note:</b> If you get an error stating "script is not digitally signed" when running any of the provided PowerShell scripts, try running this cmdlet and rerunning the script:

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

## Create the Graph application and populate prereqs keyvault

The following PowerShell script will create a new application, `<solutionAbbreviation>`-Graph-`<environmentAbbreviation>`,  that will allow GMM to access the Microsoft Graph API. It will also save these settings in the prereqs keyvault:

-   graphAppClientId
-   graphAppTenantId
-   graphAppClientSecret

Note that this script will create an new application and authentication will be done using a client id and client secret pair. If you prefer to use a certificate skip to the next section.

From your `PowerShell 7.x` command prompt navigate to the `Scripts` folder of your `Public` repo and run these commands:

    1. . ./Set-GraphCredentialsAzureADApplication.ps1
    2. Set-GraphCredentialsAzureADApplication	-SubscriptionName "<SubscriptionName>" `
                                                -SolutionAbbreviation "<SolutionAbbreviation>" `
                                                -EnvironmentAbbreviation "<EnvironmentAbbreviation>" `
                                                -TenantIdToCreateAppIn "<App-TenantId>" `
                                                -TenantIdWithKeyVault "<KeyVault-TenantId>" `
                                                -Clean $true `
                                                -Verbose
Follow the instructions on the screen.

Note:
* AppTenantId <app-tenant-id> - If the application is going to be installed in a different tenant, set that tenant id here. Refer to [Setting GMM in a demo tenant](https://github.com/microsoftgraph/group-membership-management/blob/main/Documentation/DemoTenant.md) if you want to set up a demo tenant.
* KeyVaultTenantId <keyvault-tenant-id> - This is the tenant where your GMM resources are located, i.e. keyvaults, storage account.
* If you only have one tenant, these will be set to the same tenant id.

### Creating the certificate
If you don't need to use a certificate for authentication you can skip this step.

It is also possible to use a certificate instead of an id / secret pair to authenticate and query Graph API. GMM will automatically look for a certificate and use it if available, otherwise it will fallback to id / secret.

We need to create a certificate that is going to be used for authentication, we are going to use the prereqs keyvault to create and store the certificate. Take note of the certificate name since we need to provide it in the next step.
See [Quickstart: Set and retrieve a certificate from Azure Key Vault using the Azure portal](https://docs.microsoft.com/en-us/azure/key-vault/certificates/quick-create-portal) documentation.

You can also use an existing certificate and upload it to the prereqs keyvault, you will need to provide a friendly certificate name that we will need in the next step.

The script will create these settings in your prereqs keyvault.

-   graphAppClientId
-   graphAppTenantId
-   graphAppClientSecret
-   graphAppCertificateName

From your `PowerShell 7.x` command prompt navigate to the `Scripts` folder of your `Public` repo and run these commands:

    1. . ./Set-GraphCredentialsAzureADApplication.ps1
    2. Set-GraphCredentialsAzureADApplication	-SubscriptionName "<SubscriptionName>" `
                                                -SolutionAbbreviation "<SolutionAbbreviation>" `
                                                -EnvironmentAbbreviation "<EnvironmentAbbreviation>" `
                                                -TenantIdToCreateAppIn "<App-TenantId>" `
                                                -TenantIdWithKeyVault "<KeyVault-TenantId>" `
                                                -CertificateName "<CertificateName>" `
                                                -Clean $true `
                                                -Verbose

Follow the instructions on the screen.

From your `PowerShell 7.x` command prompt navigate to the `Scripts` folder of your `Private` repo and run these commands:

    1. . ./Set-GMMSqlMembershipAzureADApplication.ps1
    2. Set-GMMSqlMembershipAzureADApplication	-SubscriptionName "<SubscriptionName>" `
                                                -SolutionAbbreviation "<SolutionAbbreviation>" `
                                                -EnvironmentAbbreviation "<EnvironmentAbbreviation>" `
                                                -Clean $true `
                                                -Verbose

### Upload the certificate to your `<solutionAbbreviation>`-Graph-`<environmentAbbreviation>` application.

If you don't need to use a certificate for authentication you can skip this step.

We need to upload the certificate to the `<solutionAbbreviation>`-Graph-`<environmentAbbreviation>` application, in order to do that we need to export it from the prerqs keyvault.

Exporting the certificate:

1. In the Azure Portal navigate to your prereqs keyvault, it will be named following this convention `<solutionAbbreviation>`-prereqs-`<environmentAbbreviation>`.
2. Locate and click on the Certificates blade on the left menu.
3. Click on your certificate from the list.
4. Click on the latest version.
5. On the top menu click on 'Download in CER format' button to download the certificate.

If you need more details on how to export the certificate please see [Quickstart: Set and retrieve a certificate from Azure Key Vault using the Azure portal](https://docs.microsoft.com/en-us/azure/key-vault/certificates/quick-create-portal) documentation.

Uploading the certificate:

1. In the Azure Portal navigate to your 'Azure Active Directory'. If you don't see it on your screen you can use the top search bar to locate it.
2. Navigate to 'App registrations' blade on the left menu.
3. Click on 'All applications" to locate and open your `<solutionAbbreviation>`-Graph-`<environmentAbbreviation>` application.
4. On your application screen click on 'Certificates and secrets' blade on the left menu.
5. Click on the 'Upload certificate' button.
6. Locate and add your certificate.

### Granting permissions

Once your application is created, we need to grant the requested permissions to use Microsoft Graph API:

1. In the Azure Portal navigate to your `Azure Active Directory`. If you don't see it on your screen you can use the top search bar to locate it.
2. Navigate to `App registrations` blade on the left menu.
3. Click on `All applications` to locate and open your `<solutionAbbreviation>`-Graph-`<environmentAbbreviation>` application.
4. On your application screen click on `API permissions` blade on the left menu.
5. Click on the 'Grant admin consent for `<YourOrganizationName>`' button.
6. You might need to refresh the page to see the permissions status updated.

## Create the WebAPI application and populate prereqs keyvault

See [WebApiSetup.md](https://github.com/microsoftgraph/group-membership-management/blob/main/Service/GroupMembershipManagement/Hosts/WebApi/Documentation/WebApiSetup.md) for more information.

## Create the UI application and populate prereqs keyvault

See [UISetup.md](https://github.com/microsoftgraph/group-membership-management/blob/main/UI/Documentation/UISetup.md) for more information.

## Set sender address for email notification 

See [SetSenderAddressForEmailNotification.md](https://github.com/microsoftgraph/group-membership-management/blob/main/Service/GroupMembershipManagement/Repositories.Mail/Documentation/SetSenderAddressForEmailNotification.md) for more information.

## Adding a new GMM environment

See [GMM Environments](#gmm-environments) and [ARM templates and parameter files overview](#ARM-templates-and-parameter-files-overview).

### To add a new GMM environment:


1. In your `Private` repo, locate and open file [vsts-cicd.yml](https://github.com/microsoftgraph/group-membership-management-tenant/blob/main/vsts-cicd.yml)
2. Locate the `yaml/deploy-pipeline.yml` template of the `env` environment. It should look like this:
```
    - template: yaml/deploy-pipeline.yml
    parameters:
        solutionAbbreviation: '$(SolutionAbbreviation)'
        environmentAbbreviation: '<env>'
        tenantId: $(tenantId)
        subscriptionName: $(subscriptionName_nonprod)
        subscriptionId: $(subscriptionId_nonprod)
        location: $(location)
        serviceConnection: '$(SolutionAbbreviation)-serviceconnection-<env>'
        dependsOn:
        - Build_Common
        - Build_CopyParameters
        stageName: 'NonProd_<env>'
        functionApps:
        - function:
        name: 'NonProdService'
        - function:
        name: 'GraphUpdater'
        - function:
        name: 'MembershipAggregator'
        dependsOn:
        - 'GraphUpdater'
        - function:
        name: 'GroupMembershipObtainer'
        dependsOn:
        - 'MembershipAggregator'
        - function:
        name: 'AzureMaintenance'
        - function:
        name: 'TeamsChannel'
        dependsOn:
        - 'MembershipAggregator'
        - function:
        name: 'JobTrigger'
        dependsOn:
        - 'MembershipAggregator'
        - function:
        name: 'Notifier'
        deployJobScheduler: true
        condition: |
        and(
            succeeded('Build_Common'),
            succeeded('Build_CopyParameters'),
            eq(variables['Build.SourceBranch'], 'refs/heads/develop'),
            in(variables['Build.Reason'], 'IndividualCI', 'Manual')
        )
```
3. Copy and paste the template located in step two, then replace the values for these settings accordingly using the name of your new environment:
    - environmentAbbreviation
    - serviceConnection
    - stageName

    Save your changes.

4. In your `Private` repo, locate and open file [vsts-cicd.yml](https://github.com/microsoftgraph/group-membership-management-tenant/blob/main/vsts-cicd.yml)

5. Locate the `yaml/copy-deploy-webapp.yml` template of the `env` environment. It should look like this:
```
    - template: yaml/copy-deploy-webapp.yml
    parameters:
        alias: ''
        solutionAbbreviation: '$(SolutionAbbreviation)'
        environmentAbbreviation: '<env>'
        tenantId: $(tenantId)
        subscriptionId: $(subscriptionId_prod)
        location: $(location)
        serviceConnection: '$(SolutionAbbreviation)-serviceconnection-<env>'
        buildRelease: ${{variables.buildRelease}}
        stageName: 'Prod_webapp_<env>'
        condition: |
        and(
            succeeded('Build_WebApp'),
            in(variables['Build.SourceBranch'], 'refs/heads/main'),
            in(variables['Build.Reason'], 'IndividualCI', 'Manual')
        )
```
6. Edit the following fields of the duplicated template:
    * There are three parameters that you must be set to your `<EnvironmentAbbreviation>`:

        - environmentAbbreviation
        - serviceConnection
        - stageName

7. Save your changes.

8. In your `Private` repo, locate and open file [vsts-cicd.yml](https://github.com/microsoftgraph/group-membership-management-tenant/blob/main/vsts-cicd.yml)

9. Locate the `repositories` information at the top. It should look like this:
    ```
    resources:
      repositories:
      - repository: group-membership-management
        type: git
        name: <ADO-PROJECT>/<ADO-GMM-PUBLIC-REPOSITORY>
        ref: refs/tags/<TAG>
    ```
10. - Replace `<ADO-PROJECT>/<ADO-GMM-PUBLIC-REPOSITORY>` with your project name and your `Public` repository name.
    - Change `<TAG>` to the latest tag. The latest Git tag for a repository can be found next to the commit. If you see multiple tags on a commit, please specify one among those. Alternatively, you can replace the line `ref: refs/tags/<TAG>` to `ref: main` so that it will pick up the latest commit from the `main` branch during build/release.

11. Save your changes.

12. Create parameter files based off the provided `parameters.env.json` by using the [Add-ParamFiles.ps1](https://github.com/microsoftgraph/group-membership-management/blob/main/Scripts/Add-ParamFiles.ps1) script:
    * From your PowerShell command prompt navigate to the Scripts folder of your `Public` repo and type these commands.

            1. . ./Add-ParamFiles.ps1
            2. Add-ParamFiles   -EnvironmentAbbreviation "<EnvironmentAbbreviation>" `
                                -SourceEnvironmentAbbreviation "<SourceEnvironmentAbbreviation>" `
                                -RepoPath "<RepoPath>"
        * Use `"env"` for `<SourceEnvironmentAbbreviation>` and the absolute path to your private repository for `<RepoPath>`.
    * This command will go into each of the `parameters` folders and copy and rename the `parameters.env.json` file to `parameters.<EnvironmentAbbreviation>.json`. These new parameter files will be used to by the ARM templates to deploy the resources of the new environment.
    * You may create an AAD Group and provide the values for sqlAdministratorsGroupId and sqlAdministratorsGroupName in [data/parameters](https://github.com/microsoftgraph/group-membership-management-tenant/blob/main/Infrastructure/data/parameters) and [data/private/parameters](https://github.com/microsoftgraph/group-membership-management-tenant/blob/main/Infrastructure/data/private/parameters/parameters.env.json) files.
    * You also want to provide values for `branch` and `repositoryUrl` in [your UI param file](https://github.com/microsoftgraph/group-membership-management-tenant/blob/main/Service/GroupMembershipManagement/Hosts/UI/Infrastructure/compute/parameters). You can provide "" for `customDomainName` if you have not set up a custom domain.
     * You also want to replace values for `<tenant-id>`, `<subscription-id>`, `<data-resource-group-name>` and `<data-key-vault-name>` in SqlMembershipObtainer/Infrastructure/compute/param file.

### To remove a GMM environment:

1. Delete your environment from [vsts-cicd.yml](https://github.com/microsoftgraph/group-membership-management-tenant/blob/main/vsts-cicd.yml) and save your changes. You might need to update any templates that had a dependency on the deleted template. For instance `dependsOn` and `condition` settings.

2. Use the [Remove-ParamFiles.ps1](https://github.com/microsoftgraph/group-membership-management/blob/main/Scripts/Remove-ParamFiles.ps1) script to remove the parameter files of the given environment:
    * From your PowerShell command prompt navigate to the Scripts folder of your `Public` repo and type these commands.

            1. . ./Remove-ParamFiles.ps1
            2. Remove-ParamFiles    -TargetEnvironmentAbbreviation "<TargetEnvironmentAbbreviation>" `
                                    -RepoPath "<RepoPath>"
        * Use the `<EnvironmentAbbreviation>` of the environment you want to remove for `<TargetEnvironmentAbbreviation>` and the path to your private repository for `<RepoPath>`.

## Create a Service Connection

In order to deploy GMM resources through a pipeline, we need to create a [Service Connection](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml) and grant permissions to it.

The following PowerShell scripts create a Service Principal and set up a Service Connection for your environment:

1.  Set-ServicePrincipal.ps1

    This script will create a new service principal for your environment.

    From your `PowerShell 7.x` command prompt navigate to the `Scripts` folder of your `Public` repo and type these commands.

        1. . ./Set-ServicePrincipal.ps1
        2. Set-ServicePrincipal -SolutionAbbreviation "<SolutionAbbreviation>"  `
                                                -EnvironmentAbbreviation "<EnvironmentAbbreviation>" `
                                                -Verbose

    Follow the instructions on the screen.

    Locate the service connection name on the screen. It follows this naming convention: `<SolutionAbbreviation>`-serviceconnection-`<EnvironmentAbbreviation>`.

2.  Set-ServicePrincipalManagedIdentityRoles.ps1

    This script will grant the service principal `Contributor` role over all resource groups for GMM. This script must be run by someone with the <b>Owner role on the subscription.</b>

    From your `PowerShell 7.x` command prompt navigate to the `Scripts` folder of your `Public` repo and type these commands.

        1. . ./Set-ServicePrincipalManagedIdentityRoles.ps1
        2. Set-ServicePrincipalManagedIdentityRoles -SolutionAbbreviation "<SolutionAbbreviation>"  `
                                                -EnvironmentAbbreviation "<EnvironmentAbbreviation>" `
                                                -Verbose

3. Set-ServiceConnection.ps1

    This script sets up the service connection for your environment. You must be an owner of the the service principal created in step 1 to run this script.

    From your `PowerShell 7.x` command prompt navigate to the `Scripts` folder of your `Public` repo, run these commands, and follow the instructions on the screen:

        1. . ./Set-ServiceConnection.ps1
        2. Set-ServiceConnection -SolutionAbbreviation "<SolutionAbbreviation>"  `
                                                -EnvironmentAbbreviation "<EnvironmentAbbreviation>" `
                                                -OrganizationName "<OrganizationName>" `
                                                -ProjectName "<ProjectName>" `
                                                -Clean $true `
                                                -Verbose

    Where:
    *  `<OrganizationName>` - This is the name of your organization used in Azure DevOps.
    *  `<ProjectName>` - This is the name of the project in Azure DevOps we just created in a previous step.

4. Give service connection access to the keyvaults

    Go to your `<SolutionAbbreviation>`-prereqs-`<EnvironmentAbbreviation>` keyvault > Click on 'Access policies' > Click on Create > Select Get, List, and Set secrets permissions and then add your `<SolutionAbbreviation>`-serviceconnection-`<EnvironmentAbbreviation>` as the principal.

5. In addition to the Contributor role, the service connection needs addional actions no included in the Contributor role. To grant these permissions, follow the steps:
   From your `PowerShell 7.x` command prompt navigate to the `Scripts` folder of your `Public` repo, run these commands:

        1. . ./Set-CustomRole.ps1
        2. Set-CustomRole -SolutionAbbreviation "<SolutionAbbreviation>"  `
                          -EnvironmentAbbreviation "<EnvironmentAbbreviation>" `
                          -Verbose

    The script will create a custom role named "GMM Custom Role" and assign it to the service principal. This role has the following permissions:
    - Microsoft.Authorization/locks/*

## Setup the Notifier

Please follow the instructions in the [Notifier Setup](https://github.com/microsoftgraph/group-membership-management/blob/main/Documentation/NotifierSetup.md) documentation.

## Create an Azure DevOps environment

An environment is necessary to manage deployment approvals. To create the environment:

1. On Azure DevOps left menu locate Pipelines menu click on `Environments`.
2. Click on `New environments` or `Create environment` button depending on which one is presented to you.
3. Fill in the `Name` field following this naming convention: <SolutionAbbreviation>-<EnvironmentAbbreviation>
4. Add a description (optional).
5. Click on `Create` button.
6. Once created, locate and click on your environment.
7. Click on `More Actions` button. It's displayed as a vertical ellipsis (three vertical dots).
8. Click on `Approvals and checks` option.
9. Click on `Add check` button.
10. Select `Approvals` option then click on `Next` button.
11. Add the user(s) or group(s) that will approve the deployment.
12. Click on `Create` button.

## Create an Azure DevOps pipeline

In Azure DevOps, we need to create a pipeline that will create your resources and deploy your code.

-   See [Create your first pipeline](https://docs.microsoft.com/en-us/azure/devops/pipelines/create-first-pipeline?view=azure-devops&tabs=java%2Cyaml%2Cbrowser%2Ctfs-2018-2) documentation for more information:
    1. On Azure DevOps left menu locate and click on Pipelines.
    2. Click on 'Create Pipeline' or 'New Pipeline' depending on which one is presented to you.
    3. Select Azure Repos Git as your code location.
    4. Select your `Private` repo.
    5. From the list of options select 'Existing Azure Pipelines YAML file'.
    6. Select your branch.
    7. Select '/vsts-cicd.yml' in the Path field.
    8. Click continue.
    9. You will be presented with the "Review your pipeline YAML" screen.
    10. Locate and click on the "Variables" button on the top right side of your screen.
    11. Create the following variables:

        * `location` - This is the location where the Azure resources are going to be created. See [Resource Locations](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/resource-location?tabs=azure-powershell).

        * `subscriptionId_prod` - This is the subscription Id of your production environment.

        * `subscriptionId_nonprod` - This is the subscription Id of your non-production environment.

        * `tenantId` - This is the Azure Active Directory tenant Id, where GMM Azure resources were created.

        * `SolutionAbbreviation` - This is the abbreviation of your solution.

    12. Follow [Update Build/Release Pipeline variables](https://github.com/microsoftgraph/group-membership-management/blob/main/UI/Documentation/UISetup.md) to create additional variables and deploy WebAPI & UI.
    13. Once all variables have been created click on the "Save" button.
    14. Run your pipeline.

    When running the pipeline for the first time you might be prompted to authorize resources, click on "Authorize resources" buttons.

    *Points to remember while running the pipeline:*
        * *If you see an error task `mspremier.BuildQualityChecks.QualityChecks-task.BuildQualityChecks` is missing, install it from [here](https://marketplace.visualstudio.com/items?itemName=mspremier.BuildQualityChecks&ssr=false&referrer=https%3A%2F%2Fapp.vssps.visualstudio.com%2F#overview)*
        * *If you see an error `no hosted parallelism has been purchased or granted`, please fill out [this](https://aka.ms/azpipelines-parallelism-request) form to request a free parallelism grant. Please note that it could take 2-3 business days to approve the request.*
        * *If you see an error `MissingSubscriptionRegistration`, go to Subscription -> Resource Providers and register the missing provider*
        * *If you see deployment failing at RunJobScheduler, run Set-PostDeploymentRoles (next step) and rerun the release*

    15. If you want to set up AzureUserReader Durable Function, please follow the instruction here: [AzureUserReader](https://github.com/microsoftgraph/group-membership-management/blob/main/Service/GroupMembershipManagement/Hosts/AzureUserReader/Documentation/README.md). Otherwise, you can remove this function from vsts-cicd.yml file

## Post-Deployment tasks

Once the pipeline has completed building and deploying GMM code and resources to your Azure resource groups, we need to make some final configuration changes.

### Grant functions and web api access to required resources:

The following script:
1. Grants all functions access to App Configuration.
2. Grants GroupMembershipObtainer, MembershipAggregator, and GraphUpdater functions access to storage account.

From your `PowerShell 7.x` command prompt navigate to the `Scripts/PostDeployment` folder of your `Public` repo, run these commands, and follow the instructions on the screen:

        1. . ./Set-PostDeploymentRoles.ps1
        2. Set-PostDeploymentRoles  -SolutionAbbreviation "<solutionAbbreviation>" `
                                    -EnvironmentAbbreviation "<environmentAbbreviation>" `
                                    -Verbose

Where:
* `<SolutionAbbreviation>` and `<EnvironmentAbbreviation>` are as before.

### Grant the WebAPI access to SQL Server Database

WebAPI will access the database using its system identity to authenticate with the database to prevent the use of credentials.

Once the WebAPI is deployed (`<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-webapi`) and has been created we need to grant it access to the SQL Server DB.

Server name follows this naming convention `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>` and `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-r` for the replica server.
Database name follows this naming convention `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>` and `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>-r` for the replica database.

1. Connect to your SQL Server Database using Sql Server Management Studio (SSMS) or Azure Data Studio.
- Server name : `<server-name>.database.windows.net`
- User name: Use your Azure account.
- Authentication: Azure Active Directory - Universal with MFA
- Database name: `<database-name>`

2. Run these SQL command

- This script needs to run only once per database.
- Make sure you are connected to right database. Sometimes SSMS will default to the master database.

```
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-webapi')
BEGIN
 CREATE USER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-webapi] FROM EXTERNAL PROVIDER;
 ALTER ROLE db_datareader ADD MEMBER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-webapi];
 ALTER ROLE db_datawriter ADD MEMBER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-webapi];
 ALTER ROLE db_ddladmin ADD MEMBER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-webapi];
END
```

Verify it ran successfully by running:
```
SELECT * FROM sys.database_principals WHERE name = N'<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-webapi'
```
You should see one record for your webapi app.
Repeat the steps for both databases.

### Grant the Azure Functions access to SQL Server Database

Azure Functions connect to SQL server via MSI (System Identity), once the database is created as part of the deployment we need to grant access to the functions to read and write to the database.

For these functions:
JobTrigger, GroupMembershipObtainer, SqlMembershipObtainer, AzureMaintenance, PlaceMembershipObtainer*, AzureUserReader, GraphUpdater, JobScheduler, MembershipAggregator, NonProdService, Notifier, GroupOwnershipObtainer, TeamsChannelMembershipObtainer, TeamsChannelUpdater, DestinationAttributesUpdater

Run this commands, in your SQL Server database where the jobs table was created:

    --Production slot
    CREATE USER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-<function>] FROM EXTERNAL PROVIDER
    ALTER ROLE db_datareader ADD MEMBER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-<function>] -- gives permission to read to database
    ALTER ROLE db_datawriter ADD MEMBER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-<function>] -- gives permission to write to database

    --Staging slot
    CREATE USER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-<function>/slots/staging] FROM EXTERNAL PROVIDER
    ALTER ROLE db_datareader ADD MEMBER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-<function>/slots/staging] -- gives permission to read to database
    ALTER ROLE db_datawriter ADD MEMBER [<SolutionAbbreviation>-compute-<EnvironmentAbbreviation>-<function>/slots/staging] -- gives permission to write to database

Repeat the steps above for each function.

*Points to remember:*
        * *Try logging into SQL database via Azure Portal by adding the IP address*

## Grant the Service Connection access to SQL Server Database

Your service connection needs MSI access to the SQL Server DB so it can deploy the DACPAC file.

Once the SQL server and databases are created as part of the deployment we will need to run these SQL statements before we can deploy the DACPAC file and run scripts on the jobs database.

SyncJobs DB
- Server name follows this naming convention `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>`.
- Database name follows this naming convention `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>`.

1. Connect to your SQL Server Database using Sql Server Management Studio (SSMS) or Azure Data Studio.
- Server name : `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>.database.windows.net`
- User name: Your account.
- Authentication: Azure Active Directory - Universal with MFA
- Database name: `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>`

2. Run these SQL commands

SyncJobs DB

- This script needs to run only once.
- Make sure you are connected to SyncJobs database: `<SolutionAbbreviation>-data-<EnvironmentAbbreviation>`.

```
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'<SolutionAbbreviation>-serviceconnection-<EnvironmentAbbreviation>')
BEGIN
    CREATE USER [<SolutionAbbreviation>-serviceconnection-<EnvironmentAbbreviation>] FROM EXTERNAL PROVIDER
    ALTER ROLE db_datareader ADD MEMBER [<SolutionAbbreviation>-serviceconnection-<EnvironmentAbbreviation>] -- gives permission to read to database
    ALTER ROLE db_datawriter ADD MEMBER [<SolutionAbbreviation>-serviceconnection-<EnvironmentAbbreviation>] -- gives permission to write to database
END
```

Verify it ran successfully by running:
```
SELECT * FROM sys.database_principals WHERE name = N'<SolutionAbbreviation>-serviceconnection-<EnvironmentAbbreviation>'
```
You should see one record for your service connection resource.

### Create the jobs table:

The jobs table contains all the sync jobs that GMM will perform.

#### Create jobs table in SQL database

* Go to https://`<solutionAbbreviation>`-compute-`<environmentAbbreviation>`-webapi.azurewebsites.net/swagger/index.html
* Hit the endpoint `admin/databaseMigration`. This will create the jobs table in `<solutionAbbreviation>`-data-`<environmentAbbreviation>` database
    * *Note: To hit the endpoint: 1- Add `ASPNETCORE_ENVIRONMENT: development` in `<solutionAbbreviation>`-compute-`<environmentAbbreviation>`-webapi, 2-update the value of config setting `ConnectionStrings:JobsContext` in `<solutionAbbreviation>`-compute-`<environmentAbbreviation>`-webapi with the value of `jobsMSIConnectionString` which you can find in your data key vault*
* Run [this script](/Scripts/New-GmmGroupMembershipSyncJob.ps1) to add a job to sql database

#### Create notifications tables in storage account:

Open your jobs storage account on Azure Explorer:

* Go to the [Azure Portal](https://ms.portal.azure.com/#home)
* Go to `Subscription` and select the subscription used for GMM
* Go to `Resource Groups` and select `gmm-data-<EnvironmentAbbreviation>`
* Under `Resources`, select the `jobs<EnvironmentAbbreviation><ID>` storage account, and open it on Azure Explorer
* Create a new table called `notifications`
    * Go to the table and click on `Import` at the top bar
    * Import the `thresholdNotificationSample.csv` file located under the `Documentation` folder of your `Public` repo
    * IMPORTANT: Remove the sample entry from the table before proceeding

#### * Please follow Post Deployment tasks on SqlMembershipObtainer/Documentation/README.md

## (Optional) Set up a production environment

To create a production environment:

1. Using the same Azure DevOps repositories and pipeline created on the first iteration, follow the steps of [GMM Setup](#gmm-setup) to create another environment.
2. Use the following `yaml/deploy-pipeline.yml` template for step 2 of [Adding a new GMM environment](#adding-a-new-gmm-environment):

        - template: yaml/deploy-pipeline.yml
        parameters:
            solutionAbbreviation: '$(SolutionAbbreviation)'
            environmentAbbreviation: '<ProdEnvironmentAbbreviation>'
            tenantId: $(tenantId)
            subscriptionId: $(subscriptionId_prod)
            location: $(location)
            serviceConnection: '$(SolutionAbbreviation)-serviceconnection-<ProdEnvironmentAbbreviation>'
            dependsOn:
            - Build_Common
            - Build_CopyParameters
            - NonProd_<NonProdEnvironmentAbbreviation>
            stageName: 'Prod_production'
            functionApps:
            - function:
            name: 'GraphUpdater'
            - function:
            name: 'MembershipAggregator'
            dependsOn:
            - 'GraphUpdater'
            - function:
            name: 'GroupMembershipObtainer'
            dependsOn:
            - 'MembershipAggregator'
            - function:
            name: 'AzureMaintenance'
            - function:
            name: 'JobScheduler'
            - function:
            name: 'Notifier'
            - function:
            name: 'JobTrigger'
            dependsOn:
            - 'GroupMembershipObtainer'
            condition: |
            and(
                succeeded('Build_Common'),
                succeeded('Build_CopyParameters'),
                succeeded('NonProd_<NonProdEnvironmentAbbreviation>'),
                in(variables['Build.SourceBranch'], 'refs/heads/master', 'refs/heads/main'),
                in(variables['Build.Reason'], 'IndividualCI', 'Manual')
            )

    Where:

    * `<ProdEnvironmentAbbreviation>` - The new environment being created or your production environment.
    * `<NonProdEnvironmentAbbreviation>` - The previously created environment or your non-production environment.

    Note: if you notice the condition section, it states that your non-production environment must deploy successfully for your production environment to deploy.

3. Add the following variables to your pipeline as you did in step 11 of [Creating a Pipeline](#create-an-azure-devops-pipeline):

    * `subscriptionId_prod` - This is the subscription Id of your production environment.
    * `SolutionAbbreviation` - This is the abbreviation of your solution.



# Using GMM

## Creating synchronization jobs for source groups

Once GMM is up and running you might want to start creating synchronization jobs for your groups.

### Adding Graph application as an owner to GMM managed destination group

The previously created `<solutionAbbreviation>-Graph-<environmentAbbreviation>` application must be added as an owner to any destination group that will be managed by GMM in order for GMM to have the right permissions to update the group.

To add the application as an owner of a group, follow the next steps:
1. In the Azure Portal navigate to your `Azure Active Directory`. If you don't see it on your screen, you can use the top search bar to locate it.
2. Navigate to the `Groups` blade on the left menu.
3. Locate and open the group you would like to use.
4. Navigate to `Owners` on the left menu.
5. Click on `Add owners` and add your `<solutionAbbreviation>-Graph-<environmentAbbreviation>` application.

### Adding synchronization jobs to the jobs table

A synchronization job must have the following properties populated:

- Requestor
- Destination
- TargetOfficeGroupId
- Status
- LastRunTime
- LastSuccessfulRunTime
- LastSuccessfulStartTime
- Period
- Query
- StartDate
- ThresholdPercentageForAdditions
- ThresholdPercentageForRemovals
- ThresholdViolations
- IsDryRunEnabled
- DryRunTimeStamp

See [syncJobs properties](https://github.com/microsoftgraph/group-membership-management/blob/main/Documentation/syncJobsProperties.md) for more information.


A PowerShell script [New-GmmGroupMembershipSyncJob.ps1](/Scripts/New-GmmGroupMembershipSyncJob.ps1) is provided to help you create the synchronization jobs.

The Query field requires a JSON object that must follow this format:

```
[
    {
        "type": "GroupMembership",
        "source": "<guid-group-objet-id-1>"
    },
    {
        "type": "GroupMembership",
        "source": "<guid-group-objet-id-2>"
    },
    {
        "type": "GroupMembership",
        "source": "<guid-group-objet-id-n>"
    }
]
```
From your `PowerShell 7.x` command prompt navigate to [New-GmmGroupMembershipSyncJob.ps1](/Scripts/New-GmmGroupMembershipSyncJob.ps1), run these commands, and follow the instructions on the screen:

    1. . ./New-GmmGroupMembershipSyncJob.ps1
    2. New-GmmGroupMembershipSyncJob	-SubscriptionName "<SubscriptionName>" `
                            -SolutionAbbreviation "<SolutionAbbreviation>" `
							-EnvironmentAbbreviation "<EnvironmentAbbreviation>" `
							-Requestor "<RequestorEmailAddress>" `
							-TargetOfficeGroupId "<DestinationGroupObjectId>" `
                            -Destination "<JSON string>" `
							-Query "<JSON string>" `
							-Period <in hours, integer only> `
							-ThresholdPercentageForAdditions <integer only> `
							-ThresholdPercentageForRemovals <integer only> `
							-Verbose

You can also add, edit or delete synchronization jobs via `SyncJobs` SQL table`.

### Setting up the NonProdService function

The NonProdService function will create and populate test groups in the tenant for use in GMM integration testing (or for sources in your own manual tests as well). See [Setting up NonProdService function](https://github.com/microsoftgraph/group-membership-management/blob/main/Service/GroupMembershipManagement/Hosts/NonProdService/Documentation/README.md).
### Dry Run Settings

Dry run settings are present in GMM to provide users the ability to test new changes without affecting the group membership. This configuration is present in the application configuration table.
If you would like to have the default setting to be false, then please update the settings in the app configuration to false for the GraphUpdater and GroupMembershipObtainer.

There are 3 Dry Run flags in GMM. If any of these Dry run flags are set, the sync will be completed but destination membership will not be affected.
1. IsDryRunEnabled: This is a property that is set on an individual sync. Setting this to true will run this sync in dry run.
2. GroupMembershipObtainer:IsDryRunEnabled: This is a property that is set in the app configuration table. Setting this to true will run all Security Group syncs in dry run.
3. IsMembershipAggregatorDryRunEnabled: This is a property that is set in the app configuration table. Setting this to true will run all syncs in dry run.

# Setting GroupOwnershipObtainer function
[GroupOwnershipObtainer function](https://github.com/microsoftgraph/group-membership-management/blob/main/Service/GroupMembershipManagement/Hosts/GroupOwnershipObtainer/Documentation/GroupOwnershipObtainer.md)

# Setting GMM in a demo tenant

In the event that you are setting up GMM in a demo tenant refer to [Setting GMM in a demo tenant](https://github.com/microsoftgraph/group-membership-management/blob/main/Documentation/DemoTenant.md) for additional guidance.

# Setting up WebAPI and GMM UI

Please refer to [Create React App](https://github.com/microsoftgraph/group-membership-management/blob/main/UI/web-app/README.md) for additional guidance.
Please refer to [WebAPI](https://github.com/microsoftgraph/group-membership-management/blob/main/Service/GroupMembershipManagement/Hosts/WebApi/Documentation/WebApiSetup.md) for additional guidance.
Please refer to [GMM UI](https://github.com/microsoftgraph/group-membership-management/blob/main/UI/Documentation/UISetup.md) for additional guidance.

# Steps to debug and troubleshoot a failing sync

To troubleshoot any issues that might occur we can use Log Analytics and Application Insights.

1. Find Logs in the Log analytics workspace following the instructions [here](https://github.com/microsoftgraph/group-membership-management/blob/main/Documentation/FindLogEntriesInLogAnalyticsForASync.md).
2. Find failures and exceptions with Application Insights [here](https://github.com/microsoftgraph/group-membership-management/blob/main/Documentation/TroubleshootWithApplicationInsights.md).
3. In case jobs appear to be stuck in progress without any visible exceptions, it is recommended to restart GMM. This can be done by running this script [Restart-GMM.ps1](https://github.com/microsoftgraph/group-membership-management/blob/main/Scripts/Restart-GMM.ps1).

# Tearing down your GMM environment.
In the event that you want to reset the GMM environment refer to [Delete GMM environment](https://github.com/microsoftgraph/group-membership-management/blob/main/Documentation/DeleteEnvironment.md) for additional guidance.

# Breaking changes
See [Breaking changes](https://github.com/microsoftgraph/group-membership-management/blob/main/breaking_changes.md)