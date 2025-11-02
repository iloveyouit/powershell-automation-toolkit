<#
.SYNOPSIS
    Resets and manages Active Directory user passwords.

.DESCRIPTION
    This script provides functions to:
    - Reset user passwords with secure password generation
    - Force password change at next logon
    - Unlock user accounts
    - Set password never expires
    - Bulk password reset operations from CSV
    - Generate secure random passwords

.PARAMETER UserName
    The username (SamAccountName) of the user

.PARAMETER Action
    The action to perform: Reset, Unlock, ForceChange, or BulkReset

.PARAMETER Password
    The new password (if not provided, a random secure password will be generated)

.PARAMETER MustChangePassword
    Force user to change password at next logon (default: $true for Reset action)

.PARAMETER UnlockAccount
    Unlock the account if it's locked (applies to Reset action)

.PARAMETER CSVPath
    Path to CSV file for bulk operations (requires column: UserName)

.PARAMETER ExportPath
    Path to export generated passwords to CSV (recommended for bulk operations)

.EXAMPLE
    .\Reset-ADUserPassword.ps1 -Action Reset -UserName "jdoe"

    Resets password for user 'jdoe' with a randomly generated secure password.

.EXAMPLE
    .\Reset-ADUserPassword.ps1 -Action Reset -UserName "jdoe" -Password "NewP@ssw0rd123" -MustChangePassword $false

    Resets password to a specific value without forcing change at next logon.

.EXAMPLE
    .\Reset-ADUserPassword.ps1 -Action Unlock -UserName "jdoe"

    Unlocks the user account 'jdoe'.

.EXAMPLE
    .\Reset-ADUserPassword.ps1 -Action ForceChange -UserName "jdoe"

    Forces user 'jdoe' to change password at next logon.

.EXAMPLE
    .\Reset-ADUserPassword.ps1 -Action BulkReset -CSVPath "C:\Input\users.csv" -ExportPath "C:\Output\passwords.csv"

    Resets passwords for all users in CSV and exports the generated passwords.

.NOTES
    Author: System Administrator
    Date: 2025-11-01
    Requires: Active Directory PowerShell module
    Version: 1.0

    CSV Format for BulkReset:
    UserName
    jdoe
    jsmith
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$UserName,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Reset", "Unlock", "ForceChange", "BulkReset")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [SecureString]$Password,

    [Parameter(Mandatory = $false)]
    [bool]$MustChangePassword = $true,

    [Parameter(Mandatory = $false)]
    [switch]$UnlockAccount,

    [Parameter(Mandatory = $false)]
    [string]$CSVPath,

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

# Function to generate a secure random password
function New-SecurePassword {
    param(
        [int]$Length = 16
    )

    # Character sets
    $uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lowercase = 'abcdefghijklmnopqrstuvwxyz'
    $numbers = '0123456789'
    $special = '!@#$%^&*()_+-=[]{}|;:,.<>?'

    # Ensure at least one character from each set
    $password = @()
    $password += $uppercase[(Get-Random -Maximum $uppercase.Length)]
    $password += $lowercase[(Get-Random -Maximum $lowercase.Length)]
    $password += $numbers[(Get-Random -Maximum $numbers.Length)]
    $password += $special[(Get-Random -Maximum $special.Length)]

    # Fill the rest with random characters from all sets
    $allChars = $uppercase + $lowercase + $numbers + $special
    for ($i = $password.Count; $i -lt $Length; $i++) {
        $password += $allChars[(Get-Random -Maximum $allChars.Length)]
    }

    # Shuffle the password
    $shuffled = $password | Sort-Object { Get-Random }

    return -join $shuffled
}

# Function to convert plain text password to SecureString
function ConvertTo-SecurePassword {
    param([string]$PlainPassword)

    return ConvertTo-SecureString -String $PlainPassword -AsPlainText -Force
}

