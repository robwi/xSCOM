<###################################################
 #                                                 #
 #  Copyright (c) Microsoft. All rights reserved.  #
 #                                                 #
 ###################################################>

 <#
.SYNOPSIS
    Pester Tests for MSFT_xSCOMDatabaseUpdate.psm1

.DESCRIPTION
    See Pester Wiki at https://github.com/pester/Pester/wiki
    Download Module from https://github.com/pester/Pester to run tests
#>

Get-Module -Name sqlps | Remove-Module
New-Module -Name sqlps -ScriptBlock `
{
    # Create skeleton of needed functions/parameters so they can be Mocked in the tests
    function Invoke-sqlcmd
    {
        param
        (
            [Parameter(Position=0, Mandatory=$True)]
            [System.String]$Database,
            [Parameter(Position=1, Mandatory=$True)]
            [System.String]$ServerInstance,
            [Parameter(ParameterSetName='fromfile')]
            [System.String]$InputFile,
            [Parameter(ParameterSetName='fromquery')]
            [System.String]$Query,
            [Int]$QueryTimeout
        )
    }
    Export-ModuleMember -Function *
} | Import-Module -Force


New-Module -Name CommonFunctions -ScriptBlock `
{
    function Invoke-command {
        param(
            [System.String] $ComputerName, 
            [System.Management.Automation.PSCredential]$Credential, 
            [ScriptBlock]$ScriptBlock, 
            [System.String[]]$ArgumentList
            )
    }

    function Get-ItemProperty {
        param(
            [System.String]$path,
            [System.String]$Name
            )
    }
    
    function GetxPDTVariable {
        param(
            [System.String] $Compontent,
            [System.String] $Version,
            [System.String] $Role,
            [System.String] $Name
            )
    }
        
    function ResolvePath {
        param(
            [System.String] $path
        )
    }

    function Import-Module {
        param(
        [System.String]$path
        )
    }

    function NetUse {
        param(
        [System.String]$SourcePath,
        [System.Management.Automation.PSCredential]$Credential, 
        [System.String]$Ensure
        )
    }

    function robocopy.exe {
        param(
            [System.String] $Source,
            [System.String] $Destination,
            [System.String] $addional
        )
    }

    function Set-ItemProperty {
            param(
            [System.String] $Path,
            [System.String] $Name,
            [System.String] $Value
        )
    }

    Export-ModuleMember -Function *
} | Import-Module


$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestModule = "$here\..\MSFT_xSCOMDatabaseUpdate.psm1"
If (Test-Path $TestModule)
{
    Import-Module $TestModule -Force
}
Else
{
    Throw "Unable to find '$TestModule'"
}


Describe "MSFT_xSCOMDatabaseUpdate Tests" {

    $global:DefaultDescription = "SCOM Database Update Description"
    $global:InvokeCount = 0

    Context "Get Absent" {
        Mock Import-Module -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                return
        }
        Mock Invoke-Command -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                return "7.1.10226.0"
        }
        Mock GetxPDTVariable -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                
                if ($Name -eq "IdentifyingNumber")
                {
                    return "UR5"
                }
                else
                {
                    return "DatabaseUpdate.sql"
                }
        }
        Mock Get-ItemProperty -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                return $null
        }

        It "Get-TargetResource when SCOM DB Update has not been applied" {
            
            $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
            $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

            $result = Get-TargetResource -Ensure "Absent" -SourcePath "Source" -SourceFolder "C:\test\folder" -SourceCredential $mycreds -SqlCredential $mycreds -SqlServerInstance "test\sql01" -DatabaseName "OperationsManager" -ConfigSetting "DBUpdate" -Verbose
            $result.Ensure | Should Be "Absent"
            $result.SourcePath | Should Be "Source"
            $result.SourceFolder | Should Be "C:\test\folder"
            Assert-VerifiableMocks
        }
    }

    Context "Get Present" {
        Mock Import-Module -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                return
        }
        Mock Invoke-Command -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                return "7.1.10226.0"
        }
        Mock GetxPDTVariable -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                
                if ($Name -eq "IdentifyingNumber")
                {
                    return "UR5"
                }
                else
                {
                    return "DatabaseUpdate.sql"
                }
        }
        Mock Get-ItemProperty -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                $result = New-Object PSObject
                Add-Member -InputObject $result -MemberType NoteProperty -Name $ConfigSetting -Value UR5
                return $result
        }

        It "Get-TargetResource when SCOM DB Update has been applied" {

            $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
            $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

            $result = Get-TargetResource -Ensure "Present" -SourcePath "Source" -SourceFolder "C:\test\folder" -SourceCredential $mycreds -SqlCredential $mycreds -SqlServerInstance "test\sql01" -DatabaseName "OperationsManager" -ConfigSetting "DBUpdate" -Verbose
            $result.Ensure | Should Be "Present"
            $result.SourcePath | Should Be "Source"
            $result.SourceFolder | Should Be "C:\test\folder"
            Assert-VerifiableMocks
        }
    }

    Context "Test/Set Absent" {
        Mock Import-Module -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                return
        }
        Mock Invoke-Command -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
            if ($global:InvokeCount -eq 2)
            {
                $result = $true
            }
            else
            {
                $result = "7.1.10226.0"
            }
            $global:InvokeCount++
            return $result
        }
        Mock GetxPDTVariable -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
            if ($Name -eq "IdentifyingNumber")
            {
                return "UR5"
            }
            else
            {
                return "DatabaseUpdate.sql"
            }                
        }
        Mock Get-ItemProperty -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                $result = New-Object PSObject
                if ($global:InvokeCount -eq 4)
                {
                    Add-Member -InputObject $result -MemberType NoteProperty -Name $ConfigSetting -Value UR5
                }
                return $result
        }
        Mock NetUse -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
            return
        }
        Mock robocopy.exe -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
            return
        }

        Mock ResolvePath -ModuleName MSFT_xSCOMDatabaseUpdate -Verifiable {
                return "C:\test\path"
        }

        It "Set-TargetResource when SCOM DB Update hasn't been applied" {
            
            $secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
            $mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)
            $result = Test-TargetResource -Ensure "Present" -SourcePath "Source" -SourceFolder "C:\test\folder" -SourceCredential $mycreds -SqlCredential $mycreds -SqlServerInstance "test\sql01" -DatabaseName "OperationsManager" -ConfigSetting "DBUpdate" -Verbose
            $result | Should Be $false

            Set-TargetResource -Ensure "Present" -SourcePath "Source" -SourceFolder "C:\test\folder" -SourceCredential $mycreds -SqlCredential $mycreds -SqlServerInstance "test\sql01" -DatabaseName "OperationsManager" -ConfigSetting "DBUpdate" -Verbose
            
            $result = Test-TargetResource -Ensure "Present" -SourcePath "Source" -SourceFolder "C:\test\folder" -SourceCredential $mycreds -SqlCredential $mycreds -SqlServerInstance "test\sql01" -DatabaseName "OperationsManager" -ConfigSetting "DBUpdate" -Verbose
            $result | Should Be $true

            Assert-VerifiableMocks
        }
    }
}

Get-Module -Name sqlps | Remove-Module
Get-Module -Name CommonFunctions | Remove-Module
Get-Module $TestModule | Remove-Module
