$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\xSCOMHelper.psm1 -Verbose:$false -ErrorAction Stop

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source",

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential,

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[System.Boolean]
		$SuppressReboot,

		[System.Boolean]
		$ForceReboot,

		[System.String]
		$InstallPath,

		[parameter(Mandatory = $true)]
		[System.String]
		$ManagementGroupName,

		[parameter(Mandatory = $true)]
		[System.Boolean]
		$FirstManagementServer,

		[System.UInt16]
		$ManagementServicePort = 5723,

		[System.Management.Automation.PSCredential]
		$ActionAccount,

		[System.Management.Automation.PSCredential]
		$DASAccount,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$DataReader,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$DataWriter,

		[parameter(Mandatory = $true)]
		[System.String]
		$SqlServerInstance,

		[System.String]
		$DatabaseName = "OperationsManager",

		[System.UInt16]
		$DatabaseSize = 1000,

		[parameter(Mandatory = $true)]
		[System.String]
		$DwSqlServerInstance,

		[System.String]
		$DwDatabaseName = "OperationsManagerDW",

		[System.UInt16]
		$DwDatabaseSize = 1000,

		[System.Byte]
		$UseMicrosoftUpdate,

		[System.Byte]
		$SendCEIPReports,

		[ValidateSet("Never","Queued","Always")]
		[System.String]
		$EnableErrorReporting = "Never",

		[System.Byte]
		$SendODRReports
	)

    Import-Module $PSScriptRoot\..\..\xPDT.psm1
        
    if($SourceCredential)
    {
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Present"
    }
    $Path = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath "setup.exe"
    $Path = ResolvePath $Path
    $Version = (Get-Item -Path $Path).VersionInfo.ProductVersion
    if($SourceCredential)
    {
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Absent"
    }

    $IdentifyingNumber = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ManagementServer" -Name "IdentifyingNumber"
    Write-Verbose "IdentifyingNumber is $IdentifyingNumber"
    $InstallRegVersion = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ManagementServer" -Name "InstallRegVersion"
    Write-Verbose "InstallRegVersion is $InstallRegVersion"
    $RegVersion = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ManagementServer" -Name "RegVersion"
    Write-Verbose "RegVersion is $RegVersion"

    if($IdentifyingNumber -and (Get-WmiObject -Class Win32_Product | Where-Object {$_.IdentifyingNumber -eq $IdentifyingNumber}))
    {
        $InstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\$InstallRegVersion\Setup" -Name "InstallDirectory").InstallDirectory
        $MGs = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\$RegVersion\Server Management Groups"
        foreach($MG in $MGs)
        {
            $MGReg = $MG.Name.Replace("HKEY_LOCAL_MACHINE\","HKLM:")
            if ((Get-ItemProperty -Path $MGReg -Name "IsServer").IsServer -eq 1)
            {
                $ManagementGroupName = $MG.Name.Split("\")[$MG.Name.Split("\").Count - 1]
                $ManagementServicePort = (Get-ItemProperty -Path $MGReg -Name "Port").Port
            }
        }
        $ComputerName = $env:COMPUTERNAME + "." + (Get-WmiObject -Class Win32_ComputerSystem).Domain
        if(!(Get-Module -Name OperationsManager))
        {
            Import-Module "$InstallPath\PowerShell\OperationsManager"
        }
        if(Get-Module -Name OperationsManager)
        {
            $ManagementServer = Get-SCOMManagementServer -Name $ComputerName
		    $ActionAccountUsername = $ManagementServer.ActionAccountIdentity
            $DRA = (Get-SCOMRunAsAccount -Name "Data Warehouse Report Deployment Account")
		    $DataReaderUsername = $DRA.Domain + "\" + $DRA.UserName
            $DWA = (Get-SCOMRunAsAccount -Name "Data Warehouse Action Account")
		    $DataWriterUsername = $DWA.Domain + "\" + $DWA.UserName
        }
		$DASAccountUsername = (Get-WmiObject -Class Win32_Service | Where-Object {$_.Name -eq "OMSDK"}).StartName
		$SqlServerInstance = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\$RegVersion\Setup" -Name "DatabaseServerName").DatabaseServerName
		$DatabaseName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\$RegVersion\Setup" -Name "DatabaseName").DatabaseName
		$DwSqlServerInstance = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\$RegVersion\Setup" -Name "DataWarehouseDBServerName").DataWarehouseDBServerName
		$DwDatabaseName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\$RegVersion\Setup" -Name "DataWarehouseDBName").DataWarehouseDBName

        $returnValue = @{
		    Ensure = "Present"
		    SourcePath = $SourcePath
		    SourceFolder = $SourceFolder
		    InstallPath = $InstallPath
		    ManagementGroupName = $ManagementGroupName
		    ManagementServicePort = $ManagementServicePort
		    ActionAccountUsername = $ActionAccountUsername
		    DASAccountUsername = $DASAccountUsername
		    DataReaderUsername = $DataReaderUsername
		    DataWriterUsername = $DataWriterUsername
		    SqlServerInstance = $SqlServerInstance
		    DatabaseName = $DatabaseName
		    DwSqlServerInstance = $DwSqlServerInstance
		    DwDatabaseName = $DwDatabaseName
	    }
    }
    else
    {
	    $returnValue = @{
		    Ensure = "Absent"
		    SourcePath = $SourcePath
		    SourceFolder = $SourceFolder
	    }
    }
    
	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source",

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential,

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[System.Boolean]
		$SuppressReboot,

		[System.Boolean]
		$ForceReboot,

		[System.String]
		$InstallPath,

		[parameter(Mandatory = $true)]
		[System.String]
		$ManagementGroupName,

		[parameter(Mandatory = $true)]
		[System.Boolean]
		$FirstManagementServer,

		[System.UInt16]
		$ManagementServicePort = 5723,

		[System.Management.Automation.PSCredential]
		$ActionAccount,

		[System.Management.Automation.PSCredential]
		$DASAccount,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$DataReader,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$DataWriter,

		[parameter(Mandatory = $true)]
		[System.String]
		$SqlServerInstance,

		[System.String]
		$DatabaseName = "OperationsManager",

		[System.UInt16]
		$DatabaseSize = 1000,

		[parameter(Mandatory = $true)]
		[System.String]
		$DwSqlServerInstance,

		[System.String]
		$DwDatabaseName = "OperationsManagerDW",

		[System.UInt16]
		$DwDatabaseSize = 1000,

		[System.Byte]
		$UseMicrosoftUpdate,

		[System.Byte]
		$SendCEIPReports,

		[ValidateSet("Never","Queued","Always")]
		[System.String]
		$EnableErrorReporting = "Never",

		[System.Byte]
		$SendODRReports
	)

    Import-Module $PSScriptRoot\..\..\xPDT.psm1
        
    if($SourceCredential)
    {
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Present"
        $TempFolder = [IO.Path]::GetTempPath()
        & robocopy.exe (Join-Path -Path $SourcePath -ChildPath $SourceFolder) (Join-Path -Path $TempFolder -ChildPath $SourceFolder) /e
        $SourcePath = $TempFolder
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Absent"
    }
    $Path = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath "setup.exe"
    $Path = ResolvePath $Path
    $Version = (Get-Item -Path $Path).VersionInfo.ProductVersion

    $IdentifyingNumber = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ManagementServer" -Name "IdentifyingNumber"
    Write-Verbose "IdentifyingNumber is $IdentifyingNumber"
    $InstallRegVersion = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ManagementServer" -Name "InstallRegVersion"
    Write-Verbose "InstallRegVersion is $InstallRegVersion"

    switch($Ensure)
    {
        "Present"
        {
            # Set defaults, if they couldn't be set in param due to null configdata input
            if($ManagementServicePort -eq 0)
            {
                $ManagementServicePort = 5723
            }
            if($DatabaseSize -eq 0)
            {
                $DatabaseSize = 1000
            }
            if($DwDatabaseSize -eq 0)
            {
                $DwDatabaseSize = 1000
            }
            if($UseMicrosoftUpdate -ne 1)
            {
                $UseMicrosoftUpdate = 0
            }
            if($SendCEIPReports -ne 1)
            {
                $SendCEIPReports = 0
            }
            if($SendODRReports -ne 1)
            {
                $SendODRReports = 0
            }

            # Remove default instance name
            $SqlServerInstance = $SqlServerInstance.Replace("\MSSQLSERVER","")
            $DwSqlServerInstance = $DwSqlServerInstance.Replace("\MSSQLSERVER","")

            # Create install arguments
            $Arguments = "/silent /install /AcceptEndUserLicenseAgreement:1 /components:OMServer"
            $ArgumentVars = @(
                "InstallPath",
                "UseMicrosoftUpdate",
                "SendCEIPReports",
                "EnableErrorReporting",
                "SendODRReports",
                "ManagementServicePort",
                "SqlServerInstance",
                "DatabaseName"
            )
            if($FirstManagementServer)
            {
                $ArgumentVars += @(
                    "ManagementGroupName",
                    "DatabaseSize",
                    "DwSqlServerInstance",
                    "DwDatabaseName",
                    "DwDatabaseSize"
                )
            }
            foreach($ArgumentVar in $ArgumentVars)
            {
                if(!([String]::IsNullOrEmpty((Get-Variable -Name $ArgumentVar).Value)))
                {
                    $Arguments += " /$ArgumentVar`:" + [Environment]::ExpandEnvironmentVariables((Get-Variable -Name $ArgumentVar).Value)
                }
            }
            $AccountVars = @("ActionAccount","DASAccount","DataReader","DataWriter")
            foreach($AccountVar in $AccountVars)
            {
                if($PSBoundParameters.ContainsKey("ActionAccount") -or $PSBoundParameters.ContainsKey($AccountVar))
                {
                    $Arguments += " /$AccountVar`User:" + (Get-Variable -Name $AccountVar).Value.UserName
                    $Arguments += " /$AccountVar`Password:" + (Get-Variable -Name $AccountVar).Value.GetNetworkCredential().Password
                }
                else
                {
                    if(($AccountVar -eq "ActionAccount") -or ($AccountVar -eq "DASAccount"))
                    {
                        $Arguments += " /UseLocalSystem$AccountVar"
                    }
                }
            }
            
            # Replace sensitive values for verbose output
            $Log = $Arguments
            $LogVars = @("ActionAccount","DASAccount","DataReader","DataWriter")
            foreach($LogVar in $LogVars)
            {
                if((Get-Variable -Name $LogVar).Value -ne "")
                {
                    $Log = $Log.Replace((Get-Variable -Name $LogVar).Value.GetNetworkCredential().Password,"********")
                }
            }
        }
        "Absent"
        {
            # Create uninstall arguments
            $Arguments = "/silent /uninstall /components:OMServer"
            $Log = $Arguments
        }
    }

    Write-Verbose "Path: $Path"
    Write-Verbose "Arguments: $Log"
    
    $Process = StartWin32Process -Path $Path -Arguments $Arguments -Credential $SetupCredential -AsTask
    Write-Verbose $Process
    WaitForWin32ProcessEnd -Path $Path -Arguments $Arguments -Credential $SetupCredential

    # Additional first Management Server "Present" actions
    if(($Ensure -eq "Present") -and $FirstManagementServer -and (Get-WmiObject -Class Win32_Product | Where-Object {$_.IdentifyingNumber -eq $IdentifyingNumber}))
    {
        # Wait for Management Service
        $ErrorActionPreference = "SilentlyContinue"
        foreach($Port in @($ManagementServicePort,5724))
        {
            $MSOpen = $false
            while(!$MSOpen)
            {
                $Socket = New-Object Net.Sockets.TcpClient
                $Socket.Connect("localhost",$Port)
                if($Socket.Connected)
                {
                    $MSOpen = $true
                }
                else
                {
                    Write-Verbose "Wait for Management Server port $Port to open"
                    Start-Sleep 60
                }
                $Socket = $null
            }
        }
        $ErrorActionPreference = "Continue"
        # Allow MS to initialize
        Start-Sleep 300
    }

    if($ForceReboot -or ((Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue) -ne $null))
    {
	    if(!($SuppressReboot))
        {
            $global:DSCMachineStatus = 1
        }
        else
        {
            Write-Verbose "Suppressing reboot"
        }
    }

    if(!(Test-TargetResource @PSBoundParameters))
    {
        throw New-TerminatingError -ErrorType TestFailedAfterSet -ErrorCategory InvalidResult
    }
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source",

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential,

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[System.Boolean]
		$SuppressReboot,

		[System.Boolean]
		$ForceReboot,

		[System.String]
		$InstallPath,

		[parameter(Mandatory = $true)]
		[System.String]
		$ManagementGroupName,

		[parameter(Mandatory = $true)]
		[System.Boolean]
		$FirstManagementServer,

		[System.UInt16]
		$ManagementServicePort = 5723,

		[System.Management.Automation.PSCredential]
		$ActionAccount,

		[System.Management.Automation.PSCredential]
		$DASAccount,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$DataReader,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$DataWriter,

		[parameter(Mandatory = $true)]
		[System.String]
		$SqlServerInstance,

		[System.String]
		$DatabaseName = "OperationsManager",

		[System.UInt16]
		$DatabaseSize = 1000,

		[parameter(Mandatory = $true)]
		[System.String]
		$DwSqlServerInstance,

		[System.String]
		$DwDatabaseName = "OperationsManagerDW",

		[System.UInt16]
		$DwDatabaseSize = 1000,

		[System.Byte]
		$UseMicrosoftUpdate,

		[System.Byte]
		$SendCEIPReports,

		[ValidateSet("Never","Queued","Always")]
		[System.String]
		$EnableErrorReporting = "Never",

		[System.Byte]
		$SendODRReports
	)

	$result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)
	
	$result
}


Export-ModuleMember -Function *-TargetResource