# NOTE: This resource requires WMF5 and PsDscRunAsCredential

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
		[System.String]
		$SCOMManagementServer,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential
	)

	$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $ComputerName = "$($env:COMPUTERNAME).$($ComputerSystem.Domain)"

    $OMServerSession = New-PSSessionWithRetry -ComputerName $SCOMManagementServer
    if($OMServerSession)
    {
        $SCOMAgent = Invoke-Command -Session $OMServerSession {
            try
            {
                $InstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup" -Name "InstallDirectory" -ErrorAction Stop).InstallDirectory
            }
            catch
            {
                $InstallPath = "$($env:ProgramFiles)\Microsoft System Center 2012 R2\Operations Manager"
            }
            if(!(Get-Module -Name OperationsManager))
            {
                $CurrentVerbose = $VerbosePreference
                $VerbosePreference = 'SilentlyContinue'
                Import-Module "$InstallPath\PowerShell\OperationsManager"
                $VerbosePreference = $CurrentVerbose
            }
            if(Get-Module -Name OperationsManager)
            {
                Get-SCOMAgent -DNSHostName $using:ComputerName
            }
        }
        Remove-PSSession -Session $OMServerSession
    }

    if($SCOMAgent)
    {
        $Ensure = "Present"
    }
    else
    {
        $Ensure = "Absent"
    }

	$returnValue = @{
		Ensure = $Ensure
		SCOMManagementServer = $SCOMManagementServer
	}

    $returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$SCOMManagementServer,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential
	)

	$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $ComputerName = "$($env:COMPUTERNAME).$($ComputerSystem.Domain)"

    $OMServerSession = New-PSSessionWithRetry -ComputerName $SCOMManagementServer
    if($OMServerSession)
    {
        Invoke-Command -Session $OMServerSession {
            try
            {
                $InstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup" -Name "InstallDirectory" -ErrorAction Stop).InstallDirectory
            }
            catch
            {
                $InstallPath = "$($env:ProgramFiles)\Microsoft System Center 2012 R2\Operations Manager"
            }
            if(!(Get-Module -Name OperationsManager))
            {
                $CurrentVerbose = $VerbosePreference
                $VerbosePreference = 'SilentlyContinue'
                Import-Module "$InstallPath\PowerShell\OperationsManager"
                $VerbosePreference = $CurrentVerbose
            }
            if(Get-Module -Name OperationsManager)
            {
                switch($using:Ensure)
                {
                    "Present"
                    {
                        $ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
                        $MSFQDN = "$($ComputerSystem.Name).$($ComputerSystem.Domain)"
                        $ManagementServer = Get-SCOMManagementServer -Name $MSFQDN
                        if($ManagementServer)
                        {
                            Install-SCOMAgent -DNSHostName $using:ComputerName -PrimaryManagementServer $ManagementServer -ActionAccount $using:SetupCredential
                        }
                    }
                    "Absent"
                    {
                        $SCOMAgent = Get-SCOMAgent -DNSHostName $using:ComputerName
                        Uninstall-SCOMAgent -Agent $SCOMAgent -ActionAccount $using:SetupCredential
                    }
                }
            }
        }
        Remove-PSSession -Session $OMServerSession
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
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$SCOMManagementServer,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential
	)

	$result = ((Get-TargetResource -SCOMManagementServer $SCOMManagementServer -SetupCredential $SetupCredential).Ensure -eq $Ensure)
	
    $result
}


Export-ModuleMember -Function *-TargetResource