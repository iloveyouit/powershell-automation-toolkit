<#
.SYNOPSIS
    Brief description of what the script does (one line).

.DESCRIPTION
    Detailed description of the script's functionality.
    Explain what problem it solves and how it works.
    Include any important prerequisites or dependencies.

.PARAMETER ParameterName
    Description of this parameter.
    Include valid values, defaults, and examples.

.PARAMETER AnotherParameter
    Description of another parameter.

.EXAMPLE
    .\Script-Template.ps1 -ParameterName "Value"
    
    Description of what this example does.

.EXAMPLE
    .\Script-Template.ps1 -ParameterName "Value" -AnotherParameter "Value2" -Verbose
    
    Description of this more complex example.

.NOTES
    FileName:    Script-Template.ps1
    Author:      Your Name
    Created:     YYYY-MM-DD
    Modified:    YYYY-MM-DD
    Version:     1.0.0
    
    Requirements:
    - PowerShell 5.1 or later
    - Administrator privileges (if needed)
    - Specific modules (if needed)
    
    Changelog:
    1.0.0 - Initial release

.LINK
    https://github.com/YOUR-USERNAME/powershell-automation-toolkit

.COMPONENT
    Component this script belongs to (optional)

.ROLE
    Role this script is designed for (optional)

.FUNCTIONALITY
    Specific functionality provided (optional)
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator  # Uncomment if admin rights required

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Description of this parameter"
    )]
    [ValidateNotNullOrEmpty()]
    [string]$ParameterName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Optional parameter description"
    )]
    [ValidateSet('Option1', 'Option2', 'Option3')]
    [string]$AnotherParameter = 'Option1',

    [Parameter(Mandatory = $false)]
    [ValidateScript({Test-Path $_ -IsValid})]
    [string]$LogPath = "C:\Logs\ScriptName",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty
)

BEGIN {
    #region Initialize
    
    # Script information
    $scriptName = $MyInvocation.MyCommand.Name
    $scriptVersion = "1.0.0"
    $scriptPath = $PSScriptRoot
    
    # Error action preference
    $ErrorActionPreference = 'Stop'
    
    # Create log directory if it doesn't exist
    if (-not (Test-Path $LogPath)) {
        try {
            New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
            Write-Verbose "Created log directory: $LogPath"
        }
        catch {
            Write-Error "Failed to create log directory: $_"
            exit 1
        }
    }
    
    # Initialize log file
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFile = Join-Path $LogPath "$($scriptName -replace '\.ps1$','')_$timestamp.log"
    
    # Initialize variables
    $startTime = Get-Date
    $results = @()
    
    #endregion Initialize
    
    #region Functions
    
    function Write-Log {
        <#
        .SYNOPSIS
            Writes a message to log file and console.
        #>
        param(
            [Parameter(Mandatory = $true)]
            [string]$Message,
            
            [Parameter(Mandatory = $false)]
            [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS', 'DEBUG')]
            [string]$Level = 'INFO'
        )
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "$timestamp [$Level] $Message"
        
        # Write to log file
        $logMessage | Out-File -FilePath $logFile -Append -Encoding UTF8
        
        # Write to console with appropriate color
        switch ($Level) {
            'INFO'    { Write-Host $logMessage -ForegroundColor White }
            'WARNING' { Write-Warning $Message }
            'ERROR'   { Write-Host $logMessage -ForegroundColor Red }
            'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
            'DEBUG'   { Write-Verbose $Message }
        }
    }
    
    function Test-Prerequisites {
        <#
        .SYNOPSIS
            Validates prerequisites for the script.
        #>
        Write-Log "Validating prerequisites..." -Level INFO
        
        $prerequisitesMet = $true
        
        # Check PowerShell version
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            Write-Log "PowerShell 5.1 or higher is required" -Level ERROR
            $prerequisitesMet = $false
        }
        
        # Check if running as Administrator (if needed)
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Write-Log "This script requires Administrator privileges" -Level WARNING
        }
        
        # Add additional prerequisite checks here
        # Example: Check for required modules
        # if (-not (Get-Module -ListAvailable -Name RequiredModule)) {
        #     Write-Log "Required module 'RequiredModule' not found" -Level ERROR
        #     $prerequisitesMet = $false
        # }
        
        return $prerequisitesMet
    }
    
    function Get-ScriptConfiguration {
        <#
        .SYNOPSIS
            Loads configuration settings.
        #>
        # Define default configuration
        $config = @{
            Timeout = 30
            MaxRetries = 3
            # Add more configuration as needed
        }
        
        # Check for config file
        $configFile = Join-Path $scriptPath "config.json"
        if (Test-Path $configFile) {
            try {
                $fileConfig = Get-Content $configFile | ConvertFrom-Json
                # Merge with defaults
                $fileConfig.PSObject.Properties | ForEach-Object {
                    $config[$_.Name] = $_.Value
                }
                Write-Log "Loaded configuration from: $configFile" -Level INFO
            }
            catch {
                Write-Log "Failed to load config file: $_" -Level WARNING
            }
        }
        
        return $config
    }
    
    #endregion Functions
    
    #region Initialization
    
    Write-Log "========================================" -Level INFO
    Write-Log "$scriptName v$scriptVersion" -Level INFO
    Write-Log "========================================" -Level INFO
    Write-Log "Start time: $startTime" -Level INFO
    Write-Log "Log file: $logFile" -Level INFO
    
    if ($DryRun) {
        Write-Log "DRY RUN MODE - No changes will be made" -Level WARNING
    }
    
    # Validate prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites not met. Exiting." -Level ERROR
        exit 1
    }
    
    # Load configuration
    $config = Get-ScriptConfiguration
    
    Write-Log "Initialization complete" -Level SUCCESS
    
    #endregion Initialization
}

