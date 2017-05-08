Set-StrictMode -Version Latest

Function Assert-PSArmGroupTotal {
    Param(
        [parameter(Mandatory=$True,Position=0)]
        [System.Object] $Target,

        [parameter(Mandatory=$True,Position=1)]
        [string] $Matches
    )
    Context "Resource Group Total" {
       It "should have $Matches total resources" {
           $Target.resources.length | Should Be $Matches
        }
    }
}

Function Assert-PsArmGroupSummary {
    Param(
        [parameter(Mandatory=$True,Position=0)]
        [System.Object] $Target,

        [parameter(Mandatory=$True,Position=1)]
        [System.Object] $Matches
    )
    Context "Overall Group" {
        It "should have <Expected> <Resource>" -TestCases $Matches {
            param($Resource, $Expected)
            $Objects =  @($target.resources | where {$_.type -Eq $Resource})
            $Objects.length | Should be $Expected
        }
    } 
}

Function Assert-PsArmVM {
    Param(
        [parameter(Mandatory=$True,Position=0)]
        [System.Object] $Target,

        [parameter(Mandatory=$True,Position=1)]
        [System.Object] $Matches
    )
    Context "VMs" {
        $VMs = $target.resources | where {$_.type -eq 'Microsoft.Compute/virtualMachines'}
        It "desired should include VM named <Name> and sized <VmSize>" -TestCases $Matches {
            param($Name, $VmSize)
            $normalizedName = $Name.Replace('-','_')
            $VM = $VMs | 
                where {$_.name -Match $Name -or $_.name -Match $normalizedName }
            $VM.properties.hardwareProfile.vmSize | Should be $VmSize
        }
    }
}

Function Assert-PsArmStorage {
    Param(
        [parameter(Mandatory=$True,Position=0)]
        [System.Object] $Target,

        [parameter(Mandatory=$True,Position=1)]
        [hashtable] $Matches
    )
    Context "StorageAccounts" {
        $StorageAccounts = $target.resources | where {$_.type -Match 'storageAccounts'}
        It  "should <State> include storage account <Name>" -TestCases $Matches {
            param($Name, $State)
            $StorageAccount = $StorageAccounts | where {$_.name -Match $Name}
            if ($State) {
                $StorageAccount | Should Not BeNullOrEmpty
            } else {
                $StorageAccount | Should BeNullOrEmpty
            }
        }

        It "should use replication <Replication>" -TestCases $Matches {
            param($Name, $Replication)
            $StorageAccounts = 
                $target.resources | where {$_.type -Match 'storageAccounts'}
            $StorageAccount = $StorageAccounts | where {$_.name -Match $Name}
            $StorageAccount.sku.name | Should Match $Replication
        }
    }
}

Function Assert-PsArmNetworkSecurityGroup {
    Param(
        [parameter(Mandatory=$True,Position=0)]
        [System.Object] $Target,

        [parameter(Mandatory=$True,Position=1)]
        [System.Object] $Matches
    )
    Context "NetworkSecurityGroup" {
        $NSGs = @($target.resources | 
            where {$_.type -Eq 'Microsoft.Network/networkSecurityGroups'})
        It  "should include networkSecurityGroup <Name>" -TestCases $Matches {
            param($Name)
            @($NSGs | where {$_.name -Match $Name}).length | Should Be 1
        }

        It  "networkSecurityGroup <Name> should have <SecurityRuleCount> rules" -TestCases $Matches {
            param($Name,$SecurityRuleCount)
            $NSG = $NSGs | where {$_.name -Match $Name} 
            $NSG.properties.securityRules.count | Should Be $SecurityRuleCount
        }
    }
}

Function Assert-PsArmVNet {
    Param(
        [parameter(Mandatory=$True,Position=0)]
        [System.Object] $Target,

        [parameter(Mandatory=$True,Position=1)]
        [System.Object] $Matches
    )
    Context "VNet" {
        $VNets = @($target.resources | 
            where {$_.type -Eq 'Microsoft.Network/virtualNetworks'})
        It  "should include vNet <Name>" -TestCases $Matches {
            param($Name)
            @($VNets | where {$_.name -Match $Name}).length | Should Be 1
        }
        It "should use AddressPrefix <AddressPrefixes>" -TestCases $Matches {
            param($Name, $AddressPrefixes)
            $VNet = $VNets | where {$_.name -Match $Name}
            $Vnet.properties.addressspace.addressPrefixes |
                Should Be $AddressPrefixes
        }
        It "should have <SubnetCount> subnets" -TestCases $Matches {
            param($Name, $SubnetCount)
            $VNet = $VNets | where {$_.name -Match $Name}
            $Vnet.properties.subnets.count |
                Should Be $SubnetCount
        }
    }
}

Function Assert-PsArmRouteTable {
    Param(
        [parameter(Mandatory=$True,Position=0)]
        [System.Object] $Target,

        [parameter(Mandatory=$True,Position=1)]
        [System.Object] $Matches
    )
    Context "RouteTables" {
        $RouteTables = @($target.resources | 
            where {$_.type -Eq 'Microsoft.Network/routeTables'})
        It  "should include routeTable <Name>" -TestCases $Matches {
            param($Name)
            @($RouteTables| where {$_.name -Match $Name}).length | Should Be 1
        }
        It "should have <RouteCount> routes" -TestCases $Matches {
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
# 1. Export-AzureRMtarget is incomplete, and doesn't export VNet peerings. This is an API limitation
# 2. The vNet Peerings can be seen with say:
#      PS> $a = Get-AzureRMResource -ResourceGroupName 'DevVnetVA' -ResourceType 'Microsoft.Network/virtualNetworks' -ExpandProperties
#      PS> $a.Properties.virtualNetworkPeerings.properties
#    and they's appears as properties of a property
# 3. Directy querying the API for all resources with properties doesn't work. See https://github.com/Azure/azure-powershell/issues/2494
#    for Invoke-RestMethod with Azure, but the `resources` endpoint doesn't actually expand the list
# 4. VNetPeering is weird, they are modelled not as properties of a Vnet, but as resources associated with a Vnet.
#    See https://github.com/Azure/azure-quickstart-templates/blob/master/201-vnet-to-vnet-peering/azuredeploy.json#L44-L65


Function Get-PsArmActualResourceGroup([string] $ResourceGroupName) {
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

Export-ModuleMember -Function Assert-PSArmGroupTotal
Export-ModuleMember -Function Assert-PsArmGroupSummary
Export-ModuleMember -Function Assert-PsArmVM
Export-ModuleMember -Function Assert-PsArmStorage
Export-ModuleMember -Function Assert-PsArmNetworkSecurityGroup
Export-ModuleMember -Function Assert-PsArmVNet
Export-ModuleMember -Function Assert-PsArmRouteTable

Export-ModuleMember -Function Get-PsArmActualResourceGroup
Export-ModuleMember -Function Get-DesiredResourceGroup