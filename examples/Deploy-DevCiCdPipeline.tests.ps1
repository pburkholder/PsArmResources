<#   
Invoke-Pester -Test DevCICDPipelineVA 
#>

Import-Module "AzureRMAudit" -Force

$ResourceGroupName = 'DevCICDPipelineVA'
$DeployScriptName  = 'Deploy-DevCiCdPipeline.ps1'
# next line finds the deploy script relative to this test script:
$DeployScript = Join-Path ($PSCommandPath | Split-Path -Parent) $DeployScriptName

# Set up test cases
$ResourceTotalTestCase = 22
$ResourceSummaryTestCases = @( 
    @{
        Resource = "Microsoft.Network/networkInterfaces"
        Expected = 10
    },
    @{
        Resource = "Microsoft.Storage/storageAccounts"
        Expected = 2
    },
    @{
        Resource = 'Microsoft.Compute/virtualMachines'
        Expected = 10
    }
) 

$VMTestCases = @(
    @{
        Name = 'CAZGDSO903D'
        VmSize = 'Standard_D3_V2'
    },
    @{
        Name = 'CAZGDSO904D'
        VmSize = 'Standard_D4_V2'
    },
    @{
        Name = 'CAZGDSO905D'
        VmSize = 'Standard_D2_V2'
    },
    @{
        Name = 'CAZGDSO906D'
        VmSize = 'Standard_D4_V2'
    },
    @{
        Name = 'CAZGDSO907D'
        VmSize = 'Standard_D2_V2'
    },
    @{
        Name = 'CAZGDSO912D'
        VmSize = 'Standard_D2_V2'
    },
    @{
        Name = 'CAZGDSO913D'
        VmSize = 'Standard_D2_V2'
    },
    @{
        Name = 'CAZGDSO915D'
        VmSize = 'Standard_D2'
        Role = 'SonarQube'
    },
    @{
        Name = 'CAZGDSO916D'
        VmSize = 'Standard_DS2'
        Role = 'Nexus'
    },
    @{
        Name = 'CAZGSQL908D'
        VmSize = 'Standard_D2'
        Role = 'SonarQubeDB'
    }
)

$StorageCases = @(
    @{
        Name = 'devcicdva'
        State = $true
        Replication = 'RAGRS'
    },
    @{
        Name = 'managedbackupstorage'
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
