<# 
This is the PsArmResource equivalent to the tutorial,
"Create your first virtual network" at
https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-get-started-vnet-subnet
#>

param( 
 [switch] $RunIt 
)
Import-Module "PsArmResources" -Force
Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

function New-StandardVM() {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory=$False)] [string] $VMName = "MyVM",
        [parameter(Mandatory=$False)] [string] $VMSize = "Standard_DS1_V2",
        [parameter(Mandatory=$True)] [string] $StorageName,
        [parameter(Mandatory=$True)] [string] $StorageID,
        [parameter(Mandatory=$True)] [string] $UserName,
        [parameter(Mandatory=$True)] [string] $Password,
        [parameter(Mandatory=$True)] [string] $NicID
    )
    
    $OsDiskName = "{0}_osdisk" -f $VMName
    $OsVhdUri =  "https://{0}.blob.core.windows.net/vhds/{1}.vhd" -f $StorageName,$OsDiskName
    New-PsArmVMConfig -VMName $VMName -VMSize $VMSize |
        Set-PsArmVMOperatingSystem -Windows -ComputerName $VMName `
            -AdminUserName $UserName -AdminPassword $Password -ProvisionVMAgent -EnableAutoUpdate |
        Set-PsArmVMSourceImage -Publisher MicrosoftWindowsServer `
            -Offer WindowsServer -Sku 2012-R2-Datacenter -Version "latest" |
        Add-PsArmVMNetworkInterface -Id $NicId |
        Set-PsArmVMOSDisk -Name $OsDiskName -Caching 'ReadWrite' `
            -CreateOption 'FromImage' -SourceImage $null `
            -VhdUri $OsVhdUri |
        Add-PsArmVmDependsOn -Id $StorageId
}

$location = "EastUS"
# Initialize the Template
$template = New-PsArmTemplate

# Add the Vnet, with Subnets:
$vNet =  New-PsArmVnet -Name 'MyVNet' -AddressPrefixes '10.0.0.0/16' |
        Add-PsArmVnetSubnet -Name 'Front-End' -AddressPrefix '10.0.0.0/24' |
        Add-PsArmVnetSubnet -Name 'Back-End' -AddressPrefix '10.0.1.0/24'
$template.resources += $vnet

# Create the Web PublicIP object and add to template
$WebPublicIP = New-PsArmPublicIpAddress -Name 'Web-Pip0' -AllocationMethod Dynamic 
$template.resources += $WebPublicIP

# Create the Web NIC, with references to SubNet and PublicIP, and add to template
$WebNic = New-PsArmNetworkInterface -Name 'Web-Nic0' `
    -SubnetId $vNet.SubnetId('Front-End') `
    -PublicIpAddressId $WebPublicIp.Id() 
$WebNic.dependsOn += $vNet.Id()
$template.resources += $WebNic

# VMs require storege
$Storage = New-PsArmStorageAccount -Name 'myrgdemostorage' -Tier 'Standard' `
        -Replication 'LRS' -Location $location
$template.resources += $Storage

$UserName='pburkholder'
$Password='3nap-sn0t-RR'
$WebVM = New-StandardVM -VMName 'MyWebServer' -UserName $UserName -Password $Password -NicId $WebNic.Id() -StorageName $Storage.name -StorageId $Storage.Id()
$Template.resources += $WebVM

# Add the DBVM - First the Nic:
$DbNic = New-PsArmNetworkInterface -Name 'Db-Nic0' `
    -SubnetId $vNet.SubnetId('Back-End')
$DbNic.dependsOn += $vNet.id()     
$template.resources += $DbNic

$DbVM = New-StandardVM -VMName 'MyDbServer' -UserName $UserName -Password $Password `
            -NicId $DbNic.Id() -StorageName $Storage.name -StorageID $Storage.Id()
$template.resources += $DbVM

# Template is complete, now deploy it:
$resourceGroupName = 'MyRG'
$templatefile = $resourceGroupName + '.json'
$deploymentName = $resourceGroupName + $(get-date -f yyyyMMddHHmmss)
Save-PsArmTemplate -Template $template -TemplateFile $templatefile

if ($RunIt) {
  New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location -Force
  New-AzureRmResourceGroupDeployment -Name $deploymentName -Mode Complete -Force `
    -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -Verbose
}
