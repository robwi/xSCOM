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

		[parameter(Mandatory = $true)]
		[System.String]
		$SqlServerInstance,

		[parameter(Mandatory = $true)]
		[System.String]
		$DatabaseName,
		
		[parameter(Mandatory = $true)]
		[System.String]
		$OMServerName
	)

	Write-Verbose -Message "Retrieve TiP MP ClassID." -Verbose		
	
	$tipHostClassId = Invoke-Command { 
        $InstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup" -Name "InstallDirectory").InstallDirectory
        $CurrentVerbose = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        Import-Module "$InstallPath\PowerShell\OperationsManager"
        $VerbosePreference = $CurrentVerbose
	    Get-ScomClass -Name "Microsoft.SystemCenter.OnStampTiP.Host" | select -ExpandProperty Id
	} -ComputerName $OMServerName
	
	Write-Verbose -Message "Got ClassID $tipHostClassId and start creating Connection..." -Verbose
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Data Source = '$SqlServerInstance'; Initial Catalog = '$DatabaseName'; Integrated Security = True;"
    $SqlConnection.Open() 
    
	$value = $false
	if ($SqlConnection.State -eq "Open")
    {
	    Write-Verbose "Checking On-Stamp TiP MP Availability Flag" -Verbose
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand("select ManagedTypeId from dbo.ManagedTypeMonitoring where ManagedTypeId=@ManagedTypeId", $SqlConnection)
        $sqlHostClass = New-Object System.Data.SqlClient.SqlParameter("@ManagedTypeId", [System.Data.SqlDbType]::UniqueIdentifier);
        $sqlHostClass.Value = $tipHostClassId
        $sqlCommand.Parameters.Add($sqlHostClass)
        $mtmExists = $sqlCommand.ExecuteScalar()
		$value = ($mtmExists -ne $null)
		Write-Verbose "TiP MP Availability Flag is $value" -Verbose
    }    

	if ($value){
	   	    $returnValue = @{
		    Ensure = "Present"
		    SqlServerInstance = $SqlServerInstance
		    DatabaseName = $DatabaseName
			OMServerName = $OMServerName
	    }
	}
	else{
	   	    $returnValue = @{
		    Ensure = "Absent"
		    SqlServerInstance = $SqlServerInstance
		    DatabaseName = $DatabaseName
			OMServerName = $OMServerName
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
		$SqlServerInstance,

		[parameter(Mandatory = $true)]
		[System.String]
		$DatabaseName,
		
		[parameter(Mandatory = $true)]
		[System.String]
		$OMServerName
	)
	
	$tipHostClassId = Invoke-Command {
        $InstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup" -Name "InstallDirectory").InstallDirectory
        $CurrentVerbose = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        Import-Module "$InstallPath\PowerShell\OperationsManager"
        $VerbosePreference = $CurrentVerbose
	    Get-ScomClass -Name "Microsoft.SystemCenter.OnStampTiP.Host" | select -ExpandProperty Id
	} -ComputerName $OMServerName
	
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Data Source = '$SqlServerInstance'; Initial Catalog = '$DatabaseName'; Integrated Security = True;"
    $SqlConnection.Open() 

    if ($SqlConnection.State -eq "Open")
    {
	    Write-Verbose "Checking On-Stamp TiP MP Availability Flag" -Verbose
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand("select ManagedTypeId from dbo.ManagedTypeMonitoring where ManagedTypeId=@ManagedTypeId", $SqlConnection)
        $sqlHostClass = New-Object System.Data.SqlClient.SqlParameter("@ManagedTypeId", [System.Data.SqlDbType]::UniqueIdentifier);
        $sqlHostClass.Value = $tipHostClassId
        $sqlCommand.Parameters.Add($sqlHostClass)
        $mtmExists = $sqlCommand.ExecuteScalar()			
        
		if ($mtmExists -eq $null)
        {
            Write-Verbose "Adding On-Stamp TiP MP Availability Flag" -Verbose
            $sqlCommand = New-Object System.Data.SqlClient.SqlCommand("insert into dbo.ManagedTypeMonitoring values (@ManagedTypeId, 0, 1, 0); exec cs.SnapshotSynchronizationForce", $SqlConnection)
            $sqlHostClass = New-Object System.Data.SqlClient.SqlParameter("@ManagedTypeId", [System.Data.SqlDbType]::UniqueIdentifier);
            $sqlHostClass.Value = $tipHostClassId
            $sqlCommand.Parameters.Add($sqlHostClass)
            $sqlCommand.ExecuteNonQuery() | out-null
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
		$SqlServerInstance,

		[parameter(Mandatory = $true)]
		[System.String]
		$DatabaseName,
		
		[parameter(Mandatory = $true)]
		[System.String]
		$OMServerName
	)

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)
	
	$result
}


Export-ModuleMember -Function *-TargetResource

