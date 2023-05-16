$ErrorActionPreference = "Stop"
<#
.SYNOPSIS
Updates the ipRules.json file (leveraged by bicep deployment) to have the latest IP addresses that we should
allow-list on our KeyVaults.

#>

function Update-KeyVaultBicepWithFirewallIPs {

    # Installing MSIdentityTools Module
    Write-Host "Installing MSIdentityTools Module to fetch the Azure published IP ranges..." -ForegroundColor Yellow
    Install-Module -Name MSIdentityTools -Scope CurrentUser -Force

    $allIPRanges = Get-MsIdAzureIpRange -AllServiceTagsAndRegions

    $azureSubnetProperties = $allIPRanges.values.properties
    $regions = $azureSubnetProperties.region `
    | Sort-Object -Unique `
    | Where-Object { $_.Contains('us') -and -not `
                    $_.Contains('australia') -and -not `
                    $_.Contains('austria') -and -not `
                    $_.Contains('euap') -and -not `
                    $_.Contains('usstag') -and -not `
                    $_.Contains('slv') -and -not `
                    $_.Contains('east') -and -not `
                    $_.Contains('central') }

    $systemServices = @()
    $systemServices += "AzureAppService"
    $systemServices += "AzureDevOps"
    $systemServices += "DataFactory"
    $systemServices += ""

    $filteredSubnetProperties = $azureSubnetProperties | Where-Object { ($_.systemService -in $systemServices -and $_.region -in $regions) }
    $filteredIpV4AddressPrefixes = $filteredSubnetProperties.addressPrefixes | Where-Object { $_.Contains('.') }
    $filteredIpV4AddressPrefixes = $filteredIpV4AddressPrefixes | Sort-Object -Unique
    $filteredIpV4AddressPrefixes.Count

    $formattedIpList = [System.Collections.ArrayList]::new()

    $filteredIpV4AddressPrefixes | ForEach-Object {
        $formattedIpList.Add(
        @{
            "value" = $_
        }
        )
    }

    $formattedIpList | ConvertTo-Json | Out-File "ipRules.json"

}

Update-KeyVaultBicepWithFirewallIPs