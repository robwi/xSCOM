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
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$Principal,

		[parameter(Mandatory = $true)]
		[System.String]
		$UserRole
	)

    
    if(ImportOMModule)
    {
        if(Get-SCOMUserRole -Name $UserRole | ForEach-Object {$_.Users} | Where-Object {$_ -eq $Principal})
        {
            $Ensure = "Present"
        }
        else
        {
            $Ensure = "Absent"
        }
    }

    $returnValue = @{
        Ensure = $Ensure
        Principal = $Principal
        UserRole = $UserRole
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
		$Principal,

		[parameter(Mandatory = $true)]
		[System.String]
		$UserRole
	)

    if(ImportOMModule)
    {
        $UR = Get-SCOMUserRole -Name $UserRole
        switch($Ensure)
        {
            "Present"
            {
                if(!(Get-SCOMUserRole -Name $UserRole | ForEach-Object {$_.Users} | Where-Object {$_ -eq $Principal}))
                {
                    $NewUsers = ($UR.Users + $Principal)
                }
            }
            "Absent"
            {
                if(Get-SCOMUserRole -Name $UserRole | ForEach-Object {$_.Users} | Where-Object {$_ -eq $Principal})
                {
                    $NewUsers = $UR.Users | Where-Object {$_ -ne $Principal}
                }
            }
        }
        Set-SCOMUserRole -UserRole $UR -User $NewUsers
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
		$Principal,

		[parameter(Mandatory = $true)]
		[System.String]
		$UserRole
	)

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)

	$result
}


Export-ModuleMember -Function *-TargetResource