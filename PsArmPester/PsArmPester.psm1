Set-StrictMode -Version Latest

Function Audit-ResourceGroupTotal($ResourceGroup, $ResourceTotal) {
    Context "Resource Group Total" {
       It "should have $resourceTotal total resources" {
           $resourceGroup.resources.length | Should Be $resourceTotal
        }
    }
}

Function Audit-ResourceGroupSummary($ResourceGroup, $SummaryTestCases) {
    Context "Overall Group" {
        It "should have <Expected> <Resource>" -TestCases $SummaryTestCases {
            param($Resource, $Expected)
            $Objects =  @($resourceGroup.resources | where {$_.type -Eq $Resource})
            $Objects.length | Should be $Expected
        }
    } 
}

Function Audit-ResourceGroupVMs($ResourceGroup, $VMTestCases) {
    Context "VMs" {
        $VMs = $resourceGroup.resources | where {$_.type -eq 'Microsoft.Compute/virtualMachines'}
        It "desired should include VM named <Name> and sized <VmSize>" -TestCases $VMTestCases {
            param($Name, $VmSize)
            $normalizedName = $Name.Replace('-','_')
            $VM = $VMs | 
                where {$_.name -Match $Name -or $_.name -Match $normalizedName }
            $VM.properties.hardwareProfile.vmSize | Should be $VmSize
        }
    }
}

Function Audit-ResourceGroupStorage($ResourceGroup, $StorageTestCases) {
    Context "StorageAccounts" {
        $StorageAccounts = $resourceGroup.resources | where {$_.type -Match 'storageAccounts'}
        It  "should <State> include storage account <Name>" -TestCases $StorageTestCases {
            param($Name, $State)
            $StorageAccount = $StorageAccounts | where {$_.name -Match $Name}
            if ($State) {
                $StorageAccount | Should Not BeNullOrEmpty
            } else {
                $StorageAccount | Should BeNullOrEmpty
            }
        }

        It "should use replication <Replication>" -TestCases $StorageTestCases {
            param($Name, $Replication)
            $StorageAccounts = 
                $resourceGroup.resources | where {$_.type -Match 'storageAccounts'}
            $StorageAccount = $StorageAccounts | where {$_.name -Match $Name}
            $StorageAccount.sku.name | Should Match $Replication
        }
    }
}

Function Audit-AzureRMNetworkSecurityGroup($ResourceGroup, $TestCases) {
    Context "NetworkSecurityGroup" {
        $NSGs = @($resourceGroup.resources | 
            where {$_.type -Eq 'Microsoft.Network/networkSecurityGroups'})
        It  "should include networkSecurityGroup <Name>" -TestCases $TestCases {
            param($Name)
            @($NSGs | where {$_.name -Match $Name}).length | Should Be 1
        }

        It  "networkSecurityGroup <Name> should have <SecurityRuleCount> rules" -TestCases $TestCases {
            param($Name,$SecurityRuleCount)
            $NSG = $NSGs | where {$_.name -Match $Name} 
            $NSG.properties.securityRules.count | Should Be $SecurityRuleCount
        }
    }
}

Function Audit-AzureRMVNet($ResourceGroup, $TestCases) {
    Context "VNet" {
        $VNets = @($resourceGroup.resources | 
            where {$_.type -Eq 'Microsoft.Network/virtualNetworks'})
        It  "should include vNet <Name>" -TestCases $TestCases {
            param($Name)
            @($VNets | where {$_.name -Match $Name}).length | Should Be 1
        }
        It "should use AddressPrefix <AddressPrefixes>" -TestCases $TestCases {
            param($Name, $AddressPrefixes)
            $VNet = $VNets | where {$_.name -Match $Name}
            $Vnet.properties.addressspace.addressPrefixes |
                Should Be $AddressPrefixes
        }
        It "should have <SubnetCount> subnets" -TestCases $TestCases {
            param($Name, $SubnetCount)
            $VNet = $VNets | where {$_.name -Match $Name}
            $Vnet.properties.subnets.count |
                Should Be $SubnetCount
        }
    }
}

