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

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source\Updates",

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential,

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[System.Boolean]
		$SuppressReboot,

		[System.Boolean]
		$ForceReboot
	)
   
    Import-Module $PSScriptRoot\..\..\xPDT.psm1

    $Version = (Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -eq "Microsoft Monitoring Agent"}).Version
    
    $ProductCode = GetxPDTVariable -Component "SCOM" -Version $Version -Role "Agent" -Name "IdentifyingNumber"
    Write-Verbose "ProductCode is $ProductCode"
    $PatchID = GetxPDTVariable -Component "SCOM" -Version $Version -Role "Agent" -Name "PatchID"
    Write-Verbose "PatchID is $PatchID"
    $Update = GetxPDTVariable -Component "SCOM" -Version $Version -Role "Agent" -Name "Update"
    Write-Verbose "Update is $Update"

    if($ProductCode -and $PatchID)
    {
        try
        {
            Write-Verbose "Get-WmiObject -Class Win32_PatchPackage"
            $PatchPackage = Get-WmiObject -Class Win32_PatchPackage -Filter "ProductCode='$ProductCode' and PatchID='$PatchID'"
        }
        catch
        {
            Write-Verbose "Get-WmiObject -Class Win32_PatchPackage - failed, retry in 10 seconds"
            Start-Sleep 10
        }
        if($PatchPackage)
        {
            $returnValue = @{
		        Ensure = "Present"
		        SourcePath = $SourcePath
		        SourceFolder = $SourceFolder
                Update = $Update
	        }
        }
        else
        {
	        $returnValue = @{
		        Ensure = "Absent"
		        SourcePath = $SourcePath
		        SourceFolder = $SourceFolder
	        }
        }
    }
    {
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
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source\Updates",

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential,

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[System.Boolean]
		$SuppressReboot,

		[System.Boolean]
		$ForceReboot
	)

    Import-Module $PSScriptRoot\..\..\xPDT.psm1

    $Version = (Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -eq "Microsoft Monitoring Agent"}).Version
       
    $UpdateFile = GetxPDTVariable -Component "SCOM" -Version $Version -Role "Agent" -Name "UpdateFile"
    Write-Verbose "UpdateFile is $UpdateFile"

    if($UpdateFile)
    {
        if($SourceCredential)
        {
            NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Present"
            $TempFolder = [IO.Path]::GetTempPath()
            & robocopy.exe (Join-Path -Path $SourcePath -ChildPath $SourceFolder) (Join-Path -Path $TempFolder -ChildPath $SourceFolder) /e
            $SourcePath = $TempFolder
            NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Absent"
        }
        $Path = "msiexec.exe"
        $Path = ResolvePath $Path
        Write-Verbose "Path: $Path"
    
        $MSPPath = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath $UpdateFile
        $MSPPath = ResolvePath $MSPPath
        $Arguments = "/update $MSPPath /norestart"
        Write-Verbose "Arguments: $Arguments"

        $Process = StartWin32Process -Path $Path -Arguments $Arguments -Credential $SetupCredential
        Write-Verbose $Process
        WaitForWin32ProcessEnd -Path $Path -Arguments $Arguments -Credential $SetupCredential
    }

    if($ForceReboot -or ((Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue) -ne $null))
    {
	    if(!($SuppressReboot))
        {
            $global:DSCMachineStatus = 1
        }
        else
        {
            Write-Verbose "Suppressing reboot"
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

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source\Updates",

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential,

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[System.Boolean]
		$SuppressReboot,

		[System.Boolean]
		$ForceReboot
	)

	$result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)
	
	$result
}


Export-ModuleMember -Function *-TargetResource