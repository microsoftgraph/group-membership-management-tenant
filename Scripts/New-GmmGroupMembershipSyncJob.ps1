$ErrorActionPreference = "Stop"
<#
.SYNOPSIS
Create a sync job

.DESCRIPTION
This script facilitates the creation of a GMM sync job

.PARAMETER SubscriptionName
The name of the subscription into which GMM is installed.

.PARAMETER SolutionAbbreviation
Abbreviation for the solution.

.PARAMETER EnvironmentAbbreviation
Abbreviation for the environment

.PARAMETER Requestor
The requestor of the sync job.

.PARAMETER TargetOfficeGroupId
The destination M365 Group into which source users will be synced.

.PARAMETER Destination
[{"value":{"objectId":"<TargetOfficeGroupId>"},"type":"GroupMembership"}]

.PARAMETER StartDate
The date that the sync job should start.

.PARAMETER Period
Sets the frequency for the job execution. In hours. Integers only. Default is 6 hours.

.PARAMETER Query
This value depends on the type of sync job.  See example below for details.

Query of GroupMembership type

Single Source
[{"type":"GroupMembership","source":"<group-object-id>"}]

Multiple Sources
[{"type":"GroupMembership","source":"<group-object-id-1>"},{"type":"GroupMembership","source":"<group-object-id-2>"}]

Query of SqlMembership type
[{"type":"SqlMembership","source":{"filter":"(Email = ''''XYZ'''')"}}]

.PARAMETER ThresholdPercentageForAdditions
This value determines threshold percentage for users being added.  Default value is 100 unless specified in the sync request. See example below for details.

.PARAMETER ThresholdPercentageForRemovals
This value determines threshold percentage for users being removed.  Default value is 10 unless specified in the sync request. See example below for details.

.PARAMETER GroupTenantId
Optional
If your group resides in a different tenant than your storage account, provide the tenant id where the group was created.

.EXAMPLE
Add-AzAccount

New-GmmGroupMembershipSyncJob	-SubscriptionName "<subscription name>" `
                            -SolutionAbbreviation "<solution abbreviation>" `
							-EnvironmentAbbreviation "<env>" `
							-Requestor "<requestor email address>" `
							-TargetOfficeGroupId "<destination group object id>" `
							-Destination "<destination>" `                       # See .PARAMETER Destination above for more information
							-Query "<query>" `                       # See .PARAMETER Query above for more information
							-Period <in hours, integer only> `
							-ThresholdPercentageForAdditions <100> ` # integer only
							-ThresholdPercentageForRemovals <10> `   # integer only
							-Verbose
#>

function New-GmmGroupMembershipSyncJob {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$True)]
		[string] $SubscriptionName,
		[Parameter(Mandatory=$True)]
		[string] $EnvironmentAbbreviation,
		[Parameter(Mandatory=$True)]
		[string] $SolutionAbbreviation,
		[Parameter(Mandatory=$True)]
		[string] $Requestor,
		[Parameter(Mandatory=$True)]
		[Guid] $TargetOfficeGroupId,
		[Parameter(Mandatory=$True)]
		[string] $Destination,
		[Parameter(Mandatory=$True)]
		[string] $Query,
		[Parameter(Mandatory=$False)]
		[DateTime] $StartDate,
		[Parameter(Mandatory=$False)]
		[int] $Period = 6,
		[Parameter(Mandatory=$False)]
		[int] $ThresholdPercentageForAdditions = 100,
		[Parameter(Mandatory=$False)]
		[int] $ThresholdPercentageForRemovals = 10,
		[Parameter(Mandatory=$False)]
		[string] $ErrorActionPreference = $Stop,
		[Parameter(Mandatory=$False)]
		[Guid] $GroupTenantId
	)
	"New-GmmGroupMembershipSyncJob starting..."

	$dataKeyVaultName = "$SolutionAbbreviation-data-$EnvironmentAbbreviation"
    $sqlDatabaseConnectionString = Get-AzKeyVaultSecret -VaultName $dataKeyVaultName -Name "sqlDatabaseConnectionString" -AsPlainText
	$context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext

	if ($null -ne $GroupTenantId -and [Guid]::Parse($context.Tenant.Id) -ne $GroupTenantId)
	{
		Write-Host "Please sign into an account that can read the display names of groups in the $GroupTenantId tenant."
		Add-AzAccount -Tenant $GroupTenantId
	}

	if ($Null -eq $StartDate)
	{
		$StartDate = ([System.DateTime]::UtcNow)
	}

	$LastRunTime = Get-Date -Date "1753-01-01"

	$sqlToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://database.windows.net").AccessToken
	$connection = New-Object System.Data.SqlClient.SqlConnection
	$connection.ConnectionString = $sqlDatabaseConnectionString
	$connection.AccessToken = $sqlToken
	$connection.Open()

	# Check if a row with TargetOfficeGroupId already exists
	$queryCheckIfExists = "SELECT COUNT(*) FROM SyncJobs WHERE TargetOfficeGroupId = '$TargetOfficeGroupId'"
	$command = $connection.CreateCommand()
	$command.CommandText = $queryCheckIfExists
	$rowExists = $command.ExecuteScalar()
	if ($rowExists -gt 0) {
		Write-Host "A group with TargetOfficeGroup Id $TargetOfficeGroupId already exists in the table. This job will not be onboarded." -ForegroundColor Red
		$connection.Close()
		return
	}

	$insertcommand = $connection.CreateCommand()
	$insertcommand.CommandText = "
		INSERT INTO SyncJobs (Requestor, TargetOfficeGroupId, Status, Destination, LastRunTime, LastSuccessfulRunTime, LastSuccessfulStartTime, Period, Query, StartDate, ThresholdPercentageForAdditions, ThresholdPercentageForRemovals, IsDryRunEnabled, DryRunTimeStamp)
		VALUES (
			'$Requestor',
			'$TargetOfficeGroupId',
			'Idle',
			'$Destination',
			'$LastRunTime',
			'$LastRunTime',
			'$LastRunTime',
			'$Period',
			'$Query',
			'$StartDate',
			'$ThresholdPercentageForAdditions',
			'$ThresholdPercentageForRemovals',
			0,
			'$LastRunTime'
		);"
	$result = $insertcommand.ExecuteNonQuery()

	if (1 -eq $result) {
		Write-Host "$($syncJob.RowKey) OK"
	}
	else {
		Write-Host "$($syncJob.RowKey) $result"
	}
	$connection.Close()

   	"New-GmmGroupMembershipSyncJob completed."
}