Function Audit-AzureRMRouteTable ($ResourceGroup, $TestCases) {
    Context "RouteTables" {
        $RouteTables = @($resourceGroup.resources | 
            where {$_.type -Eq 'Microsoft.Network/routeTables'})
        It  "should include routeTable <Name>" -TestCases $TestCases {
            param($Name)
            @($RouteTables| where {$_.name -Match $Name}).length | Should Be 1
        }
        It "should have <RouteCount> routes" -TestCases $TestCases {
            param($Name, $RouteCount)
            $RouteTable = $RouteTables | where {$_.name -Match $Name}
            $RouteTable.properties.routes.count |
                Should Be $RouteCount
        }
    }
}

# Problem: $actual for DevVnetVA doesn't include the VNet peering information
#   Confirmed by ` $actual.resources[3].properties |ConvertTo-Json`
# and by reviewing the JSON emitted not containing string 'Peer'
#
# Solution: Ignore the problem and accept that we won't be able to model
#  everything with tests at this point
#
# Discussion Points:
# 1. Export-AzureRMResourceGroup is incomplete, and doesn't export VNet peerings. This is an API limitation
# 2. The vNet Peerings can be seen with say:
#      PS> $a = Get-AzureRMResource -ResourceGroupName 'DevVnetVA' -ResourceType 'Microsoft.Network/virtualNetworks' -ExpandProperties
#      PS> $a.Properties.virtualNetworkPeerings.properties
#    and they's appears as properties of a property
# 3. Directy querying the API for all resources with properties doesn't work. See https://github.com/Azure/azure-powershell/issues/2494
#    for Invoke-RestMethod with Azure, but the `resources` endpoint doesn't actually expand the list
# 4. VNetPeering is weird, they are modelled not as properties of a Vnet, but as resources associated with a Vnet.
#    See https://github.com/Azure/azure-quickstart-templates/blob/master/201-vnet-to-vnet-peering/azuredeploy.json#L44-L65


Function Get-ActualResourceGroup([string] $ResourceGroupName) {
    $DeploymentName = $ResourceGroupName + $(get-date -f yyyyMMddHHmmss)
    $actualFile = $env:TEMP + '\actual-'+ $deploymentName + '.json'
    Write-Verbose "Saving actual Azure state to $actualFile"
    $result = Export-AzureRmResourceGroup -ResourceGroupName $ResourceGroupName -IncludeParameterDefaultValue -Path $actualFile
    Get-Content $actualFile | ConvertFrom-Json
}

Function Get-DesiredResourceGroup([string] $ResourceGroupName, [string] $DeployScript) {
    if (Test-Path $DeployScript) {
        $DeploymentName = $ResourceGroupName + $(get-date -f yyyyMMddHHmmss)
        $desiredFile = $env:TEMP + '\desired-'+ $deploymentName + '.json'
        Write-Verbose "Save desired Azure state from $DeployScript to $desiredFile"
        Invoke-Expression "$DeployScript -Path $desiredFile"
        Get-Content $desiredFile | ConvertFrom-Json
    } else {
        Write-Error "Can't find path $DeployScript"
    }
}

# Export-ResourceGroupDeployment doesn't provide the
# actual resource name, but something like 
#    [parameters('networkSecurityGroups_DevVnetIADefaultNsg_name')]
# so we add the _simpalename_name to make it more likely unique
Function Get-AzureRMParamName([string] $simpleName) {
    if ($global:mungeNames) { 
        return "_" + $simpleName + "_nameasldj"
    }
    return $simpleName
}

Export-ModuleMember -Function Audit-ResourceGroupTotal
Export-ModuleMember -Function Audit-ResourceGroupSummary
Export-ModuleMember -Function Audit-ResourceGroupVMs
Export-ModuleMember -Function Audit-ResourceGroupStorage

Export-ModuleMember -Function Audit-AzureRMNetworkSecurityGroup
Export-ModuleMember -Function Audit-AzureRMVNet
Export-ModuleMember -Function Audit-AzureRMRouteTable

Export-ModuleMember -Function Get-ActualResourceGroup
Export-ModuleMember -Function Get-DesiredResourceGroup