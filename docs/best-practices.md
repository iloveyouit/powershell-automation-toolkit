# PowerShell Scripting Best Practices

A comprehensive guide to writing enterprise-quality PowerShell scripts.

## 📋 Table of Contents

1. [Script Structure](#script-structure)
2. [Naming Conventions](#naming-conventions)
3. [Parameter Design](#parameter-design)
4. [Error Handling](#error-handling)
5. [Logging](#logging)
6. [Security](#security)
7. [Performance](#performance)
8. [Testing](#testing)
9. [Documentation](#documentation)
10. [Code Quality](#code-quality)

## Script Structure

### Use the Verb-Noun Naming Pattern

```powershell
# Good
Get-ServerInfo
Set-ServiceConfiguration
Test-NetworkConnectivity

# Bad
ServerInfo
ConfigureService
CheckNetwork
```

### Include Comment-Based Help

```powershell
<#
.SYNOPSIS
    Brief one-line description

.DESCRIPTION
    Detailed description of functionality

.PARAMETER Name
    Parameter description

.EXAMPLE
    Example usage

.NOTES
    Additional information
#>
```

### Use #Requires Statements

```powershell
#Requires -Version 5.1
#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, AzureAD
```

### Implement BEGIN-PROCESS-END Structure

```powershell
BEGIN {
    # Initialization
    # Load configurations
    # Validate prerequisites
}

PROCESS {
    # Main logic
    # Process pipeline input
}

END {
    # Cleanup
    # Summary reporting
    # Resource disposal
}
```

## Naming Conventions

### Variables

```powershell
# Use clear, descriptive names
$serverName = "SERVER01"              # Good
$s = "SERVER01"                       # Bad

# Use camelCase for local variables
$userName = "jdoe"
$ipAddress = "192.168.1.1"

# Use PascalCase for script scope
$Script:ConfigurationPath = "C:\Config"
$Script:LogFile = "C:\Logs\script.log"

# Constants in UPPER_SNAKE_CASE
$RETRY_LIMIT = 3
$MAX_TIMEOUT = 300
```

### Functions

```powershell
# Use approved PowerShell verbs
Get-Verb  # See all approved verbs

# Good examples
function Get-ServerStatus { }
function Set-ServiceAccount { }
function Test-Connectivity { }
function New-LogEntry { }

# Bad examples
function Fetch-Data { }        # Use Get-
function Change-Setting { }    # Use Set-
function Check-Status { }      # Use Test-
function Make-File { }         # Use New-
```

### Parameters

```powershell
# Use PascalCase
param(
    [string]$ComputerName,
    [int]$RetryCount,
    [switch]$Force
)
```

## Parameter Design

### Use Strong Typing

```powershell
param(
    [string]$Name,              # String
    [int]$Count,                # Integer
    [datetime]$Date,            # DateTime
    [switch]$Force,             # Boolean switch
    [ValidateSet('Dev','Test','Prod')]
    [string]$Environment        # Constrained choice
)
```

### Add Validation

```powershell
param(
    # Not null or empty
    [ValidateNotNullOrEmpty()]
    [string]$Name,
    
    # Range validation
    [ValidateRange(1, 100)]
    [int]$Count,
    
    # Pattern validation
    [ValidatePattern('^\d{3}-\d{3}-\d{4}$')]
    [string]$PhoneNumber,
    
    # Path validation
    [ValidateScript({Test-Path $_})]
    [string]$FilePath,
    
    # Set validation
    [ValidateSet('Low', 'Medium', 'High')]
    [string]$Priority
)
```

### Support Pipeline Input

```powershell
param(
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [string]$ComputerName
)
```

### Use CmdletBinding

```powershell
[CmdletBinding(
    SupportsShouldProcess = $true,
    ConfirmImpact = 'High',
    DefaultParameterSetName = 'Default'
)]
param()
```

## Error Handling

### Use Try-Catch-Finally

```powershell
try {
    # Code that might fail
    $result = Invoke-RestMethod -Uri $uri -ErrorAction Stop
}
catch [System.Net.WebException] {
    # Specific exception handling
    Write-Error "Network error: $($_.Exception.Message)"
}
catch {
    # General exception handling
    Write-Error "Unexpected error: $($_.Exception.Message)"
    Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
}
finally {
    # Cleanup code - always runs
    if ($connection) { $connection.Close() }
}
```

### Set ErrorActionPreference Appropriately

```powershell
# Stop on any error (recommended for scripts)
$ErrorActionPreference = 'Stop'

# Continue on errors (use selectively)
$ErrorActionPreference = 'Continue'

# Use -ErrorAction for specific commands
Get-Service -Name "NonExistent" -ErrorAction SilentlyContinue
```

### Provide Meaningful Error Messages

```powershell
# Bad
throw "Error"

# Good
throw "Failed to connect to server '$ComputerName'. Verify the server is online and accessible."

# Better
$errorMessage = @"
Failed to connect to server '$ComputerName'.
Possible causes:
- Server is offline or unreachable
- Firewall blocking connection
- Invalid credentials
Please verify and try again.
"@
throw $errorMessage
```

### Use $PSCmdlet.ThrowTerminatingError()

```powershell
$errorRecord = [System.Management.Automation.ErrorRecord]::new(
    [Exception]::new("Connection failed"),
    "ConnectionFailure",
    [System.Management.Automation.ErrorCategory]::ConnectionError,
    $ComputerName
)
$PSCmdlet.ThrowTerminatingError($errorRecord)
```

## Logging

### Implement Consistent Logging

```powershell
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile = $script:LogFile
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    
    # Write to file
    $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
    
    # Write to appropriate stream
    switch ($Level) {
        'INFO'    { Write-Verbose $Message }
        'WARNING' { Write-Warning $Message }
        'ERROR'   { Write-Error $Message }
        'DEBUG'   { Write-Debug $Message }
    }
}
```

### Use Write-* Cmdlets Appropriately

```powershell
Write-Verbose "Connecting to server..."   # Detailed progress
Write-Debug "Variable value: $value"      # Debugging info
Write-Warning "Disk space low"            # Warnings
Write-Error "Operation failed"            # Errors
Write-Information "Process complete"      # General info
Write-Progress                            # Progress bars
```

### Create Structured Logs

```powershell
# JSON structured logging
$logEntry = @{
    Timestamp = (Get-Date).ToString('o')
    Level = 'INFO'
    Message = 'Operation completed'
    Server = $env:COMPUTERNAME
    User = $env:USERNAME
    Details = @{
        Duration = $duration
        ItemsProcessed = $count
    }
} | ConvertTo-Json -Compress

$logEntry | Out-File -FilePath $LogFile -Append
```

## Security

### Never Hardcode Credentials

```powershell
# Bad
$password = "MyPassword123"
$username = "admin"

# Good - Prompt for credentials
$cred = Get-Credential

# Good - Use Windows Credential Manager
$cred = Get-StoredCredential -Target "MyApp"

# Good - Use secure string
$securePassword = Read-Host "Password" -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)
```

### Use PSCredential Objects

```powershell
param(
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty
)

# Use the credential
if ($Credential -ne [System.Management.Automation.PSCredential]::Empty) {
    Invoke-Command -ComputerName $server -Credential $Credential -ScriptBlock { }
}
```

### Sanitize Input

```powershell
# Validate and sanitize
param(
    [ValidatePattern('^[a-zA-Z0-9\-]+$')]
    [string]$ServerName
)

# Prevent injection
$safeName = $UserInput -replace '[^a-zA-Z0-9\-]', ''
```

### Use Least Privilege

```powershell
# Check if admin is actually needed
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and $RequiresAdmin) {
    throw "This script requires Administrator privileges"
}
```

## Performance

### Use Efficient Methods

```powershell
# Slow - Appending to arrays
$results = @()
foreach ($item in $items) {
    $results += $item  # Creates new array each time
}

# Fast - Use ArrayList or List
$results = [System.Collections.ArrayList]::new()
foreach ($item in $items) {
    $null = $results.Add($item)
}

# Or use pipeline
$results = $items | ForEach-Object { Process-Item $_ }
```

### Filter Early

```powershell
# Slow - Filter after retrieval
$services = Get-Service
$running = $services | Where-Object {$_.Status -eq 'Running'}

# Fast - Filter during retrieval
$running = Get-Service | Where-Object {$_.Status -eq 'Running'}

# Fastest - Use built-in filtering where available
$running = Get-Service -ErrorAction SilentlyContinue | Where-Object Status -eq 'Running'
```

### Use -match Instead of -like When Possible

```powershell
# Slower
$text -like "*pattern*"

# Faster for complex patterns
$text -match "pattern"
```

### Avoid Using Format Cmdlets in Pipeline

```powershell
# Bad - Format cmdlets change object type
Get-Service | Format-Table | Export-Csv output.csv

# Good - Format at the end
Get-Service | Export-Csv output.csv
Get-Service | Format-Table
```

### Use Parallel Processing for Independent Operations

```powershell
# PowerShell 7+ - ForEach-Object -Parallel
$servers | ForEach-Object -Parallel {
    Test-Connection -ComputerName $_ -Count 1
} -ThrottleLimit 10

# PowerShell 5.1 - Workflow or RunspacePool
workflow Test-ServersParallel {
    param([string[]]$ComputerNames)
    foreach -parallel ($computer in $ComputerNames) {
        Test-Connection -ComputerName $computer
    }
}
```

## Testing

### Write Testable Functions

```powershell
# Testable - Returns objects
function Get-DiskInfo {
    param([string]$ComputerName)
    
    Get-WmiObject Win32_LogicalDisk -ComputerName $ComputerName |
        Select-Object DeviceID, Size, FreeSpace
}

# Not testable - Only writes to console
function Show-DiskInfo {
    Get-WmiObject Win32_LogicalDisk | Format-Table
}
```

### Use Pester for Unit Tests

```powershell
Describe "Get-DiskInfo Tests" {
    It "Returns disk information" {
        $result = Get-DiskInfo -ComputerName "localhost"
        $result | Should -Not -BeNullOrEmpty
    }
    
    It "Returns correct properties" {
        $result = Get-DiskInfo -ComputerName "localhost"
        $result[0].PSObject.Properties.Name | Should -Contain 'DeviceID'
        $result[0].PSObject.Properties.Name | Should -Contain 'Size'
    }
}
```

### Mock External Dependencies

```powershell
Describe "Test-ServerConnectivity" {
    Mock Test-Connection { return $true }
    
    It "Returns true when server is reachable" {
        Test-ServerConnectivity -ComputerName "SERVER01" | Should -Be $true
        Assert-MockCalled Test-Connection -Times 1
    }
}
```

## Documentation

### Write Comprehensive Help

```powershell
<#
.SYNOPSIS
    Tests connectivity to remote servers.

.DESCRIPTION
    The Test-ServerConnectivity function tests network connectivity to one or more
    remote servers using ICMP ping. It supports both single and multiple server
    testing and can export results to CSV.

.PARAMETER ComputerName
    The name or IP address of the server(s) to test. Accepts single value or array.
    Can be provided via pipeline.

.PARAMETER Count
    Number of ping attempts. Default is 4.

.PARAMETER TimeoutSeconds
    Timeout in seconds for each ping attempt. Default is 2.

.PARAMETER ExportPath
    Optional path to export results in CSV format.

.EXAMPLE
    Test-ServerConnectivity -ComputerName "SERVER01"
    
    Tests connectivity to SERVER01 with default settings.

.EXAMPLE
    "SERVER01","SERVER02" | Test-ServerConnectivity -Count 10
    
    Tests connectivity to multiple servers with 10 ping attempts each.

.EXAMPLE
    Test-ServerConnectivity -ComputerName (Get-Content servers.txt) -ExportPath C:\Results\connectivity.csv
    
    Tests servers from file and exports results to CSV.

.INPUTS
    System.String
    You can pipe server names to this function.

.OUTPUTS
    PSCustomObject
    Returns objects with properties: ComputerName, Status, ResponseTime, PacketLoss

.NOTES
    Name: Test-ServerConnectivity
    Author: Your Name
    Version: 1.0.0
    DateCreated: 2025-11-01
    
.LINK
    https://github.com/YOUR-USERNAME/powershell-automation-toolkit

#>
```

### Add Inline Comments for Complex Logic

```powershell
# Calculate the threshold based on 80% of total capacity
$threshold = [math]::Round($totalCapacity * 0.8, 2)

# Loop through each disk and check usage
# We subtract 1 from the count because array index starts at 0
for ($i = 0; $i -lt ($disks.Count - 1); $i++) {
    # Process only fixed drives (DriveType 3)
    if ($disks[$i].DriveType -eq 3) {
        # Code here
    }
}
```

## Code Quality

### Use PSScriptAnalyzer

```powershell
# Install
Install-Module -Name PSScriptAnalyzer

# Analyze script
Invoke-ScriptAnalyzer -Path .\Script.ps1

# Use in CI/CD
$results = Invoke-ScriptAnalyzer -Path .\Script.ps1 -Severity Error
if ($results) {
    throw "Script analysis failed"
}
```

### Follow PowerShell Style Guide

```powershell
# Opening braces on same line
if ($condition) {
    # Code
}

# Use 4-space indentation
function Get-Data {
    if ($condition) {
        # Code
    }
}

# Space after keywords
if ($condition) { }
foreach ($item in $items) { }
while ($condition) { }

# No space before parameters
Get-Service -Name "Spooler"  # Good
Get-Service -Name"Spooler"   # Bad
```

### Use Approved Verbs and Nouns

```powershell
# Check approved verbs
Get-Verb | Where-Object { $_.Verb -eq "Fetch" }  # Returns nothing - not approved

# Use approved alternatives
Get-Data    # Instead of Fetch-Data
Remove-Item # Instead of Delete-Item
Set-Value   # Instead of Change-Value
```

### Return Objects, Not Formatted Text

```powershell
# Bad - Returns formatted text
function Get-ServiceInfo {
    Get-Service | Format-Table | Out-String
}

# Good - Returns objects
function Get-ServiceInfo {
    Get-Service | Select-Object Name, Status, StartType
}
```

## Additional Resources

- [PowerShell Best Practices and Style Guide](https://poshcode.gitbooks.io/powershell-practice-and-style/)
- [The PowerShell Best Practices and Style Guide](https://github.com/PoshCode/PowerShellPracticeAndStyle)
- [PowerShell Gallery](https://www.powershellgallery.com/)
- [PSScriptAnalyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer/tree/master/RuleDocumentation)

---

**Remember:** These are guidelines, not absolute rules. Use judgment and consistency in your codebase.

**Last Updated:** November 2025
