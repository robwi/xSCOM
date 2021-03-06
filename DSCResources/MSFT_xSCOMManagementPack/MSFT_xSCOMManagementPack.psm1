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
		$Name,

		[System.String]
		$Version,

		[parameter(Mandatory = $true)]
		[System.String]
	    $MinVersion,

		[System.String]
		$SourcePath,

		[parameter(Mandatory = $true)]
		[System.String]
		$SourceFolder,

		[parameter(Mandatory = $true)]
		[System.String]
		$SourceFile
	)

    if(ImportOMModule)
    {
        $Version = [String](Get-SCManagementPack -Name $Name).Version
    }

	$returnValue = @{
		Name = $Name
		Version = $Version
	}

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[System.String]
		$Version,

		[parameter(Mandatory = $true)]
		[System.String]
		$MinVersion,

		[System.String]
		$SourcePath,

		[parameter(Mandatory = $true)]
		[System.String]
		$SourceFolder,

		[parameter(Mandatory = $true)]
		[System.String]
		$SourceFile
	)

    if(ImportOMModule)
    {
        if([String]::IsNullOrEmpty($SourcePath))
        {
            $SourcePath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup" -Name "InstallDirectory").InstallDirectory
        }
        $MPFile = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath $SourceFile

        if(Test-Path -Path $MPFile)
        {
            Write-Verbose "MPFile: $MPFile"
            Import-SCManagementPack $MPFile
        }

        $i = 0
        while (!(Test-TargetResource @PSBoundParameters) -and ($i -le 60))
        {
            $i++
            Write-Verbose "Management Pack $Name test $i"
            Start-Sleep 1
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
		[System.String]
		$Name,

		[System.String]
		$Version,

		[parameter(Mandatory = $true)]
		[System.String]
		$MinVersion,

		[System.String]
		$SourcePath,

		[parameter(Mandatory = $true)]
		[System.String]
		$SourceFolder,

		[parameter(Mandatory = $true)]
		[System.String]
		$SourceFile
	)

    $result = $true
    
    $MPData = Get-TargetResource @PSBoundParameters

    # Test for MP not installed
    if([String]::IsNullOrEmpty($MPData.Version))
    {
        $result = $false
    }

    if($result)
    {
        # Test just for MP, no version
        if([String]::IsNullOrEmpty($Version) -and [String]::IsNullOrEmpty($MinVersion))
        {
            if(![String]::IsNullOrEmpty($MPData.Version))
            {
                $result = $true
            }
            else
            {
                $result = $false
            }
        }
	
        # Test for MP specific version
        if(![String]::IsNullOrEmpty($Version))
        {
            if($Version -eq $MPData.Version)
            {
                $result = $true
            }
            else
            {
                $result = $false
            }
        }
        # Test for MP minimum version
        else
        {
            $MinVersionArray = $MinVersion.Split(".")
            $VersionArray = $MPData.Version.Split(".")

            if($VersionArray[0] -lt $MinVersionArray[0])
            {
                $result = $false
            }
            else
            {
                if($VersionArray[0] -gt $MinVersionArray[0])
                {
                    $result = $true
                }
                else
                {
                    if($VersionArray[1] -lt $MinVersionArray[1])
                    {
                        $result = $false
                    }
                    else
                    {
                        if($VersionArray[1] -gt $MinVersionArray[1])
                        {
                            $result = $true
                        }
                        else
                        {
                            if($VersionArray[2] -lt $MinVersionArray[2])
                            {
                                $result = $false
                            }
                            else
                            {
                                if($VersionArray[2] -gt $MinVersionArray[2])
                                {
                                    $result = $true
                                }
                                else
                                {
                                    if($VersionArray[3] -lt $MinVersionArray[3])
                                    {
                                        $result = $false
                                    }
                                    else
                                    {
                                        if($VersionArray[3] -ge $MinVersionArray[3])
                                        {
                                            $result = $true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

	$result
}


Export-ModuleMember -Function *-TargetResource