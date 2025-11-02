<#
.SYNOPSIS
    Generates comprehensive Active Directory user account reports.

.DESCRIPTION
    This script provides functions to:
    - Generate reports on user accounts in Active Directory
    - Filter users by various criteria (enabled/disabled, department, etc.)
    - Export reports to CSV or HTML format
    - Check password expiration dates
    - Identify accounts that never expire

.PARAMETER SearchBase
    The distinguished name of the OU to search (default: entire domain)

.PARAMETER Department
    Filter users by department

.PARAMETER Enabled
    Filter by account status: $true (enabled), $false (disabled), or $null (all)

.PARAMETER ExportFormat
    Export format: CSV, HTML, or Console (default: Console)

.PARAMETER OutputPath
    Path for the exported report file (required for CSV and HTML formats)

.PARAMETER IncludePasswordInfo
    Include password expiration and policy information

.EXAMPLE
    .\Get-ADUserReport.ps1 -ExportFormat Console

    Displays all users in console output.

.EXAMPLE
    .\Get-ADUserReport.ps1 -Department "IT" -ExportFormat CSV -OutputPath "C:\Reports\IT_Users.csv"

    Exports all IT department users to a CSV file.

.EXAMPLE
    .\Get-ADUserReport.ps1 -Enabled $false -ExportFormat HTML -OutputPath "C:\Reports\DisabledUsers.html"

    Exports all disabled user accounts to an HTML report.

.EXAMPLE
    .\Get-ADUserReport.ps1 -IncludePasswordInfo -ExportFormat CSV -OutputPath "C:\Reports\PasswordExpiry.csv"

    Exports user report with password expiration information.

.NOTES
    Author: System Administrator
    Date: 2025-11-01
    Requires: Active Directory PowerShell module
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SearchBase,

    [Parameter(Mandatory = $false)]
    [string]$Department,

    [Parameter(Mandatory = $false)]
    [nullable[bool]]$Enabled = $null,

    [Parameter(Mandatory = $false)]
    [ValidateSet("CSV", "HTML", "Console")]
    [string]$ExportFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$IncludePasswordInfo
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

# Function to get password expiration date
function Get-PasswordExpirationDate {
    param($User)

    try {
        if ($User.PasswordNeverExpires) {
            return "Never"
        }

        $maxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
        if ($maxPasswordAge -eq $null -or $maxPasswordAge.Days -eq 0) {
            return "Never"
        }

        if ($User.PasswordLastSet) {
            $expiryDate = $User.PasswordLastSet + $maxPasswordAge
            return $expiryDate
        }
        else {
            return "Not Set"
        }
    }
    catch {
        return "Unknown"
    }
}

# Function to calculate days until password expires
function Get-DaysUntilPasswordExpires {
    param($ExpiryDate)

    if ($ExpiryDate -eq "Never" -or $ExpiryDate -eq "Not Set" -or $ExpiryDate -eq "Unknown") {
        return $ExpiryDate
    }

    $daysRemaining = ($ExpiryDate - (Get-Date)).Days
    return $daysRemaining
}

# Main script execution
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Active Directory User Report" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Build filter parameters
$filterParams = @{
    Properties = @(
        'DisplayName',
        'SamAccountName',
        'UserPrincipalName',
        'EmailAddress',
        'Department',
        'Title',
        'Enabled',
        'LastLogonDate',
        'Created',
        'PasswordLastSet',
        'PasswordNeverExpires'
    )
}

if ($SearchBase) {
    $filterParams['SearchBase'] = $SearchBase
    Write-Host "[INFO] Searching in: $SearchBase" -ForegroundColor Yellow
}

# Get all users based on filters
Write-Host "[INFO] Retrieving user accounts..." -ForegroundColor Yellow

try {
    $users = Get-ADUser -Filter * @filterParams

    # Apply filters
    if ($Enabled -ne $null) {
        $users = $users | Where-Object { $_.Enabled -eq $Enabled }
        $statusText = if ($Enabled) { "enabled" } else { "disabled" }
        Write-Host "[INFO] Filtering for $statusText accounts" -ForegroundColor Yellow
    }

    if ($Department) {
        $users = $users | Where-Object { $_.Department -eq $Department }
        Write-Host "[INFO] Filtering for department: $Department" -ForegroundColor Yellow
    }

    Write-Host "[SUCCESS] Found $($users.Count) user accounts" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to retrieve user accounts: $_" -ForegroundColor Red
    exit 1
}

# Build report data
$reportData = @()

foreach ($user in $users) {
    $userInfo = [PSCustomObject]@{
        'Display Name'        = $user.DisplayName
        'Username'            = $user.SamAccountName
        'UPN'                 = $user.UserPrincipalName
        'Email'               = $user.EmailAddress
        'Department'          = $user.Department
        'Title'               = $user.Title
        'Enabled'             = $user.Enabled
        'Last Logon'          = $user.LastLogonDate
        'Account Created'     = $user.Created
    }

    if ($IncludePasswordInfo) {
        $passwordExpiry = Get-PasswordExpirationDate -User $user
        $daysRemaining = Get-DaysUntilPasswordExpires -ExpiryDate $passwordExpiry

        $userInfo | Add-Member -NotePropertyName 'Password Last Set' -NotePropertyValue $user.PasswordLastSet
        $userInfo | Add-Member -NotePropertyName 'Password Expires' -NotePropertyValue $passwordExpiry
        $userInfo | Add-Member -NotePropertyName 'Days Until Expiry' -NotePropertyValue $daysRemaining
    }

    $reportData += $userInfo
}

# Export or display report
switch ($ExportFormat) {
    "CSV" {
        if (-not $OutputPath) {
            Write-Host "[ERROR] OutputPath is required for CSV export" -ForegroundColor Red
            exit 1
        }

        try {
            $reportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            Write-Host "[SUCCESS] Report exported to: $OutputPath" -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to export CSV: $_" -ForegroundColor Red
            exit 1
        }
    }

    "HTML" {
        if (-not $OutputPath) {
            Write-Host "[ERROR] OutputPath is required for HTML export" -ForegroundColor Red
            exit 1
        }

        try {
            $htmlHeader = @"
<style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #2c3e50; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th { background-color: #3498db; color: white; padding: 12px; text-align: left; }
    td { border: 1px solid #ddd; padding: 8px; }
    tr:nth-child(even) { background-color: #f2f2f2; }
    tr:hover { background-color: #e8f4f8; }
    .info { color: #7f8c8d; font-size: 0.9em; margin-top: 10px; }
</style>
<h1>Active Directory User Report</h1>
<p class="info">Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
<p class="info">Total Users: $($reportData.Count)</p>
"@

            $reportData | ConvertTo-Html -Head $htmlHeader | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host "[SUCCESS] Report exported to: $OutputPath" -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to export HTML: $_" -ForegroundColor Red
            exit 1
        }
    }

    "Console" {
        $reportData | Format-Table -AutoSize
        Write-Host "`n[INFO] Total users displayed: $($reportData.Count)" -ForegroundColor Cyan
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Report Generation Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
