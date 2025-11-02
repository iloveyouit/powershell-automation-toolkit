<#
.SYNOPSIS
    Identifies and reports on inactive Active Directory accounts.

.DESCRIPTION
    This script provides functions to:
    - Find user accounts that haven't logged in for a specified period
    - Find computer accounts that haven't connected to the domain
    - Identify accounts that are disabled but not moved to proper OUs
    - Export inactive accounts to CSV for review
    - Optionally disable or move inactive accounts

.PARAMETER AccountType
    Type of accounts to search: User, Computer, or Both (default: User)

.PARAMETER InactiveDays
    Number of days of inactivity to consider an account inactive (default: 90)

.PARAMETER SearchBase
    The distinguished name of the OU to search (default: entire domain)

.PARAMETER Action
    Action to perform: Report, Disable, or Move (default: Report)

.PARAMETER TargetOU
    Distinguished name of the OU to move inactive accounts to (required for Move action)

.PARAMETER ExportPath
    Path to export the report CSV file

.EXAMPLE
    .\Find-InactiveADAccounts.ps1 -InactiveDays 90 -ExportPath "C:\Reports\InactiveUsers.csv"

    Finds all user accounts inactive for 90+ days and exports to CSV.

.EXAMPLE
    .\Find-InactiveADAccounts.ps1 -AccountType Computer -InactiveDays 60

    Finds all computer accounts inactive for 60+ days and displays in console.

.EXAMPLE
    .\Find-InactiveADAccounts.ps1 -InactiveDays 180 -Action Disable

    Disables all user accounts inactive for 180+ days.

.EXAMPLE
    .\Find-InactiveADAccounts.ps1 -InactiveDays 90 -Action Move -TargetOU "OU=Disabled,DC=company,DC=com"

    Moves all accounts inactive for 90+ days to the specified OU.

.EXAMPLE
    .\Find-InactiveADAccounts.ps1 -SearchBase "OU=Sales,DC=company,DC=com" -InactiveDays 60 -ExportPath "C:\Reports\InactiveSales.csv"

    Finds inactive accounts only in the Sales OU.

.NOTES
    Author: System Administrator
    Date: 2025-11-01
    Requires: Active Directory PowerShell module
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("User", "Computer", "Both")]
    [string]$AccountType = "User",

    [Parameter(Mandatory = $false)]
    [int]$InactiveDays = 90,

    [Parameter(Mandatory = $false)]
    [string]$SearchBase,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Report", "Disable", "Move")]
    [string]$Action = "Report",

    [Parameter(Mandatory = $false)]
    [string]$TargetOU,

    [Parameter(Mandatory = $false)]
    [string]$ExportPath
)

#Requires -Modules ActiveDirectory

# Import required modules
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "[INFO] Active Directory module loaded successfully." -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to load Active Directory module: $_" -ForegroundColor Red
    exit 1
}

# Calculate the cutoff date
$cutoffDate = (Get-Date).AddDays(-$InactiveDays)

# Function to find inactive user accounts
function Find-InactiveUsers {
    param(
        [datetime]$CutoffDate,
        [string]$SearchBase
    )

    Write-Host "[INFO] Searching for user accounts inactive since $($CutoffDate.ToString('yyyy-MM-dd'))..." -ForegroundColor Yellow

    $filterParams = @{
        Filter = {
            (Enabled -eq $true) -and
            ((LastLogonDate -lt $CutoffDate) -or (LastLogonDate -notlike "*"))
        }
        Properties = @(
            'DisplayName',
            'SamAccountName',
            'LastLogonDate',
            'Created',
            'PasswordLastSet',
            'Department',
            'Title',
            'EmailAddress',
            'DistinguishedName'
        )
    }

    if ($SearchBase) {
        $filterParams['SearchBase'] = $SearchBase
    }

    try {
        $inactiveUsers = Get-ADUser @filterParams

        Write-Host "[SUCCESS] Found $($inactiveUsers.Count) inactive user accounts" -ForegroundColor Green

        return $inactiveUsers | Select-Object @{
            Name = 'AccountType'
            Expression = { 'User' }
        },
        DisplayName,
        SamAccountName,
        @{
            Name = 'LastLogon'
            Expression = { if ($_.LastLogonDate) { $_.LastLogonDate } else { 'Never' } }
        },
        @{
            Name = 'DaysInactive'
            Expression = { if ($_.LastLogonDate) { ((Get-Date) - $_.LastLogonDate).Days } else { 'Never Logged In' } }
        },
        Created,
        PasswordLastSet,
        Department,
        Title,
        EmailAddress,
        DistinguishedName
    }
    catch {
        Write-Host "[ERROR] Failed to retrieve inactive users: $_" -ForegroundColor Red
        return @()
    }
}

