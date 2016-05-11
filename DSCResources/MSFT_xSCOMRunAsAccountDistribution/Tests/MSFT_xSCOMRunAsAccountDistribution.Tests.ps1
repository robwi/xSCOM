<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCOMRunAsAccountDistribution.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>
New-Module -Name CommonFunctions -ScriptBlock `
{
    function Invoke-command {
        param
        (
            [System.String] $ComputerName, 
            [ScriptBlock]$ScriptBlock
        )
    }

    Export-ModuleMember -Function *
} | Import-Module -Force

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCOMRunAsAccountDistribution.psm1"
If (Test-Path $TestModule)
{
    Import-Module $TestModule -Force
}
Else
{
    Throw "Unable to find '$TestModule'"
}


Describe "MSFT_xSCOMRunAsAccount Tests" {

    $global:DefaultDescription = "SCOM RunAsAccountDistribution Description"
    $global:InvokeCount = 0

    Context "Get Absent" {
        Mock Invoke-Command -ModuleName MSFT_xSCOMRunAsAccountDistribution -Verifiable {
                return $false
        }

        It "Get-TargetResource when SCOM RunAsAcccount is not in Distribution" {

            $result = Get-TargetResource -Ensure "Present" -RunAsAccountName "MockRunAsAccount" -SCOMManagementServer "MockSCOM" -Verbose
            $result.Ensure | Should Be "Absent"
            Assert-VerifiableMocks
        }
    }

    Context "Get Present" {
        Mock Invoke-Command -ModuleName MSFT_xSCOMRunAsAccountDistribution -Verifiable {
                return $true
        }
        
        It "Get-TargetResource when SCOM RunAsAcccount is already in Distribution" {

            $result = Get-TargetResource -Ensure "Present" -RunAsAccountName "MockRunAsAccount" -SCOMManagementServer "MockSCOM" -Verbose
            $result.Ensure | Should Be "Present"
            Assert-VerifiableMocks
        }
    }

    Context "Test/Set Absent" {
        Mock Invoke-Command -ModuleName MSFT_xSCOMRunAsAccountDistribution -Verifiable {
                $global:InvokeCount++
                if ($global:InvokeCount -gt 1)
                {
                    return $true
                }
                else
                {
                    return $false
                }
                
        }

        It "Set-TargetResource when SCOM RunAsAccount is not in Distribution" {

            $result = Test-TargetResource -Ensure "Present" -RunAsAccountName "MockRunAsAccount" -SCOMManagementServer "MockSCOM" -Verbose
            $result| Should Be $false

            Set-TargetResource -Ensure "Present" -RunAsAccountName "MockRunAsAccount" -SCOMManagementServer "MockSCOM" -Verbose
            Assert-VerifiableMocks
        }
    }
}

Get-Module -Name operationsmanager | Remove-Module
#Get-Module $TestModule | Remove-Module
