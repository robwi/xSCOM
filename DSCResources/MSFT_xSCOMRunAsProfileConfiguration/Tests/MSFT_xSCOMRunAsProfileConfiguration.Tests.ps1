<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCOMRunAsProfileConfiguration.psm1

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
            [System.String]$ComputerName
        )
    }

    function Get-SCOMRunAsAccount
    {
        param
        (
            [System.String]$Name
        )
    }

    function Get-SCOMRunAsProfile
    {
        param
        (
            [System.String]$Action
        )
    }

    function Set-SCOMRunAsProfile
    {
        [CmdletBinding()]
        param
        (
            $Name,
            $Profile,
            $Account,
            $Action,
            [Switch]$whatif,
            $Variable
        )
    }

    Export-ModuleMember -Function *
} | Import-Module -Force


$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCOMRunAsProfileConfiguration.psm1"
If (Test-Path $TestModule)
{
    Import-Module $TestModule -Force
}
Else
{
    Throw "Unable to find '$TestModule'"
}


Describe "MSFT_xSCOMRunAsProfileConfiguration Tests" {

    $global:DefaultDescription = "SCOM RunAsProfile Configuration Description"
    $global:InvokeCount = 0

    Context "Get Absent" {
        Mock New-SCOMManagementGroupConnection -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                return
        }
        Mock Get-SCOMRunAsAccount -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = "MockRunAsAccount";Description="RunAsAccount Discription"}

        }
        Mock Get-SCOMRunAsProfile -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = "MockRunAsProfile"}
        }
        Mock Set-SCOMRunAsProfile -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                return 
        }

        It "Get-TargetResource when SCOM RunAsAcccount is not in Profile" {

            $result = Get-TargetResource -Ensure "Present" -RunAsAccountName "MockRunAsAccount" -RunAsProfile "MockRunAsProfile" -Verbose
            $result.Ensure | Should Be "Absent"
            Assert-VerifiableMocks
        }
    }

    Context "Get Present" {
        Mock New-SCOMManagementGroupConnection -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                return
        }
        Mock Get-SCOMRunAsAccount -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = "MockRunAsAccount";Description="RunAsAccount Discription"}

        }
        Mock Get-SCOMRunAsProfile -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = "MockRunAsProfile"}
        }
        Mock Set-SCOMRunAsProfile -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                #$ErrorPreference = "SilentlyContinue"
                Write-Error "Run as account with context Object already exists for profile" -ErrorVariable addToProfile -ErrorAction SilentlyContinue
        }

        It "Get-TargetResource when RunAsAccount is in Profile" {

            $result = Get-TargetResource -Ensure "Present" -RunAsAccountName "MockRunAsAccount" -RunAsProfile "MockRunAsProfile" -Verbose
            $result.Ensure | Should Be "Present"
            Assert-VerifiableMocks
        }
    }

    Context "Test/Set Absent" {
        Mock New-SCOMManagementGroupConnection -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                return
        }
        Mock Get-SCOMRunAsAccount -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = "MockRunAsAccount";Description="RunAsAccount Discription"}

        }
        Mock Get-SCOMRunAsProfile -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = "MockRunAsProfile"}
        }
        Mock Set-SCOMRunAsProfile -ModuleName MSFT_xSCOMRunAsProfileConfiguration -Verifiable {
            $global:InvokeCount++
            if ($global:InvokeCount -ge 2 -And $whatif)
            {
                Write-Error "Run as account with context Object already exists for profile"
            }
            else
            {
                return 
            }
        }

        It "Set-TargetResource when SCOM RunAsAccount is not in Profile" {

            $result = Test-TargetResource -Ensure "Present" -RunAsAccountName "MockRunAsAccount" -RunAsProfile "MockRunAsProfile" -Verbose
            $result | Should Be $false

            $reults = Set-TargetResource -Ensure "Present" -RunAsAccountName "MockRunAsAccount" -RunAsProfile "MockRunAsProfile" -Verbose
            Assert-VerifiableMocks
        }
    }
}

Get-Module -Name operationsmanager | Remove-Module
#Get-Module $TestModule | Remove-Module
