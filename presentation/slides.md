<!-- 

This presentation is written for rendering by reveal-ck. It would not take much 
to rework for reveal-md. At this point I find the code syntax hightlighting works
better in reveal-ck.

View here: (?)
https://htmlpreview.github.io/?https://raw.githubusercontent.com/pburkholder/PsArmResources/master/presentation/slides/index.html#/>

reveal-ck: https://github.com/jedcn/reveal-ck 
reveal-md: https://github.com/webpro/reveal-md

-->

---

# Azure Code-Driven Infrastructure

* A word about Azure
* The way of Portal
* The way of JSON
* The way of POSH
* The way of Tests

---

<section data-background="https://secure.aadcdn.microsoftonline-p.com/ests/2.1.5898.9/content/images/default_signin_illustration.png"/>

# <br>
# <br>
# Azure

```note
Also: Microsoft cloud, but I like the name of the color
IaaS: 3 datacenters: DoD, usgovvirginia, usgoviowa
PaaS: 
  - SQL server as a service
  - Azure App Service - integration w/ VSTS, BB, GitHub
    - node
    - php
    - java
    - .Net
    - python
SaaS: The cash cow. O365 and AzureAD are winners.
    - offload authentication, DLP, Phishing detection

We'll just look at IaaS...
```

---

## Reference Architecture

<a href= "https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-get-started-vnet-subnet">
<img src="https://docs.microsoft.com/en-us/azure/virtual-network/media/virtual-network-get-started-vnet-subnet/vnet-diagram.png" alt="Create your first virtual network walkthrough" style="height: 100%;"/>
</a>

```note
This is the "Create your first virtual network walkthrough":
https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-get-started-vnet-subnet
```

---

<section data-background-image="images/portal.gif"/> 

# <br>
# <br>
# The Way of the Portal

```note
ffmpeg -i in.mov -s 600x400 -pix_fmt rgb24 -r 10 -f gif - | gifsicle --optimize=3 --delay=10 > out.gif
from 
https://gist.github.com/dergachev/4627207
```

---

<section data-background-image="images/json_way.png"/>

# <br>
# <br>
# [The way of JSON](https://gist.github.com/pburkholder/292d450f11d616d2f8af6f62f021ab6f#file-myrg-json)

---
# Implementation

```ps1
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location -Force
New-AzureRmResourceGroupDeployment -Name $deploymentName -Force `
    -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -Verbose `
    -Mode Complete 
```

***

# The Way of POSH