# Function to reset user password
function Reset-UserPassword {
    param(
        [string]$User,
        [SecureString]$NewPassword,
        [bool]$ForceChange = $true,
        [bool]$Unlock = $false
    )

    try {
        # Verify user exists
        $adUser = Get-ADUser -Identity $User -Properties LockedOut, PasswordLastSet -ErrorAction Stop

        # Generate password if not provided
        $plainPassword = $null
        if (-not $NewPassword) {
            $plainPassword = New-SecurePassword
            $NewPassword = ConvertTo-SecurePassword -PlainPassword $plainPassword
            Write-Host "[INFO] Generated secure password for user '$User'" -ForegroundColor Yellow
        }

        # Reset password
        Set-ADAccountPassword -Identity $User -NewPassword $NewPassword -Reset -ErrorAction Stop

        # Set password change requirement
        Set-ADUser -Identity $User -ChangePasswordAtLogon $ForceChange -ErrorAction Stop

        # Unlock account if requested or if account is locked
        if ($Unlock -or $adUser.LockedOut) {
            Unlock-ADAccount -Identity $User -ErrorAction Stop
            Write-Host "[SUCCESS] Account '$User' has been unlocked" -ForegroundColor Green
        }

        Write-Host "[SUCCESS] Password reset for user '$User'" -ForegroundColor Green
        if ($ForceChange) {
            Write-Host "[INFO] User must change password at next logon" -ForegroundColor Yellow
        }

        return [PSCustomObject]@{
            UserName        = $User
            Password        = $plainPassword
            MustChangePassword = $ForceChange
            Unlocked        = ($Unlock -or $adUser.LockedOut)
            Status          = "Success"
            Timestamp       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Host "[ERROR] User '$User' not found" -ForegroundColor Red
        return [PSCustomObject]@{
            UserName = $User
            Status   = "Failed - User not found"
        }
    }
    catch {
        Write-Host "[ERROR] Failed to reset password for '$User': $_" -ForegroundColor Red
        return [PSCustomObject]@{
            UserName = $User
            Status   = "Failed - $_"
        }
    }
}

# Function to unlock account
function Unlock-UserAccount {
    param([string]$User)

    try {
        # Verify user exists
        $adUser = Get-ADUser -Identity $User -Properties LockedOut -ErrorAction Stop

        if (-not $adUser.LockedOut) {
            Write-Host "[INFO] Account '$User' is not locked" -ForegroundColor Yellow
            return
        }

        Unlock-ADAccount -Identity $User -ErrorAction Stop
        Write-Host "[SUCCESS] Account '$User' has been unlocked" -ForegroundColor Green
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Host "[ERROR] User '$User' not found" -ForegroundColor Red
    }
    catch {
        Write-Host "[ERROR] Failed to unlock account '$User': $_" -ForegroundColor Red
    }
}

# Function to force password change at next logon
function Set-ForcePasswordChange {
    param([string]$User)

    try {
        # Verify user exists
        $adUser = Get-ADUser -Identity $User -ErrorAction Stop

        Set-ADUser -Identity $User -ChangePasswordAtLogon $true -ErrorAction Stop
        Write-Host "[SUCCESS] User '$User' must change password at next logon" -ForegroundColor Green
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Host "[ERROR] User '$User' not found" -ForegroundColor Red
    }
    catch {
        Write-Host "[ERROR] Failed to set force password change for '$User': $_" -ForegroundColor Red
    }
}

# Function for bulk password reset
function Invoke-BulkPasswordReset {
    param(
        [string]$CSV,
        [string]$ExportFile
    )

    try {
        # Verify CSV exists
        if (-not (Test-Path $CSV)) {
            Write-Host "[ERROR] CSV file not found: $CSV" -ForegroundColor Red
            return
        }

        # Import CSV
        $data = Import-Csv -Path $CSV -ErrorAction Stop

        # Validate CSV format
        if (-not ($data[0].PSObject.Properties.Name -contains 'UserName')) {
            Write-Host "[ERROR] CSV must contain 'UserName' column" -ForegroundColor Red
            return
        }

        Write-Host "[INFO] Processing $($data.Count) users from CSV..." -ForegroundColor Yellow
        Write-Host "[WARNING] Passwords will be randomly generated for all users" -ForegroundColor Yellow

        $results = @()

        foreach ($entry in $data) {
            Write-Host "`nProcessing: $($entry.UserName)" -ForegroundColor Cyan
            $result = Reset-UserPassword -User $entry.UserName -ForceChange $true -Unlock $true
            $results += $result
        }

        # Export results
        if ($ExportFile) {
            $results | Export-Csv -Path $ExportFile -NoTypeInformation -Encoding UTF8
            Write-Host "`n[SUCCESS] Results exported to: $ExportFile" -ForegroundColor Green
            Write-Host "[IMPORTANT] Store this file securely - it contains generated passwords!" -ForegroundColor Yellow
        }
        else {
            Write-Host "`n[WARNING] No export path specified. Displaying results:" -ForegroundColor Yellow
            $results | Format-Table -AutoSize
        }

        # Summary
        $successCount = ($results | Where-Object { $_.Status -eq "Success" }).Count
        $failCount = $results.Count - $successCount

        Write-Host "`n[SUMMARY] Bulk password reset complete:" -ForegroundColor Cyan
        Write-Host "  Successful: $successCount" -ForegroundColor Green
        Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
    }
    catch {
        Write-Host "[ERROR] Failed to process bulk operation: $_" -ForegroundColor Red
    }
}

# Main script execution
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AD Password Management" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

switch ($Action) {
    "Reset" {
        if (-not $UserName) {
            Write-Host "[ERROR] -UserName is required for Reset action" -ForegroundColor Red
            exit 1
        }

        $result = Reset-UserPassword -User $UserName -NewPassword $Password -ForceChange $MustChangePassword -Unlock $UnlockAccount

        if ($result.Password) {
            Write-Host "`n[IMPORTANT] Generated Password: $($result.Password)" -ForegroundColor Yellow
            Write-Host "[IMPORTANT] Please provide this password to the user securely" -ForegroundColor Yellow
        }
    }

    "Unlock" {
        if (-not $UserName) {
            Write-Host "[ERROR] -UserName is required for Unlock action" -ForegroundColor Red
            exit 1
        }

        Unlock-UserAccount -User $UserName
    }

    "ForceChange" {
        if (-not $UserName) {
            Write-Host "[ERROR] -UserName is required for ForceChange action" -ForegroundColor Red
            exit 1
        }

        Set-ForcePasswordChange -User $UserName
    }

    "BulkReset" {
        if (-not $CSVPath) {
            Write-Host "[ERROR] -CSVPath is required for BulkReset action" -ForegroundColor Red
            exit 1
        }

        if (-not $ExportPath) {
            Write-Host "[WARNING] -ExportPath not specified. Generated passwords will only be displayed on screen." -ForegroundColor Yellow
            $confirm = Read-Host "Continue without exporting passwords? (yes/no)"
            if ($confirm -ne "yes") {
                Write-Host "[INFO] Operation cancelled" -ForegroundColor Yellow
                exit 0
            }
        }

        Invoke-BulkPasswordReset -CSV $CSVPath -ExportFile $ExportPath
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Operation Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
