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
		$SCOMManagementServer
	)

	$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $ComputerName = "$($env:COMPUTERNAME).$($ComputerSystem.Domain)"

    $OMServerSession = New-PSSessionWithRetry -ComputerName $SCOMManagementServer
    if($OMServerSession)
    {
        $SCOMAgentProxy = Invoke-Command -Session $OMServerSession {
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
                (Get-SCOMAgent -DNSHostName $using:ComputerName).ProxyingEnabled.Value
            }
        }
        Remove-PSSession -Session $OMServerSession
    }

    if($SCOMAgentProxy)
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
		$Ensure = "Absent",

		[parameter(Mandatory = $true)]
		[System.String]
		$SCOMManagementServer
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
                $SCOMAgent = Get-SCOMAgent -DNSHostName $using:ComputerName
                if($SCOMAgent)
                {
                    switch($using:Ensure)
                    {
                        "Present"
                        {
                            Enable-SCOMAgentProxy -Agent $SCOMAgent
                        }
                        "Absent"
                        {
                            Disable-SCOMAgentProxy -Agent $SCOMAgent
                        }
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
		$Ensure = "Absent",

		[parameter(Mandatory = $true)]
		[System.String]
		$SCOMManagementServer
	)

	$result = ((Get-TargetResource -SCOMManagementServer $SCOMManagementServer).Ensure -eq $Ensure)
	
    $result
}


Export-ModuleMember -Function *-TargetResource