# Function to find inactive computer accounts
function Find-InactiveComputers {
    param(
        [datetime]$CutoffDate,
        [string]$SearchBase
    )

    Write-Host "[INFO] Searching for computer accounts inactive since $($CutoffDate.ToString('yyyy-MM-dd'))..." -ForegroundColor Yellow

    $filterParams = @{
        Filter = {
            (Enabled -eq $true) -and
            ((LastLogonDate -lt $CutoffDate) -or (LastLogonDate -notlike "*"))
        }
        Properties = @(
            'Name',
            'LastLogonDate',
            'Created',
            'OperatingSystem',
            'OperatingSystemVersion',
            'IPv4Address',
            'DistinguishedName'
        )
    }

    if ($SearchBase) {
        $filterParams['SearchBase'] = $SearchBase
    }

    try {
        $inactiveComputers = Get-ADComputer @filterParams

        Write-Host "[SUCCESS] Found $($inactiveComputers.Count) inactive computer accounts" -ForegroundColor Green

        return $inactiveComputers | Select-Object @{
            Name = 'AccountType'
            Expression = { 'Computer' }
        },
        Name,
        @{
            Name = 'LastLogon'
            Expression = { if ($_.LastLogonDate) { $_.LastLogonDate } else { 'Never' } }
        },
        @{
            Name = 'DaysInactive'
            Expression = { if ($_.LastLogonDate) { ((Get-Date) - $_.LastLogonDate).Days } else { 'Never Connected' } }
        },
        Created,
        OperatingSystem,
        OperatingSystemVersion,
        IPv4Address,
        DistinguishedName
    }
    catch {
        Write-Host "[ERROR] Failed to retrieve inactive computers: $_" -ForegroundColor Red
        return @()
    }
}