* Powershell passes objects, not strings
* [Mike Hsu's PsArmResource project](https://github.com/mikeehsu/PsArmResources)
* An Azure Resource Manager Template is then composable
  * Create a blank template
  * Define a PsArm object
  * Append to template
  * When ready, save template and deploy

---

Initialize the template
```ps1
$template = New-PsArmTemplate
```

---
Add the vNet with subnets
```ps1
$vNet =  New-PsArmVnet -Name 'MyVNet' -AddressPrefixes '10.0.0.0/16' |
        Add-PsArmVnetSubnet -Name 'Front-End' -AddressPrefix '10.0.0.0/24' |
        Add-PsArmVnetSubnet -Name 'Back-End' -AddressPrefix '10.0.1.0/24'
$template.resources += $vnet
```

---

Save it and deploy
```ps1
$resourceGroupName = 'MyRG'
$templatefile = $resourceGroupName + '.json'
$deploymentName = $resourceGroupName + $(get-date -f yyyyMMddHHmmss)

Save-PsArmTemplate -Template $template -TemplateFile $templatefile

New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location -Force
New-AzureRmResourceGroupDeployment -Name $deploymentName -Force `
    -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -Verbose `
    -Mode Complete 
```
---
Complete script for just the vnet
```ps1
$location = "EastUS"
$template = New-PsArmTemplate
$vNet =  New-PsArmVnet -Name 'MyVNet' -AddressPrefixes '10.0.0.0/16' |
        Add-PsArmVnetSubnet -Name 'Front-End' -AddressPrefix '10.0.0.0/24' |
        Add-PsArmVnetSubnet -Name 'Back-End' -AddressPrefix '10.0.1.0/24'

$template.resources += $vnet

$resourceGroupName = 'MyRG'
$templatefile = $resourceGroupName + '.json'
$deploymentName = $resourceGroupName + $(get-date -f yyyyMMddHHmmss)

Save-PsArmTemplate -Template $template -TemplateFile $templatefile

New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location -Force
New-AzureRmResourceGroupDeployment -Name $deploymentName -Mode Complete -Force `
    -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -Verbose
```
---

# VMs
* A webVM with a public IP
* A DBVM 
* Both reference Nics and Storage created elsewhere in script
---

```ps1
$WebVM = New-PsArmVMConfig -VMName 'MyWebServer' -VMSize 'Standard_DS1_V2' |
        Set-PsArmVMOperatingSystem -Windows -ComputerName 'MyWebServer' `
            -AdminUserName $UserName -AdminPassword $Password -ProvisionVMAgent -EnableAutoUpdate |
        Set-PsArmVMSourceImage -Publisher MicrosoftWindowsServer `
            -Offer WindowsServer -Sku 2012-R2-Datacenter -Version "latest" |
        Add-PsArmVMNetworkInterface -Id $WebNic.Id() |
        Set-PsArmVMOSDisk -Name 'MyWebServer_osdisk' -Caching 'ReadWrite' `
            -CreateOption 'FromImage' -SourceImage $null `
            -VhdUri 'https://myrgdemostorage.blob.core.windows.net/vhds/MyWebServer_osdisk.vhd' |
        Add-PsArmVmDependsOn -Id $Storage.Id()
```
---
```ps1
$DbVM = New-PsArmVMConfig -VMName 'MyDbServer' -VMSize 'Standard_DS1_V2' |
        Set-PsArmVMOperatingSystem -Windows -ComputerName 'MyDbServer' `
            -AdminUserName $UserName -AdminPassword $Password -ProvisionVMAgent -EnableAutoUpdate |
        Set-PsArmVMSourceImage -Publisher MicrosoftWindowsServer `
            -Offer WindowsServer -Sku 2012-R2-Datacenter -Version "latest" |
        Add-PsArmVMNetworkInterface -Id $DbNic.Id() |
        Set-PsArmVMOSDisk -Name 'MyDbServer_osdisk' -Caching 'ReadWrite' `
            -CreateOption 'FromImage' -SourceImage $null `
            -VhdUri 'https://myrgdemostorage.blob.core.windows.net/vhds/MyDbServer_osdisk.vhd' |
        Add-PsArmVmDependsOn -Id $Storage.Id()
```
---

# Practice DRY

---

```ps1
function New-StandardVM() {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory=$False)] [string] $VMName = "MyVM",
        [parameter(Mandatory=$False)] [string] $VMSize = "Standard_DS1_V2",
        [parameter(Mandatory=$True)] $Storage,
        [parameter(Mandatory=$True)] [string] $UserName,
        [parameter(Mandatory=$True)] [string] $Password,
        [parameter(Mandatory=$True)] [string] $NicID
    )
    
    $OsDiskName = "{0}_osdisk" -f $VMName
    $OsVhdUri =  "https://{0}.blob.core.windows.net/vhds/{1}.vhd" -f $Storage.name,$OsDiskName
    New-PsArmVMConfig -VMName $VMName -VMSize $VMSize |
        Set-PsArmVMOperatingSystem -Windows -ComputerName $VMName `
            -AdminUserName $UserName -AdminPassword $Password -ProvisionVMAgent -EnableAutoUpdate |
        Set-PsArmVMSourceImage -Publisher MicrosoftWindowsServer `
            -Offer WindowsServer -Sku 2012-R2-Datacenter -Version "latest" |
        Add-PsArmVMNetworkInterface -Id $NicId |
        Set-PsArmVMOSDisk -Name $OsDiskName -Caching 'ReadWrite' `
            -CreateOption 'FromImage' -SourceImage $null `
            -VhdUri $OsVhdUri |
        Add-PsArmVmDependsOn -Id $Storage.Id()
}
```
---
```ps1
$WebVM = New-StandardVM -VMName 'MyWebServer' -UserName $UserName -Password $Password `
    -NicId $WebNic.Id() -Storage $Storage

$DbVM = New-StandardVM -VMName 'MyDbServer' -UserName $UserName -Password $Password `
    -NicId $DbNic.Id() -Storage $Storage
