# NOTE: This resource requires WMF5 and PsDscRunAsCredential

# DSC resource to manage OM license.
# Runs on the OM Management Server.

$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\xSCOMHelper.psm1 -Verbose:$false -ErrorAction Stop


function ConnectOMServer
{
    if(ImportOMModule)
    {
        try
        {
            Write-Verbose "Connecting to OM server $($env:COMPUTERNAME)"
            New-SCOMManagementGroupConnection -ComputerName $env:COMPUTERNAME -PassThru
        }
        catch
        {
            Write-Verbose "Failed connecting to OM server $($env:COMPUTERNAME)"
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
		$ProductKey
	)

    if(!$OMServer)
    {
        $OMServer = ConnectOMServer
    }

    if($OMServer)
    {
        try
        {
            Write-Verbose "Getting license type for OM server $($env:COMPUTERNAME)"
            $LicenseType = (Get-SCOMManagementGroup -SCSession $OMServer).skuforlicense
            Write-Verbose "License type for OM server $($env:COMPUTERNAME) is $LicenseType"
            if($LicenseType -eq 'Eval')
            {
                $Ensure = "Absent"
            }
            else
            {
                $Ensure = "Present"
            }
        }
        catch
        {
            Write-Verbose "Failed getting license type for OM server $($env:COMPUTERNAME)"
            $Ensure = "Absent"
        }
    }

    $returnValue = @{
        Ensure = $Ensure
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
		$ProductKey
	)

    $OMServer = ConnectOMServer

    if($OMServer)
    {
        switch($Ensure)
        {
            "Present"
            {
                try
                {
                    Write-Verbose "Setting license for OM server $($env:COMPUTERNAME)"
                    Set-SCOMLicense -ProductID $ProductKey -Confirm:$false -ErrorAction Stop
                    Write-Verbose "Restarting OM Data Access Service on $($env:COMPUTERNAME)"
                    Restart-Service OMSDK
                }
                catch
                {
                    Write-Verbose "Failed setting license for OM server $($env:COMPUTERNAME)"
                }
            }
            "Absent"
            {
                throw New-TerminatingError -ErrorType AbsentNotImplemented -ErrorCategory NotImplemented
            }
        }
    }

    # NOTE: No Test-TargetResource since the eval license is cached, PowerShell must be reloaded before the udpated license will be returned
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
		$ProductKey
	)

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)

	$result
}


Export-ModuleMember -Function *-TargetResource