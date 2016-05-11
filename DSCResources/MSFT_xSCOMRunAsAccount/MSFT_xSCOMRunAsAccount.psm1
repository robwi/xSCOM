$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\xSCOMHelper.psm1 -Verbose:$false -ErrorAction Stop


function ConnectSCOMManagementGroup
{
    if(ImportOMModule)
    {
        try
        {
            Write-Verbose "Connecting to OM server $($env:COMPUTERNAME)"
            New-SCOMManagementGroupConnection -ComputerName $env:COMPUTERNAME
            return $true
        }
        catch
        {
            throw New-TerminatingError -ErrorType FailedToConnectToVMMServer -FormatArgs $($env:COMPUTERNAME)
        }
    }
}


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

		[parameter(Mandatory = $true)]
		[System.String]
		$RunAsAccountName,
	
		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$RunAscredential,

		[System.String]
		$Description
	)
	
    if(!$SCOMManagementGroup)
    {
        $SCOMManagementGroup = ConnectSCOMManagementGroup
    }

    if ($SCOMManagementGroup)
    {
        try
        {
            Write-Verbose "cmdlet: Get-SCOMRunAsAccount" -Verbose
            $runAsAccount = Get-SCOMRunAsAccount -Name $RunAsAccountName
            Write-Verbose "cmdlet succeeded" -Verbose
        }
        catch
        {
            Write-Verbose "cmdlet failed" -Verbose
        }

	    if($runAsAccount){
                Write-Verbose "Account already present." -Verbose
	   	        $returnValue = @{
		        Ensure = "Present"
		        Description = $runAsAccount.Description
                }
	        
	    }
	    else{
                Write-Verbose "Account not found." -Verbose
	   	        $returnValue = @{
		        Ensure = "Absent"
                Description = ""
	        }
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

		[parameter(Mandatory = $true)]
		[System.String]
		$RunAsAccountName,
	
		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$RunAscredential,

		[System.String]
		$Description
	)

    if(!$SCOMManagementGroup)
    {
        $SCOMManagementGroup = ConnectSCOMManagementGroup
    }

    if ($SCOMManagementGroup)
    {	    
        switch($Ensure)
        {
            "Present"
            {
                try
                {
                    Write-Verbose "cmdlet: Add-SCOMRunAsAccount" -Verbose
                    Add-SCOMRunAsAccount -Name $RunAsAccountName -RunAsCredential $RunAscredential -Description $Description
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
                    Write-Verbose "cmdlet: Get-SCOMRunAsAccount | Remove-SCOMRunAsccount" -Verbose
                    Get-SCOMRunAsAccount -Name $RunAsAccountName| Remove-SCOMRunAsAccount
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

		[parameter(Mandatory = $true)]
		[System.String]
		$RunAsAccountName,
	
		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$RunAscredential,

		[System.String]
		$Description
	)   

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)

	$result
}


Export-ModuleMember -Function *-TargetResource