```

---

# [Complete Template Script](https://github.com/pburkholder/PsArmResources/blob/preso/examples/FirstVirtualDRY.ps1)

***
***

# The Way of Testing

1. Will my script produce the _desired_ outcome?
2. Does my _actual_ resource group match my specification?

---

# Test the desired state

```ps1
Invoke-Pester -Test MyRG -Tag Desired
Describing MyRG
   Context Resource Group Total
    [+] should have 7 total resources 114ms
   Context Overall Group
    [+] should have 1 Microsoft.Network/virtualNetworks 36ms
    [+] should have 1 Microsoft.Network/publicIPAddresses 18ms
    [+] should have 2 Microsoft.Network/networkInterfaces 20ms
    [+] should have 1 Microsoft.Storage/storageAccounts 19ms
    [+] should have 2 Microsoft.Compute/virtualMachines 15ms
   Context VMs
    [+] desired should include VM named MyWebServer and sized Standard_DS1_V2 39ms
    [+] desired should include VM named MyDBServer and sized Standard_DS1_V2 22ms
   Context StorageAccounts
    [+] should True include storage account myrgdemostorage 39ms
    [+] should use replication LRS 30ms
   Context VNet
    [+] should include vNet myvnet 39ms
    [+] should use AddressPrefix <AddressPrefixes> 18ms
    [+] should have 2 subnets 19ms
Tests completed in 434ms
Passed: 13 Failed: 0 Skipped: 0 Pending: 0 Inconclusive: 0
```

---

```ps1

<#   
Invoke-Pester -Test MyRG
#>

Import-Module "PsArmPester" -Force

$ResourceGroupName = 'MyRG'
$DeployScriptName  = 'FirstVirtualDRY.ps1'
# next line finds the deploy script relative to this test script:
$DeployScript = Join-Path ($PSCommandPath | Split-Path -Parent) $DeployScriptName

# Set up test cases
$ResourceTotalTestCase = 7
$ResourceSummaryTestCases = @( 
    @{
        Resource = "Microsoft.Network/virtualNetworks"
        Expected = 1
    },

    @{
        Resource = "Microsoft.Network/publicIPAddresses"
        Expected = 1
    },

    @{
        Resource = "Microsoft.Network/networkInterfaces"
        Expected = 2
    },
    @{
        Resource = "Microsoft.Storage/storageAccounts"
        Expected = 1
    },
    @{
        Resource = 'Microsoft.Compute/virtualMachines'
        Expected = 2
    }
) 

$VMTestCases = @(
    @{
        Name = 'MyWebServer'
        VmSize = 'Standard_DS1_V2'
    },
    @{
        Name = 'MyDBServer'
        VmSize = 'Standard_DS1_V2'
    }
) 

$StorageCases = @(
    @{
        Name = 'myrgdemostorage'
        State = $true
        Replication = 'LRS'
    }
)

$vNetCases = @(
    @{
        Name = 'myvnet'
        SubnetCount = 2
        AddressPrefix = '10.0.0.0/16'
    }
)

Describe $ResourceGroupName -Tag Actual {
    $actual = Get-ActualResourceGroup $ResourceGroupName
    Audit-ResourceGroupTotal $actual $ResourceTotalTestCase
    Audit-ResourceGroupSummary $actual $ResourceSummaryTestCases
    Audit-ResourceGroupVMs $actual $VMTestCases
    Audit-ResourceGroupStorage $actual $StorageCases
}

Describe $ResourceGroupName -Tag Desired  {
    $desired = Get-DesiredResourceGroup $ResourceGroupName $DeployScript
    Audit-ResourceGroupTotal $desired $ResourceTotalTestCase
    Audit-ResourceGroupSummary $desired $ResourceSummaryTestCases
    Audit-ResourceGroupVMs $desired $VMTestCases
    Audit-ResourceGroupStorage $desired $StorageCases
    Audit-AzureRMVnet $desired $vNetCases
}
```

---

# Test Actual State

```ps1
Invoke-Pester -Test MyRG -Tag Desired
```

---


# Reconcile
- Update tests to DS4_V2
- Test Desired State Fail
- Update code
- Test Desired State Passes
- Update actuality
- Test Actual State

***
***

# EndNotes

---

# Randomize the Resource Group

```ps1
$ResourceGroupName = "MyRG"
$VMName = "MyDBServer"
$NewVMSize = "Standard_DS2_V2"
 
$vm = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName
$vm.HardwareProfile.vmSize = $NewVMSize
Update-AzureRmVM -ResourceGroupName $ResourceGroupName -VM $vm
```

---
PowerShell AzureRM on OsX or Linux is very limited at this time because the underlying .NET libraries are pretty limited. You _can_ login and do some basic calls against resources, but not much else. See for more: https://github.com/Azure/azure-powershell/issues/3178
and https://github.com/Azure/azure-powershell/issues/3746 - June 2017 milestone.


```bash
brew cask install powershell
powershell
```

```
# Get the AzureRM .NET core 0.3.4 preview
Install-Module AzureRM.NetCore.Preview
Import-Module AzureRM.NetCore.Preview
Install-Module AzureRM -MinimumVersion 3.8.0 -Scope CurrentUser
```
