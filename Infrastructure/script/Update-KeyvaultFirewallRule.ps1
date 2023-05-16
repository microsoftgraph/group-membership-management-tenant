$ErrorActionPreference = "Stop"
<#
.SYNOPSIS
Updates the KeyVault Networking policy to allow access from the input IP addresses

.PARAMETER KeyvaultName
The name of the keyvault to update Networking policies for

.PARAMETER Add
Whether to add or remove the host-caller's IP address from the keyvault's Networking policies

.EXAMPLE
Update-KeyVaultFirewallRule	-KeyvaultName "gmm-prereqs-<env>" `
                            -Add true
#>

function Update-KeyVaultFirewallRule {
    [CmdletBinding()]
    param(
      [Parameter(Mandatory=$True)]
      [string] $KeyvaultName,
      [Parameter(Mandatory=$True)]
      [bool] $Add
    )

    $service = "https://$KeyvaultName.vault.azure.net/healthstatus?api-version=7.3"
    $respHeader = Invoke-WebRequest -Uri $service -Method GET -UseBasicParsing | Select-Object -ExpandProperty Headers
    $respHeader.'x-ms-keyvault-network-info'.Split(';') | ForEach-Object {
        $keyValue = $_.Split('=')
        if($null -ne $keyValue -and $keyValue.Count -gt 1 ){
          if($keyValue[0] -eq 'addr'){
            $hostIPAddress = $keyValue[1]
          }
        }
    }
    Write-Host $hostIPAddress

    if ($Add) {
        Add-AzKeyVaultNetworkRule -VaultName $KeyvaultName -IpAddressRange $hostIPAddress
    } else {
        Remove-AzKeyVaultNetworkRule -VaultName $KeyvaultName -IpAddressRange $hostIPAddress
    }
}