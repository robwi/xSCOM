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

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source",

		[System.Management.Automation.PSCredential]
		$SourceCredential,
		
		[parameter(Mandatory = $true)]
		[System.String]
		$SqlServerInstance,

		[parameter(Mandatory = $true)]
		[System.String]
		$DatabaseName = "OperationsManagerDW",

		[parameter(Mandatory = $true)]
        [System.String]
        $ConfigSetting

	)

	Write-Verbose -Message "Getting Patch registry value to validate if database patch has been applied." -Verbose
	
	Import-Module $PSScriptRoot\..\..\xPDT.psm1
	
    if(ImportSQLPSModule)
    {
    	#Get version number from OM Database
        $version = Invoke-Sqlcmd -Database "OperationsManager" -ServerInstance $SqlServerInstance -Query "SELECT DBVersion FROM [dbo].[__MOMManagementGroupInfo__]" -QueryTimeout 600
	    $Version = $version.DBVersion
	
	    Write-Verbose "OM version from DB is $Version"
	
        $IdentifyingNumber = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ManagementServer" -Name "IdentifyingNumber"
        Write-Verbose "IdentifyingNumber is $IdentifyingNumber"

        $DatabaseFileName = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ManagementServer" -Name $ConfigSetting
        Write-Verbose "Database file name is $DatabaseFileName"
	
	    $value = $false
        $item = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cloud Solutions" -Name $ConfigSetting -ErrorAction SilentlyContinue
	    if ($item)
	    {
	        if ($item.$ConfigSetting -and $item.$ConfigSetting -eq $IdentifyingNumber) {
                    Write-Verbose "Registry entry $item.$ConfigSetting found. So Skip execution"
                    $value = $true
                }
	    }
    }

	if ($value){
	   	    $returnValue = @{
		    Ensure = "Present"
		    SourcePath = $SourcePath
		    SourceFolder = $SourceFolder
	    }
	}
	else{
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
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source",

		[System.Management.Automation.PSCredential]
		$SourceCredential,
	
		[parameter(Mandatory = $true)]
		[System.String]
		$SqlServerInstance,

		[parameter(Mandatory = $true)]
		[System.String]
		$DatabaseName = "OperationsManagerDW",

		[parameter(Mandatory = $true)]
        [System.String]
        $ConfigSetting
	)

	Import-Module $PSScriptRoot\..\..\xPDT.psm1
	
	#Copy SCOM media onto local source folder
    if ($SourceCredential)
    {
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Present"
        $TempFolder = [IO.Path]::GetTempPath()
        & robocopy.exe (Join-Path -Path $SourcePath -ChildPath $SourceFolder) (Join-Path -Path $TempFolder -ChildPath $SourceFolder) /e
        $SourcePath = $TempFolder
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Absent"
    }
	
    if(ImportSQLPSModule)
    {
        #Get version number from OM Database
        $ver = Invoke-Sqlcmd -Database "OperationsManager" -ServerInstance $SqlServerInstance -Query "SELECT DBVersion FROM [dbo].[__MOMManagementGroupInfo__]" -QueryTimeout 600
	    $Version = $ver.DBVersion
	
	    Write-Verbose "OM version from DB is $Version"

        $IdentifyingNumber = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ManagementServer" -Name "IdentifyingNumber"
        Write-Verbose "IdentifyingNumber is $IdentifyingNumber"

        $DatabaseFileName = GetxPDTVariable -Component "SCOM" -Version $Version -Role "ManagementServer" -Name $ConfigSetting
        Write-Verbose "Database file name is $DatabaseFileName"

        $DatabaseFilePath = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath $DatabaseFileName
        Resolve-Path $DatabaseFilePath -ErrorAction Stop
        Write-Verbose "Database file path is $DatabaseFilePath"

        Write-Verbose -Message "Applying Database patch $DatabaseFileName on $DatabaseName and Instance $SqlServerInstance" -Verbose
    
        Invoke-Sqlcmd -Database $DatabaseName -ServerInstance $SqlServerInstance -InputFile $DatabaseFilePath -QueryTimeout 1000

        Push-Location
        Set-Location HKLM:
        if (!(Test-path ".\SOFTWARE\Microsoft\Cloud Solutions"))
        {
            New-Item -Path ".\SOFTWARE\Microsoft\Cloud Solutions" -ItemType RegistryKey
        }	
        
        Set-ItemProperty -Path ".\SOFTWARE\Microsoft\Cloud Solutions" -Name $ConfigSetting -Value $IdentifyingNumber
        Pop-Location
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

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source",

		[System.Management.Automation.PSCredential]
		$SourceCredential,
	
		[parameter(Mandatory = $true)]
		[System.String]
		$SqlServerInstance,

		[parameter(Mandatory = $true)]
		[System.String]
		$DatabaseName = "OperationsManagerDW",

		[parameter(Mandatory = $true)]
        [System.String]
        $ConfigSetting
	)   

    $result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)
	
	$result
}


Export-ModuleMember -Function *-TargetResource

