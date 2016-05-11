<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCOMRunAsAcccount.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

Get-Module -Name operationsmanager | Remove-Module
New-Module -Name operationsmanager -ScriptBlock `
{
    # Create skeleton of needed functions/parameters so they can be Mocked in the tests
    function New-SCOMManagementGroupConnection
    {
        param
        (
            [Parameter(Position=0, Mandatory=$True)]
            [System.String]$ComputerName
        )
    }

    function Get-SCOMRunAsAccount
    {
        param
        (
            [Parameter(Position=0, Mandatory=$True)]
            [System.String]$Name
        )
    }

    function Add-SCOMRunAsAccount
    {
        param
        (
            #[Parameter(Position=0, Mandatory=$True)]
            [System.String]$Name,
            #[Parameter(Position=1, Mandatory=$True)]
            [System.Management.Automation.PSCredential]$RunAsCredential,
            #[Parameter(Position=2, Mandatory=$True)]
            [System.String]$Description
        )
    }

    Export-ModuleMember -Function *
} | Import-Module -Force


$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCOMRunAsAccount.psm1"
If (Test-Path $TestModule)
{
    Import-Module $TestModule -Force
}
Else
{
    Throw "Unable to find '$TestModule'"
}


Describe "MSFT_xSCOMRunAsAccount Tests" {

    $global:DefaultDescription = "SCOM RunAsAccount Description"
    $global:InvokeCount = 0

    Context "Get Absent" {
        Mock New-SCOMManagementGroupConnection -ModuleName MSFT_xSCOMRunAsAccount -Verifiable {
                return
        }
        Mock Get-SCOMRunAsAccount -ModuleName MSFT_xSCOMRunAsAccount -Verifiable {
                return $null

        }

        It "Get-TargetResource when SCOM RunAsAcccount is not present" {
            $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
            $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

            $result = Get-TargetResource -Ensure Present -RunAsAccountName "MockRunAsAccount" -RunAscredential $mycreds -Verbose
            $result.Ensure | Should Be "Absent"
            $result.Description | Should Be ""
            Assert-VerifiableMocks
        }
    }

    Context "Get Present" {
        Mock New-SCOMManagementGroupConnection -ModuleName MSFT_xSCOMRunAsAccount -Verifiable {
                return
        }
        Mock Get-SCOMRunAsAccount -ModuleName MSFT_xSCOMRunAsAccount -Verifiable {
                $result = New-Object -TypeName psobject -Property @{Name = "MockRunAsAccount";Description="Mock RunAsAccount Description"}
                return $result
        }

        It "Get-TargetResource when RunAsAccount is already present" {
            $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
            $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

            $result = Get-TargetResource -Ensure Present -RunAsAccountName "MockRunAsAccount" -RunAscredential $mycreds -Verbose
            $result.Ensure | Should Be "Present"
            $result.Description | Should Be "Mock RunAsAccount Description"
            Assert-VerifiableMocks
        }
    }

    Context "Test/Set Absent" {
        Mock New-SCOMManagementGroupConnection -ModuleName MSFT_xSCOMRunAsAccount -Verifiable {
                return
        }
        Mock Get-SCOMRunAsAccount -ModuleName MSFT_xSCOMRunAsAccount -Verifiable {
            if ($global:InvokeCount -ge 1)
            {
                $returnValue = New-Object -TypeName psobject -Property @{Name = "MockRunAsAccount";Description="Mock RunAsAccount Description"}
            }
            else
            {
                $returnValue = $null
            }
            $global:InvokeCount++
            $returnValue
        }
        Mock Add-SCOMRunAsAccount -ModuleName MSFT_xSCOMRunAsAccount -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = "MockRunAsAccount";Description="Mock RunAsAccount Description"}
        }

        It "Set-TargetResource when SCOM RunAsAccount is not present" {

            $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
            $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

            $result = Test-TargetResource -Ensure Present -RunAsAccountName "MockRunAsAccount"-RunAscredential $mycreds -Verbose
            $result | Should Be $false

            $reults = Set-TargetResource -Ensure Present -RunAsAccountName "MockRunAsAccount" -RunAscredential $mycreds -Description "Mock RunAsAccount Description" -Verbose

            $result = Test-TargetResource -Ensure Present -RunAsAccountName "MockRunAsAccount" -RunAscredential $mycreds -Verbose
            $result | Should Be $true

            Assert-VerifiableMocks
        }
    }
}

Get-Module -Name operationsmanager | Remove-Module
#Get-Module $TestModule| Remove-Module 
