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
		[System.String] $Ensure = "Present",

		[parameter(Mandatory=$true,
        HelpMessage='SCOM task name to start. Ex: "Microsoft.LaJolla.Tasks.ResolveAlertsPerMP')] 
        [string] $TaskName,

        [parameter(Mandatory=$true,
        HelpMessage='SCOM class name. Ex: "Microsoft.SystemCenter.CollectionManagementServer')] 
        [string] $ClassName,

        [parameter(Mandatory=$false,
        HelpMessage='Flag that determines whether to check the health state.')] 
        [boolean] $SkipHealthStateCheck = $true, 

        [parameter(Mandatory=$false,
        HelpMessage='Default is 1 day')]
        [string] $LastRun = "-1" 
    )

    if(!$SCOMManagementGroup)
    {
        $SCOMManagementGroup = ConnectSCOMManagementGroup
    }

    if ($SCOMManagementGroup)
    {    
        try
        {
            Write-Verbose "cmdlet: Get-SCOMTask $TaskName" -Verbose
			$task = Get-SCOMTask -Name $TaskName
            
            if (!$task)
            {
                throw New-TerminatingError -ErrorType TaskNotInstalled -FormatArgs @($TaskName) -ErrorCategory ObjectNotFound
            }

            Write-Verbose "cmdlet: Get-SCOMClass $ClassName" -Verbose
            $class = Get-SCOMClass -Name $ClassName 

            if (!$class)
            {
                throw New-TerminatingError -ErrorType ClassNotPresent -FormatArgs @($ClassName) -ErrorCategory ObjectNotFound
            }

            Write-Verbose "cmdlet: Get-SCOMTaskResult" -Verbose
            $taskInstances = Get-SCOMTaskResult -Task $task -ErrorAction SilentlyContinue | ? {$_.TimeStarted -gt (get-date).AddDays($LastRun).ToUniversalTime()}
            
            if ($taskInstances)
            {
                Write-Verbose "Found Task result." -Verbose
	   	        $returnValue = @{
		            Ensure = "Present"
                }            
            }
            else
            {
	   	        $returnValue = @{
		            Ensure = "Absent"
	            }                
            }		
	    }
	    catch
	    {
            Write-Verbose "cmdlet failed: $_" -Verbose
            throw $_
	    }    
    }
    else
    {
        $returnValue = @{
            Ensure = "Absent"
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
		[System.String] $Ensure = "Present",

		[parameter(Mandatory=$true,
        HelpMessage='SCOM task name to start. Ex: "Microsoft.LaJolla.Tasks.ResolveAlertsPerMP')] 
        [string] $TaskName,

        [parameter(Mandatory=$true,
        HelpMessage='SCOM class name. Ex: "Microsoft.SystemCenter.CollectionManagementServer')] 
        [string] $ClassName,

        [parameter(Mandatory=$false,
        HelpMessage='Flag that determines whether to check the health state.')] 
        [boolean] $SkipHealthStateCheck = $true, 

        [parameter(Mandatory=$false,
        HelpMessage='Default is 1 day')]
        [string] $LastRun = "-1" 
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
                    Write-Verbose "cmdlet: Get-SCOMTask" -Verbose
			        $task = Get-SCOMTask -Name $TaskName

                    Write-Verbose "cmdlet: Get-SCOMClass" -Verbose
			        $class = Get-SCOMClass -Name $ClassName 

                    Write-Verbose "cmdlet: Get-SCOMClassInstance" -Verbose
                    $instance =  Get-SCOMClassInstance -Class $Class | ?{($_.Healthstate -eq "Success") -or $SkipHealthStateCheck}

			        if ($instance)
			        {
                        Write-Verbose "cmdlet: Start-SCOMTask" -Verbose
				        $task = Start-SCOMTask -Task $task -Instance $instance
				        if ($task -eq $null)
				        {
                            throw New-TerminatingError -ErrorType StartTaskFailed -FormatArgs @($TaskName)
				        }
			        }
			        else
			        {
                        throw New-TerminatingError -ErrorType ClassInstanceNotFound -FormatArgs @($ClassName) -ErrorCategory ObjectNotFound
			        }
                }
                catch
                {
                    Write-Verbose "cmdlet failed: $_" -Verbose
                    throw $_
                }
            }
            "Absent"
            {
                throw New-TerminatingError -ErrorType AbsentNotImplemented -ErrorCategory NotImplemented
            }
        }
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
		[System.String] $Ensure = "Present",

		[parameter(Mandatory=$true,
        HelpMessage='SCOM task name to start. Ex: "Microsoft.LaJolla.Tasks.ResolveAlertsPerMP')] 
        [string] $TaskName,

        [parameter(Mandatory=$true,
        HelpMessage='SCOM class name. Ex: "Microsoft.SystemCenter.CollectionManagementServer')] 
        [string] $ClassName,

        [parameter(Mandatory=$false,
        HelpMessage='Flag that determines whether to check the health state.')] 
        [boolean] $SkipHealthStateCheck = $true,
         
        [parameter(Mandatory=$false,
        HelpMessage='Default is 1 day')]
        [string] $LastRun = "-1" 
    )   

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)

	$result
}


Export-ModuleMember -Function *-TargetResource

