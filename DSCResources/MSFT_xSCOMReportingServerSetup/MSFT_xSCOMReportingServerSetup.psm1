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
        $ManagementServer,

		[parameter(Mandatory = $true)]
		[System.String]
        $SRSInstance,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$DataReader,

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

    $IdentifyingNumber = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ReportingServer" -Name "IdentifyingNumber"
    Write-Verbose "IdentifyingNumber is $IdentifyingNumber"
    $InstallRegVersion = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ReportingServer" -Name "InstallRegVersion"
    Write-Verbose "InstallRegVersion is $InstallRegVersion"
    $RegVersion = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ReportingServer" -Name "RegVersion"
    Write-Verbose "RegVersion is $RegVersion"

    if($IdentifyingNumber -and (Get-WmiObject -Class Win32_Product | Where-Object {$_.IdentifyingNumber -eq $IdentifyingNumber}))
    {
		$InstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\$InstallRegVersion\Setup" -Name "InstallDirectory").InstallDirectory
        $ManagementServer = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\$RegVersion\Reporting" -Name "DefaultSDKServiceMachine").DefaultSDKServiceMachine
        $SRSInstance = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Operations Manager\$RegVersion\Reporting" -Name "SRSInstance").SRSInstance
        $InstanceName = $SRSInstance.Split("\")[1]
        if(($InstanceName -eq "MSSQLSERVER") -or ($InstanceName -eq $null))
        {
            $RSServiceName = "ReportServer"
        }
        else
        {
            $RSServiceName = "ReportServer`$$InstanceName"
        }
        $DataReaderUsername = (Get-WmiObject -Class Win32_Service | Where-Object {$_.Name -eq $RSServiceName}).StartName

        $returnValue = @{
		    Ensure = "Present"
		    SourcePath = $SourcePath
		    SourceFolder = $SourceFolder
		    InstallPath = $InstallPath
            ManagementServer = $ManagementServer
            SRSInstance = $SRSInstance
            DataReaderUsername = $DataReaderUsername
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
        $ManagementServer,

		[parameter(Mandatory = $true)]
		[System.String]
        $SRSInstance,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$DataReader,

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

    $MSIdentifyingNumber = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ManagementServer" -Name "IdentifyingNumber"
    Write-Verbose "MSIdentifyingNumber is $MSIdentifyingNumber"

    switch($Ensure)
    {
        "Present"
        {
            # Set defaults, if they couldn't be set in param due to null configdata input
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
            $SRSInstance = $SRSInstance.Replace("\MSSQLSERVER","")

            # Create install arguments
            $Arguments = "/silent /install /AcceptEndUserLicenseAgreement:1 /components:OMReporting"
            $ArgumentVars = @(
                "InstallPath",
                "UseMicrosoftUpdate",
                "SendCEIPReports",
                "EnableErrorReporting",
                "SendODRReports"
            )
            if(!(Get-WmiObject -Class Win32_Product | Where-Object {$_.IdentifyingNumber -eq $MSIdentifyingNumber}))
            {
                $ArgumentVars += @("ManagementServer")
            }
            $ArgumentVars += @("SRSInstance")
            $Arguments += " /DataReaderUser:" + $DataReader.UserName
            $Arguments += " /DataReaderPassword:" + $DataReader.GetNetworkCredential().Password
            foreach($ArgumentVar in $ArgumentVars)
            {
                if(!([String]::IsNullOrEmpty((Get-Variable -Name $ArgumentVar).Value)))
                {
                    $Arguments += " /$ArgumentVar`:" + [Environment]::ExpandEnvironmentVariables((Get-Variable -Name $ArgumentVar).Value)
                }
            }

            # Replace sensitive values for verbose output
            $Log = $Arguments
            $LogVars = @("DataReader")
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
            $Arguments = "/silent /uninstall /components:OMReporting"
            $Log = $Arguments
        }
    }

    Write-Verbose "Path: $Path"
    Write-Verbose "Arguments: $Log"
    
    $Process = StartWin32Process -Path $Path -Arguments $Arguments -Credential $SetupCredential -AsTask
    Write-Verbose $Process
    WaitForWin32ProcessEnd -Path $Path -Arguments $Arguments -Credential $SetupCredential

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
        $ManagementServer,

		[parameter(Mandatory = $true)]
		[System.String]
        $SRSInstance,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$DataReader,

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