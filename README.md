# Group Membership Management (GMM) custom settings setup

This repository enables GMM users to customize their GMM environments with no need to change the public code  [GMM](https://github.com/microsoftgraph/group-membership-management) in order to facilitate the transition to new versions as they become available.


## Prerequisites

Set up GMM as described here [README](https://github.com/microsoftgraph/group-membership-management#readme).

## Setup

- Add this code to your private repository.
- Add submodule to GMM code.
- Rename the existing environments in this repo (including file names) with your own unique environment names.
- Add / remove environments as needed.

#### How to setup repository with a submodule?

```
git clone <url-tenant-gmm-ado-repository>
cd <gmm-repository-folder>
git submodule add <url-gmm-ado-repository> public
ls # you should see public submodule
cd public
ls # no contents within public submodule
git submodule update --init --recursive
ls # you should see contents from public ADO repository within public submodule
```

#### How to update submodule?
From the folder that contains the submodule.

```
git submodule update --remote --merge
git add public
git commit -m "updated public submodule"
git push
```

Note:

When you run a build from pipeline after setting up GMM as described here [README](https://github.com/microsoftgraph/group-membership-management#readme), a git tag that matches the build number is added to the the latest commit.

Update `ref: refs/tags/<TAG>` in [vsts-cicd.yml](https://microsoftit.visualstudio.com/OneITVSO/_git/STW-Sol-GrpMM-tenant?path=/vsts-cicd.yml&version=GBdevelop&line=12&lineEnd=12&lineStartColumn=5&lineEndColumn=17&lineStyle=plain&_a=contents) with that tag for a successful build/release.

## Settings

GMM provides default values for most of the settings needed for its operation. However there are some settings that need to be provided in order to work in your environment.

As described before GMM logically divides in three groups the resources it creates needed for its operation.

- prereqs
- data
- compute

### Global data settings

Global data settings are defined in Infrastructure\data\parameters.`<environment>`.json file. See [parameters.prodv2.json](\Infrastructure\data\parameters\parameters.prodv2.json)

### Azure Function data and compute settings

Each function has two parameter files, one for data resources and the other one for compute resources. All settings provide default values.  
To customize each function locate the desired function under:

    \Service\GroupMembershipManagement\Hosts\FUNCTION_NAME\Infrastructure\(data|compute)\parameters

In order to customize function settings, copy the data or compute parameters.<env>.json file from [GMM](https://github.com/microsoftgraph/group-membership-management) repository and paste it in corresponding function. Edit the file as needed, commit and push your changes.



## How to update your GMM ADO repository with latest changes from GitHub?

* Setting public GitHub repository as the upstream of your GMM ADO repository.

    ```
    git clone <url-gmm-ado-repository>
    git remote add upstream https://github.com/microsoftgraph/group-membership-management.git
    git fetch upstream
    git checkout upstream/main -b <new-branch-name>
    git merge upstream/main
    git push --set-upstream origin <new-branch-name>
    ```
