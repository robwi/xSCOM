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

		[System.String]
	    $WebSiteName = "Default Web Site",

		[ValidateSet("Mixed","Network")]
		[System.String]
	    $WebConsoleAuthorizationMode = "Mixed",

	    [System.Boolean]
        $WebConsoleUseSSL = $false,

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

    $IdentifyingNumber = GetxPDTVariable -Component "SCOM" -Version $Version -Role "WebConsoleServer" -Name "IdentifyingNumber"
    Write-Verbose "IdentifyingNumber is $IdentifyingNumber"
    $InstallRegVersion = GetxPDTVariable -Component "SCOM" -Version $Version -Role "WebConsoleServer" -Name "InstallRegVersion"
    Write-Verbose "InstallRegVersion is $InstallRegVersion"

    if($IdentifyingNumber -and (Get-WmiObject -Class Win32_Product | Where-Object {$_.IdentifyingNumber -eq $IdentifyingNumber}))
    {
		$InstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\$InstallRegVersion\Setup" -Name "InstallDirectory").InstallDirectory
        $ManagementServer = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\$InstallRegVersion\Setup\WebConsole" -Name "DEFAULT_SERVER").DEFAULT_SERVER
        $WebSiteID = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\$InstallRegVersion\Setup\WebConsole" -Name "WEBSITE_ID").WEBSITE_ID

        $returnValue = @{
		    Ensure = "Present"
		    SourcePath = $SourcePath
		    SourceFolder = $SourceFolder
		    InstallPath = $InstallPath
            ManagementServer = $ManagementServer
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

		[System.String]
	    $WebSiteName = "Default Web Site",

		[ValidateSet("Mixed","Network")]
		[System.String]
	    $WebConsoleAuthorizationMode = "Mixed",

	    [System.Boolean]
        $WebConsoleUseSSL = $false,

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

            # Create install arguments
            $Arguments = "/silent /install /AcceptEndUserLicenseAgreement:1 /components:OMWebConsole"
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
            $ArgumentVars += @(
                "WebSiteName"
                "WebConsoleAuthorizationMode"
            )
            if($WebConsoleUseSSL)
            {
                $Arguments += " /WebConsoleUseSSL"
            }
            foreach($ArgumentVar in $ArgumentVars)
            {
                if(!([String]::IsNullOrEmpty((Get-Variable -Name $ArgumentVar).Value)))
                {
                    $Arguments += " /$ArgumentVar`:" + [Environment]::ExpandEnvironmentVariables((Get-Variable -Name $ArgumentVar).Value)
                }
            }
        }
        "Absent"
        {
            # Create uninstall arguments
            $Arguments = "/silent /uninstall /components:OMWebConsole"
        }
    }

    Write-Verbose "Path: $Path"
    Write-Verbose "Arguments: $Arguments"
    
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

		[System.String]
	    $WebSiteName = "Default Web Site",

		[ValidateSet("Mixed","Network")]
		[System.String]
	    $WebConsoleAuthorizationMode = "Mixed",

	    [System.Boolean]
        $WebConsoleUseSSL = $false,

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