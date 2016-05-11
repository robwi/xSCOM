<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCOMRunTask.psm1

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
            $computername
        )
    }

    function Get-SCOMTask
    {
        param
        (
            [Parameter(Position=0, Mandatory=$True)]
            [System.String]$Name
        )
    }

    function Add-SCOMClass
    {
        param
        (
            $Name
        )
    }

    function Get-SCOMClass
    {
        param
        (
            $Name
        )
    }

    function Start-SCOMTask
    {
        param
        (
            [Parameter(Position=0, Mandatory=$True)]
            [System.Object]$Task,
            [Parameter(Position=1, Mandatory=$True)]
            [System.Object]$Instance
        )
    }

    function Get-SCOMClassInstance 
    {
        param
        (
            [System.Object]$Class
        )
    }

    function Get-SCOMTaskResult
    {
        param
        (
            $Task
        )
    }

    Export-ModuleMember -Function *
} | Import-Module -Force

Get-Module -Name CommonFucntions | Remove-Module
New-Module -Name CommonFunctions -ScriptBlock `
{
    function ConnectSCOMManagementGroup
    {

    }

    Export-ModuleMember -Function *
} | Import-Module -Force


$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCOMRunTask.psm1"
If (Test-Path $TestModule)
{
    Import-Module $TestModule -force
}
Else
{
    Throw "Unable to find '$TestModule'"
}

Describe "MSFT_xSCOMRunTask Tests" {

    $global:DefaultDescription = "SCOM RunTask Description"
    $global:TaskName = "MockTaskName"
    $global:ClassName = "MockClassName"

    Context "Get Absent" {
        Mock New-SCOMManagementGroupConnection -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return
        }
        Mock Get-SCOMTask -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = $global:TaskName}
        }
        Mock Get-SCOMClass -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = $global:ClassName}
        }
        Mock Get-SCOMTaskResult -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return New-Object -TypeName psobject -Property @{TimeStarted = (get-date).AddDays(-2).ToUniversalTime()}
        }

        It "Get-TargetResource when SCOM RunAsAcccount is not present" {

            $result = Get-TargetResource -Ensure "Present" -TaskName $global:TaskName -ClassName $global:ClassName-Verbose
            $result.Ensure | Should Be "Absent"
            Assert-VerifiableMocks
        }
    }

    Context "Get Present" {
        Mock New-SCOMManagementGroupConnection -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return
        }
        Mock Get-SCOMTask -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = $global:TaskName}
        }
        Mock Get-SCOMTaskResult -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return New-Object -TypeName psobject -Property @{TimeStarted = (get-date).ToUniversalTime()}
        }
        Mock Get-SCOMClass -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = $global:ClassName}
        }
        It "Get-TargetResource when RunAsAccount is already present" {

            $result = Get-TargetResource -Ensure "Present" -TaskName $global:TaskName -ClassName $global:ClassName -Verbose
            $result.Ensure | Should Be "Present"
            Assert-VerifiableMocks
        }
    }

    Context "Test/Set Absent" {
        Mock ConnectSCOMManagementGroup -ModuleName MSFT_xSCOMRunTask -Verifiable {
            return $true
        }
        Mock Get-SCOMTask -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = $global:TaskName}
        }
        Mock Get-SCOMClass -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return New-Object -TypeName psobject -Property @{Name = $global:ClassName}
        }
        Mock Get-SCOMClassInstance -ModuleName MSFT_xSCOMRunTask -Verifiable {
                #$out = @()
                return New-Object -TypeName psobject -Property @{Name = "MockClassInstanceName";Healthstate = "Success"}
                #return $out
        }
        Mock Start-SCOMTask -ModuleName MSFT_xSCOMRunTask -Verifiable {
                return $true
        }
        It "Set-TargetResource SCOMRunTask" {

            $result = Test-TargetResource -Ensure "Present" -TaskName $global:TaskName -ClassName $global:ClassName -Verbose
            $result | Should Be $false

            Set-TargetResource -Ensure "Present" -TaskName $global:TaskName -ClassName $global:ClassName -Verbose

            Assert-VerifiableMocks
        }
    }
}

Get-Module -Name operationsmanager | Remove-Module
Get-Module -Name CommonFunctions | Remove-Module
