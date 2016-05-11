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
		[System.String]
		$RunAsProfileName
	)
	
    if(!$SCOMManagementGroup)
    {
        $SCOMManagementGroup = ConnectSCOMManagementGroup
    }

    if ($SCOMManagementGroup)
    {
        $AccountPartOfProfile = $false
        try
        {
            Write-Verbose "cmdlet: Get-SCOMRunAsAccount -Name $RunAsAccountName" -Verbose
            $runAsAccount = Get-SCOMRunAsAccount -Name $RunAsAccountName

            if (!$runAsAccount)
            {
                Write-Verbose "Run As Account not present in SCOM." -Verbose
            }

            Write-Verbose "cmdlet: Get-SCOMRunAsProfile -Name $RunAsProfileName" -Verbose
            $runAsProfile = Get-SCOMRunAsProfile -Name $RunAsProfileName

            if (!$runAsProfile)
            {
                Write-Verbose "Run As Profile not present in SCOM." -Verbose
            }

            Write-Verbose "cmdlet: Set-SCOMRunAsProfile -Action Add -Profile $runAsProfile -Account $runAsAccount -whatif -ErrorAction SilentlyContinue -ErrorVariable addToProfile" -Verbose
            Set-SCOMRunAsProfile -Action "Add" -Profile $runAsProfile -Account $runAsAccount -whatif -ErrorAction SilentlyContinue -ErrorVariable addToProfile

            if ($addToProfile -AND $addToProfile[0].toString().contains("Run as account with context Object already exists for profile"))
            {
                Write-Verbose "Account already part of profile." -Verbose
                $AccountPartOfProfile = $true
            }
            Write-Verbose "cmdlet succeeded" -Verbose
        }
        catch
        {
            Write-Verbose "cmdlet failed" -Verbose
            write-verbose $_ -Verbose
        }

	    if($AccountPartOfProfile){
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
		[System.String]
		$RunAsProfileName
	)

    if(!$SCOMManagementGroup)
    {
        $SCOMManagementGroup = ConnectSCOMManagementGroup
    }

    if ($SCOMManagementGroup)
    {

        Write-Verbose "cmdlet: Get-SCOMRunAsAccount -Name $RunAsAccountName" -Verbose                   
        $runAsAccount = Get-SCOMRunAsAccount -Name $RunAsAccountName

        Write-Verbose "cmdlet: Get-SCOMRunAsProfile -Name $RunAsProfileName" -Verbose 
        $runAsProfile = Get-SCOMRunAsProfile -Name $RunAsProfileName

        #Associate the profile and account
        if ($runAsAccount -and $runAsProfile)
        {
            switch($Ensure)
            {
                "Present"
                {
                    try
                    {
                        Write-Verbose "cmdlet: Set-SCOMRunProfile -Action add" -Verbose
                        Set-SCOMRunAsProfile -Action "Add" -Profile $runAsProfile -Account $runAsAccount                      
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
                        Write-Verbose "cmdlet: Set-SCOMRunProfile -Action remove" -Verbose
                        Set-SCOMRunAsProfile -Action "remove" -Profile $runAsProfile -Account $runAsAccount  
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
		[System.String]
		$RunAsProfileName
	)   

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)
	
	$result
}


Export-ModuleMember -Function *-TargetResource

