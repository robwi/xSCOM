# Set Global Module Verbose
$VerbosePreference = 'Continue' 

# Load Localization Data 
Import-LocalizedData LocalizedData -filename xSCOM.strings.psd1 -ErrorAction SilentlyContinue
Import-LocalizedData USLocalizedData -filename xSCOM.strings.psd1 -UICulture en-US -ErrorAction SilentlyContinue

function New-TerminatingError 
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ErrorType,

        [parameter(Mandatory = $false)]
        [String[]]
        $FormatArgs,

        [parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory = [System.Management.Automation.ErrorCategory]::OperationStopped,

        [parameter(Mandatory = $false)]
        [Object]
        $TargetObject = $null
    )

    $errorMessage = $LocalizedData.$ErrorType
    
    if(!$errorMessage)
    {
        $errorMessage = ($LocalizedData.NoKeyFound -f $ErrorType)

        if(!$errorMessage)
        {
            $errorMessage = ("No Localization key found for key: {0}" -f $ErrorType)
        }
    }

    $errorMessage = ($errorMessage -f $FormatArgs)

    $callStack = Get-PSCallStack 

    # Get Name of calling script
    if($callStack[1] -and $callStack[1].ScriptName)
    {
        $scriptPath = $callStack[1].ScriptName

        $callingScriptName = $scriptPath.Split('\')[-1].Split('.')[0]
    
        $errorId = "$callingScriptName.$ErrorType"
    }
    else
    {
        $errorId = $ErrorType
    }


    Write-Verbose -Message "$($USLocalizedData.$ErrorType -f $FormatArgs) | ErrorType: $errorId"

    $exception = New-Object System.Exception $errorMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $ErrorCategory, $TargetObject

    return $errorRecord
}


function Assert-Module 
{ 
    [CmdletBinding()] 
    param 
    ( 
        [parameter(Mandatory = $true)]
        [string]$ModuleName
    ) 

    # This will check for all the modules that are loaded or otherwise
    if(!(Get-Module -Name $ModuleName))
    {
        if (!(Get-Module -Name $ModuleName -ListAvailable)) 
        { 
            throw New-TerminatingError -ErrorType ModuleNotFound -FormatArgs @($ModuleName) -ErrorCategory ObjectNotFound -TargetObject $ModuleName 
        }
        else
        {
            Write-Verbose -Message "PowerShell Module '$ModuleName' is installed on the $env:COMPUTERNAME"

            Write-Verbose "Loading $ModuleName Module"
           
            $CurrentVerbose = $VerbosePreference
            $VerbosePreference = "SilentlyContinue"
            $null = Import-Module -Name $ModuleName -ErrorAction Stop
            $VerbosePreference = $CurrentVerbose
        }
    }
}


function ImportSQLPSModule
{
    try
    {
        if(!(Get-Module 'SQLPS'))
        {
            if ((Get-Module -Name 'SQLPS' -ListAvailable)) 
            {
                $ModulePath = 'SQLPS'
            }
            else
            {
                $ModulePath = $null
                $Folders = Get-ChildItem -Path "$(${env:ProgramFiles(x86)})\Microsoft SQL Server"
                foreach($Folder in ($Folders | Sort-Object -Descending))
                {
                    if(!$ModulePath -and (Test-Path -Path "$($Folder.FullName)\Tools\PowerShell\Modules\SQLPS\SQLPS.psd1"))
                    {
                        $ModulePath = "$($Folder.FullName)\Tools\PowerShell\Modules\SQLPS"
                    }
                }
            }
            Write-Verbose 'Importing SQLPS module' -Verbose
            $CurrentVerbose = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'
            Import-Module $ModulePath -Scope Global -ErrorAction Stop
            $VerbosePreference = $CurrentVerbose
            $true
        }
        else
        {
            Write-Verbose 'SQLPS module already imported' -Verbose
            $true
        }
    }
    catch
    {
        $VerbosePreference = $CurrentVerbose
        Write-Verbose 'Failed importing SQLPS module' -Verbose
        $false
    }
}


function ImportOMModule
{
    try
    {
        if(!(Get-Module 'OperationsManager'))
        {
            $InstallPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\System Center Operations Manager\12\Setup" -Name "InstallDirectory").InstallDirectory
            Write-Verbose 'Importing OperationsManager module' -Verbose
            $CurrentVerbose = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'
            Import-Module "$InstallPath\PowerShell\OperationsManager" -Scope Global -ErrorAction Stop
            $VerbosePreference = $CurrentVerbose
            $true
        }
        else
        {
            Write-Verbose 'OperationsManager module already imported' -Verbose
            $true
        }
    }
    catch
    {
        $VerbosePreference = $CurrentVerbose
        Write-Verbose 'Failed importing OperationsManager module' -Verbose
        $false
    }
}


function New-PSSessionWithRetry
{
    param 
    (
        [parameter(Mandatory = $true)]
        [string]$ComputerName,

        [PSCredential]$Credential
    )

    $retryCount = 1
    $maxRetryCount = 6
    $sleepSeconds = 10
    while (($retryCount -le $maxRetryCount))
    {
        try
        {
            if ($Credential)
            {
                $psSession = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop
            }
            else
            {
                $psSession = New-PSSession -ComputerName $ComputerName -ErrorAction Stop
            }
            $retryCount = $maxRetryCount   
        }
        catch [Exception]
        {
            if( $retryCount -ge $maxRetryCount)
            {
                Write-Verbose -Message "Connection attempt $retryCount (of $maxRetryCount) to $ComputerName failed! $($_.Exception)" -Verbose
                Write-Error -Exception $_.Exception
                throw $_
            }
            else
            {
                Write-Verbose -Message "Connection attempt $retryCount (of $maxRetryCount) to $ComputerName failed! Going to try again." -Verbose
            }
        }
        $retryCount = $retryCount + 1
        Start-Sleep -Seconds $sleepSeconds
    } 

    return $psSession
}