$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\xSCOMHelper.psm1 -Verbose:$false -ErrorAction Stop


function Get-TargetResource
{
    #.DESCRIPTION
    #This Cmdlet will target each node that needs to be added to the Distribution list (Not OMServer).

	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$RunAsAccountName,
	
		[parameter(Mandatory = $true)]
        [System.String]
		$SCOMManagementServer
	)


	$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $ComputerName = "$($env:COMPUTERNAME).$($ComputerSystem.Domain)"
    Write-Verbose "Targetting SCOM Server $SCOMManagementServer with $ComputerName"

    $OMServerSession = New-PSSessionWithRetry -ComputerName $SCOMManagementServer
    if($OMServerSession)
    {
        $InDistribution = Invoke-Command -Session $OMServerSession {
            $found = $false
            $InstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup" -Name "InstallDirectory").InstallDirectory
            if(!(Get-Module -Name OperationsManager))
            {
                $CurrentVerbose = $VerbosePreference
                $VerbosePreference = 'SilentlyContinue'
                Import-Module "$InstallPath\PowerShell\OperationsManager"
                $VerbosePreference = $CurrentVerbose
            }

            if(Get-Module -Name OperationsManager)
            {
                if ($Using:ComputerName -eq $Using:SCOMManagementServer)
                {
                    Write-Verbose "cmdlet: Get-ScomClass -Name 'Microsoft.SystemCenter.AllManagementServersPool'" -Verbose
                    $amspClass = Get-ScomClass -Name "Microsoft.SystemCenter.AllManagementServersPool"
                    $agent = Get-ScomClassInstance $amspClass
                }
                else
                {
                    Write-Verbose "cmdlet: Get-SCOMAgent -DNSHostName $($Using:ComputerName)" -Verbose
                    $agent = Get-SCOMAgent -DNSHostName $Using:ComputerName
                }

                if ($agent -eq $null)
                {
                     Write-Verbose "Agent not present on host." -Verbose
                }
                else
                {
                    Write-Verbose "cmdlet: Get-SCOMRunAsAccount -Name $($Using:RunAsAccountName)" -Verbose
                    $RunAsAccount = Get-SCOMRunAsAccount -Name $Using:RunAsAccountName

                    Write-Verbose "cmdlet: Get-SCOMRunAsDistribution" -Verbose
                    $distribution = Get-SCOMRunAsDistribution -RunAsAccount $RunAsAccount

                    if ($distribution.SecureDistribution.DisplayName -contains $agent.DisplayName)
                    {
                        Write-Verbose "Host found in Distribution." -Verbose
                        $found = $true
                    }
                    else
                    {
                        Write-Verbose "Host not found in Distribution." -Verbose
                    }
                }
            }

            $found
        }
        Remove-PSSession -Session $OMServerSession
    }

    if($InDistribution){
        $returnValue = @{
        Ensure = "Present"
        }
    }
    else{
        $returnValue = @{
        Ensure = "Absent"
        }
    }
	
    $returnValue
    
}


function Set-TargetResource
{
    #.DESCRIPTION
    #This Cmdlet will target each node that needs to be added to the Distribution list (Not OMServer).

	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$RunAsAccountName,
	
		[parameter(Mandatory = $true)]
        [System.String]
		$SCOMManagementServer
	)

	$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $ComputerName = "$($env:COMPUTERNAME).$($ComputerSystem.Domain)"
    Write-Verbose "Targetting SCOM Server $SCOMManagementServer with $ComputerName"

    $OMServerSession = New-PSSessionWithRetry -ComputerName $SCOMManagementServer
    if($OMServerSession)
    {
        Invoke-Command -Session $OMServerSession {
            $InstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup" -Name "InstallDirectory").InstallDirectory
            if(!(Get-Module -Name OperationsManager))
            {
                $CurrentVerbose = $VerbosePreference
                $VerbosePreference = 'SilentlyContinue'
                Import-Module "$InstallPath\PowerShell\OperationsManager"
                $VerbosePreference = $CurrentVerbose
            }
            if(Get-Module -Name OperationsManager)
            {
                $agents = @()
                switch($Using:Ensure)
                {
                    "Present"
                    {
                        try
                        {
                            Write-Verbose "cmdlet: Get-SCOMRunAsAccount -Name $($Using:RunAsAccountName)" -Verbose
                            $runAsAccount = Get-SCOMRunAsAccount -Name $Using:RunAsAccountName

                            if ($Using:ComputerName -eq $Using:SCOMManagementServer)
                            {
                                Write-Verbose "cmdlet: Get-ScomClass -Name 'Microsoft.SystemCenter.AllManagementServersPool'" -Verbose
                                $amspClass = Get-ScomClass -Name "Microsoft.SystemCenter.AllManagementServersPool"
                                $agent = Get-ScomClassInstance $amspClass
                            }
                            else
                            {
                                Write-Verbose "cmdlet: Get-SCOMAgent -DNSHostName $($Using:ComputerName)" -Verbose
                                $agent = Get-SCOMAgent -DNSHostName $Using:ComputerName
                            }

                            $agents += $agent

                            Write-Verbose "cmdlet: Get-SCOMRunAsDistribution" -Verbose
                            $distribution = Get-SCOMRunAsDistribution -RunAsAccount $runAsAccount

                            $agents += $distribution.SecureDistribution

                            Write-Verbose "cmdlet: Set-SCOMRunAsDistribution" -Verbose
                            Set-SCOMRunAsDistribution -RunAsAccount $runAsAccount -MoreSecure -SecureDistribution $agents

                            Write-Verbose "cmdlet succeeded" -Verbose
                        }
                        catch
                        {
                            Write-Verbose "cmdlet failed" -Verbose
                            throw $_
                        }
                    }
                    "Absent"
                    {
                        try
                        {
                            Write-Verbose "cmdlet: Get-SCOMRunAsAccount" -Verbose
                            $runAsAccount = Get-SCOMRunAsAccount -Name $runAsAccountName

                            Write-Verbose "cmdlet: Get-SCOMAgent" -Verbose
                            $agent += Get-SCOMAgent -DNSHostName $Node.NodeName

                            Write-Verbose "cmdlet: Get-SCOMRunAsDistribution" -Verbose
                            $distribution = Get-SCOMRunAsDistribution -RunAsAccount $runAsAccount

                            $agents += $distribution.SecureDistribution | ? {$_.DisplayName -notlike $agents.DisplayName}

                            Write-Verbose "cmdlet: Set-SCOMRunAsDistribution" -Verbose                    
                            Set-SCOMRunAsDistribution -RunAsAccount $runAsAccount -MoreSecure -SecureDistribution $agents

                            Write-Verbose "cmdlet succeeded" -Verbose
                        }
                        catch
                        {
                            Write-Verbose "cmdlet failed" -Verbose
                            throw $_
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
    #.DESCRIPTION
    #This Cmdlet will target each node that needs to be added to the Distribution list (Not OMServer).

	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$RunAsAccountName,
	
		[parameter(Mandatory = $true)]
		[System.String]
		$SCOMManagementServer
	)   

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)
	
	$result
}


Export-ModuleMember -Function *-TargetResource

