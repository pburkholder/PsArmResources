param( 
 [Parameter(Mandatory=$False)]
 [switch] $RunIt 
)
Import-Module "PsArmResources" -Force
Set-StrictMode -Version latest

$location = "EastUS"
# Initialize the Template
$template = New-PsArmTemplate

# Add the Vnet, with Subnets:
$vnet =  New-PsArmVnet -Name 'MyVNet' -AddressPrefixes '10.0.0.0/16' |
        Add-PsArmVnetSubnet -Name 'Front-End' -AddressPrefix '10.0.0.0/24' |
        Add-PsArmVnetSubnet -Name 'Back-End' -AddressPrefix '10.0.1.0/24'
$template.resources += $vnet

# Create the Web PublicIP object and add to template
#$WebPublicIP = New-PsArmPublicIpAddress -Name 'Web-Pip0' -AllocationMethod Dynamic -Location $location
$WebPublicIP = New-PsArmPublicIpAddress -Name 'Web-Pip0' -AllocationMethod Dynamic 
$template.resources += $WebPublicIP

# Create the Web NIC, with references to SubNet and PublicIP, and add to template
$PublicIpId = Get-PsArmResourceId -Resource $WebPublicIP
$FESubnetId = Get-PsArmVnetSubnetId -Vnet $vNet -SubnetName 'Front-End'
$WebNic = New-PsArmNetworkInterface -Name 'Web-Nic0' `
    -SubnetId $FESubnetId `
    -PublicIpAddressId $PublicIpId
$template.resources += $WebNic

$UserName='pburkholder'
$Password='3nap-sn0t-RR'

# Add the WebVM
$WebNicId = Get-PsArmResourceId -Resource $WebNic
$Template.resources += 
    New-PsArmVMConfig -VMName 'MyWebServer' -VMSize 'Standard_DS1_V2' |
        Set-PsArmVMOperatingSystem -Windows -ComputerName 'MyWebServer' `
            -AdminUserName $UserName -AdminPassword $Password -ProvisionVMAgent -EnableAutoUpdate |
        Set-PsArmVMSourceImage -Publisher MicrosoftWindowsServer `
            -Offer WindowsServer -Sku 2012-R2-Datacenter -Version "latest" |
        Add-PsArmVMNetworkInterface -Id $WebNicId |
        Set-PsArmVMOSDisk -Name $OSDiskName -CreateOption FromImage

$resourceGroupName = 'MyRG'
$templatefile = $resourceGroupName + '.json'
$deploymentName = $resourceGroupName + $(get-date -f yyyyMMddHHmmss)
Save-PsArmTemplate -Template $template -TemplateFile $templatefile
Test-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName `
    -TemplateFile $templatefile -Verbose

if ( $RunIt) {
  New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location -Force
  New-AzureRmResourceGroupDeployment -Name $deploymentName -Mode Complete -Force `
    -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -Verbose
}
