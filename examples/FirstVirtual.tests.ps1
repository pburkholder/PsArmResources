<#   
Invoke-Pester -Test DevCICDPipelineVA 
#>

Import-Module "PsArmPester" -Force

$ResourceGroupName = 'MyRG'
$DeployScriptName  = 'FirstVirtual.ps1'
# next line finds the deploy script relative to this test script:
$DeployScript = Join-Path ($PSCommandPath | Split-Path -Parent) $DeployScriptName

# Set up test cases
$ResourceTotalTestCase = 5
$ResourceSummaryTestCases = @( 
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
}