# Function to disable accounts
function Disable-InactiveAccounts {
    param(
        [array]$Accounts
    )

    Write-Host "[WARNING] About to disable $($Accounts.Count) accounts" -ForegroundColor Yellow
    $confirmation = Read-Host "Are you sure you want to continue? (yes/no)"

    if ($confirmation -ne "yes") {
        Write-Host "[INFO] Operation cancelled by user" -ForegroundColor Yellow
        return
    }

    $successCount = 0
    $failCount = 0

    foreach ($account in $Accounts) {
        try {
            if ($account.AccountType -eq "User") {
                Disable-ADAccount -Identity $account.SamAccountName -ErrorAction Stop
                Write-Host "[SUCCESS] Disabled user: $($account.SamAccountName)" -ForegroundColor Green
            }
            else {
                Disable-ADAccount -Identity $account.Name -ErrorAction Stop
                Write-Host "[SUCCESS] Disabled computer: $($account.Name)" -ForegroundColor Green
            }
            $successCount++
        }
        catch {
            Write-Host "[ERROR] Failed to disable $($account.SamAccountName): $_" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host "`n[SUMMARY] Disable operation complete:" -ForegroundColor Cyan
    Write-Host "  Successfully disabled: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
}

# Function to move accounts to different OU
function Move-InactiveAccounts {
    param(
        [array]$Accounts,
        [string]$DestinationOU
    )

    # Verify target OU exists
    try {
        $ou = Get-ADOrganizationalUnit -Identity $DestinationOU -ErrorAction Stop
    }
    catch {
        Write-Host "[ERROR] Target OU not found or invalid: $DestinationOU" -ForegroundColor Red
        return
    }

    Write-Host "[WARNING] About to move $($Accounts.Count) accounts to: $DestinationOU" -ForegroundColor Yellow
    $confirmation = Read-Host "Are you sure you want to continue? (yes/no)"

    if ($confirmation -ne "yes") {
        Write-Host "[INFO] Operation cancelled by user" -ForegroundColor Yellow
        return
    }

    $successCount = 0
    $failCount = 0

    foreach ($account in $Accounts) {
        try {
            Move-ADObject -Identity $account.DistinguishedName -TargetPath $DestinationOU -ErrorAction Stop
            $accountName = if ($account.AccountType -eq "User") { $account.SamAccountName } else { $account.Name }
            Write-Host "[SUCCESS] Moved $($account.AccountType): $accountName" -ForegroundColor Green
            $successCount++
        }
        catch {
            $accountName = if ($account.AccountType -eq "User") { $account.SamAccountName } else { $account.Name }
            Write-Host "[ERROR] Failed to move $accountName : $_" -ForegroundColor Red
            $failCount++
        }
    }

    Write-Host "`n[SUMMARY] Move operation complete:" -ForegroundColor Cyan
    Write-Host "  Successfully moved: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
}

# Main script execution
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Inactive AD Accounts Report" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "[INFO] Configuration:" -ForegroundColor Cyan
Write-Host "  Account Type: $AccountType" -ForegroundColor White
Write-Host "  Inactive Days: $InactiveDays" -ForegroundColor White
Write-Host "  Cutoff Date: $($cutoffDate.ToString('yyyy-MM-dd'))" -ForegroundColor White
if ($SearchBase) {
    Write-Host "  Search Base: $SearchBase" -ForegroundColor White
}
Write-Host ""

# Collect inactive accounts
$allInactiveAccounts = @()

if ($AccountType -eq "User" -or $AccountType -eq "Both") {
    $inactiveUsers = Find-InactiveUsers -CutoffDate $cutoffDate -SearchBase $SearchBase
    $allInactiveAccounts += $inactiveUsers
}

if ($AccountType -eq "Computer" -or $AccountType -eq "Both") {
    $inactiveComputers = Find-InactiveComputers -CutoffDate $cutoffDate -SearchBase $SearchBase
    $allInactiveAccounts += $inactiveComputers
}

if ($allInactiveAccounts.Count -eq 0) {
    Write-Host "[INFO] No inactive accounts found" -ForegroundColor Green
    exit 0
}

# Perform action based on parameter
switch ($Action) {
    "Report" {
        Write-Host "`n[INFO] Displaying inactive accounts report..." -ForegroundColor Yellow

        if ($ExportPath) {
            $allInactiveAccounts | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
            Write-Host "[SUCCESS] Report exported to: $ExportPath" -ForegroundColor Green
        }
        else {
            $allInactiveAccounts | Format-Table -AutoSize
        }

        # Summary statistics
        Write-Host "`n[SUMMARY] Inactive Accounts:" -ForegroundColor Cyan
        $userCount = ($allInactiveAccounts | Where-Object { $_.AccountType -eq "User" }).Count
        $computerCount = ($allInactiveAccounts | Where-Object { $_.AccountType -eq "Computer" }).Count

        if ($userCount -gt 0) {
            Write-Host "  Users: $userCount" -ForegroundColor White
        }
        if ($computerCount -gt 0) {
            Write-Host "  Computers: $computerCount" -ForegroundColor White
        }
        Write-Host "  Total: $($allInactiveAccounts.Count)" -ForegroundColor White
    }

    "Disable" {
        Disable-InactiveAccounts -Accounts $allInactiveAccounts
    }

    "Move" {
        if (-not $TargetOU) {
            Write-Host "[ERROR] -TargetOU parameter is required for Move action" -ForegroundColor Red
            exit 1
        }
        Move-InactiveAccounts -Accounts $allInactiveAccounts -DestinationOU $TargetOU
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Operation Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