PROCESS {
    try {
        Write-Log "Processing: $ParameterName" -Level INFO
        
        # Main script logic goes here
        
        #region Main Logic
        
        # Example: Process items
        if ($PSCmdlet.ShouldProcess($ParameterName, "Perform operation")) {
            
            if ($DryRun) {
                Write-Log "[DRYRUN] Would perform operation on: $ParameterName" -Level INFO
            }
            else {
                # Actual operation
                Write-Log "Performing operation on: $ParameterName" -Level INFO
                
                # Your code here
                
                Write-Log "Operation completed successfully" -Level SUCCESS
            }
            
            # Store result
            $result = [PSCustomObject]@{
                Timestamp = Get-Date
                Target = $ParameterName
                Status = 'Success'
                Message = 'Operation completed'
                Details = @{}
            }
            
            $results += $result
        }
        
        #endregion Main Logic
        
    }
    catch {
        Write-Log "Error processing $ParameterName : $_" -Level ERROR
        Write-Log "Error details: $($_.Exception.Message)" -Level ERROR
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG
        
        # Store error result
        $result = [PSCustomObject]@{
            Timestamp = Get-Date
            Target = $ParameterName
            Status = 'Failed'
            Message = $_.Exception.Message
            Details = @{
                Exception = $_.Exception.GetType().FullName
                StackTrace = $_.ScriptStackTrace
            }
        }
        
        $results += $result
        
        # Decide whether to continue or halt
        # throw  # Uncomment to halt on error
    }
}

END {
    #region Cleanup and Summary
    
    Write-Log "========================================" -Level INFO
    Write-Log "Script execution completed" -Level INFO
    Write-Log "========================================" -Level INFO
    
    # Calculate execution time
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    # Summary statistics
    $successCount = ($results | Where-Object {$_.Status -eq 'Success'}).Count
    $failedCount = ($results | Where-Object {$_.Status -eq 'Failed'}).Count
    $totalCount = $results.Count
    
    Write-Log "Summary:" -Level INFO
    Write-Log "  Total items: $totalCount" -Level INFO
    Write-Log "  Successful: $successCount" -Level SUCCESS
    Write-Log "  Failed: $failedCount" -Level $(if ($failedCount -gt 0) { 'ERROR' } else { 'INFO' })
    Write-Log "  Duration: $($duration.ToString('hh\:mm\:ss'))" -Level INFO
    Write-Log "  Log file: $logFile" -Level INFO
    
    # Export results if needed
    if ($results.Count -gt 0) {
        $resultsFile = Join-Path $LogPath "$($scriptName -replace '\.ps1$','')_Results_$timestamp.csv"
        try {
            $results | Export-Csv -Path $resultsFile -NoTypeInformation -Encoding UTF8
            Write-Log "Results exported to: $resultsFile" -Level SUCCESS
        }
        catch {
            Write-Log "Failed to export results: $_" -Level ERROR
        }
    }
    
    # Cleanup temporary files/resources if needed
    # Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
    
    Write-Log "Script completed at: $endTime" -Level INFO
    
    # Return results
    return $results
    
    #endregion Cleanup and Summary
}
