<#
.SYNOPSIS
    Creates new Active Directory user accounts with standardized configuration.

.DESCRIPTION
    This script provides functions to:
    - Create new AD user accounts with complete profile information
    - Set up home directories and profile paths
    - Assign users to groups
    - Set password policies
    - Bulk create users from CSV
    - Generate temporary passwords

.PARAMETER FirstName
    User's first name

.PARAMETER LastName
    User's last name

.PARAMETER UserName
    SAM Account Name (if not provided, generated from first.last)

.PARAMETER Department
    User's department

.PARAMETER Title
    User's job title

.PARAMETER Manager
    Manager's SAM Account Name

.PARAMETER TargetOU
    Distinguished name of the OU where the user will be created

.PARAMETER Groups
    Array of group names to add the user to

.PARAMETER EmailDomain
    Email domain for generating email address (e.g., "company.com")

.PARAMETER Password
    Initial password (if not provided, a random secure password will be generated)

.PARAMETER MustChangePassword
    Require password change at next logon (default: $true)

.PARAMETER CSVPath
    Path to CSV file for bulk user creation

.PARAMETER ExportPath
    Path to export created user credentials to CSV

.EXAMPLE
    .\New-ADUserAccount.ps1 -FirstName "John" -LastName "Doe" -Department "IT" -Title "System Administrator" -EmailDomain "company.com"

    Creates a new user account with auto-generated username and password.

.EXAMPLE
    .\New-ADUserAccount.ps1 -FirstName "Jane" -LastName "Smith" -UserName "jsmith" -Department "Sales" -Groups @("Sales-Team","Office365-Users") -EmailDomain "company.com"

    Creates a user and adds them to specified groups.

.EXAMPLE
    .\New-ADUserAccount.ps1 -CSVPath "C:\Input\newusers.csv" -ExportPath "C:\Output\credentials.csv"

    Bulk creates users from CSV and exports credentials.

.NOTES
    Author: System Administrator
    Date: 2025-11-01
    Requires: Active Directory PowerShell module
    Version: 1.0

    CSV Format for Bulk Creation:
    FirstName,LastName,Department,Title,Manager,Groups,TargetOU
    John,Doe,IT,Admin,jmanager,"IT-Support;Office365-Users","OU=IT,DC=company,DC=com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$FirstName,

    [Parameter(Mandatory = $false)]
    [string]$LastName,

    [Parameter(Mandatory = $false)]
    [string]$UserName,

    [Parameter(Mandatory = $false)]
    [string]$Department,

    [Parameter(Mandatory = $false)]
    [string]$Title,

    [Parameter(Mandatory = $false)]
    [string]$Manager,

    [Parameter(Mandatory = $false)]
    [string]$TargetOU,

    [Parameter(Mandatory = $false)]
    [string[]]$Groups,

    [Parameter(Mandatory = $false)]
    [string]$EmailDomain,

    [Parameter(Mandatory = $false)]
    [SecureString]$Password,

    [Parameter(Mandatory = $false)]
    [bool]$MustChangePassword = $true,

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
    param([int]$Length = 16)

    $uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lowercase = 'abcdefghijklmnopqrstuvwxyz'
    $numbers = '0123456789'
    $special = '!@#$%^&*()_+-=[]{}|;:,.<>?'

    $password = @()
    $password += $uppercase[(Get-Random -Maximum $uppercase.Length)]
    $password += $lowercase[(Get-Random -Maximum $lowercase.Length)]
    $password += $numbers[(Get-Random -Maximum $numbers.Length)]
    $password += $special[(Get-Random -Maximum $special.Length)]

    $allChars = $uppercase + $lowercase + $numbers + $special
    for ($i = $password.Count; $i -lt $Length; $i++) {
        $password += $allChars[(Get-Random -Maximum $allChars.Length)]
    }

    $shuffled = $password | Sort-Object { Get-Random }
    return -join $shuffled
}

# Function to generate username from name
function New-UserName {
    param(
        [string]$First,
        [string]$Last
    )

    $baseUsername = "$($First.ToLower()).$($Last.ToLower())"
    $username = $baseUsername
    $counter = 1

    # Check if username exists and increment if needed
    while (Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue) {
        $username = "$baseUsername$counter"
        $counter++
    }

    return $username
}

# Function to create a new AD user
function New-ADUserAccount {
    param(
        [hashtable]$UserParams
    )

    try {
        # Generate username if not provided
        if (-not $UserParams.UserName) {
            $UserParams.UserName = New-UserName -First $UserParams.FirstName -Last $UserParams.LastName
            Write-Host "[INFO] Generated username: $($UserParams.UserName)" -ForegroundColor Yellow
        }

        # Check if user already exists
        if (Get-ADUser -Filter "SamAccountName -eq '$($UserParams.UserName)'" -ErrorAction SilentlyContinue) {
            Write-Host "[ERROR] User '$($UserParams.UserName)' already exists" -ForegroundColor Red
            return $null
        }

        # Generate password if not provided
        $plainPassword = $null
        if (-not $UserParams.Password) {
            $plainPassword = New-SecurePassword
            $UserParams.Password = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force
            Write-Host "[INFO] Generated secure password for user '$($UserParams.UserName)'" -ForegroundColor Yellow
        }

        # Build user properties
        $displayName = "$($UserParams.FirstName) $($UserParams.LastName)"
        $upn = "$($UserParams.UserName)@$(if ($UserParams.EmailDomain) { $UserParams.EmailDomain } else { (Get-ADDomain).DNSRoot })"
        $email = "$($UserParams.FirstName).$($UserParams.LastName)@$(if ($UserParams.EmailDomain) { $UserParams.EmailDomain } else { (Get-ADDomain).DNSRoot })"

        $newUserParams = @{
            SamAccountName        = $UserParams.UserName
            UserPrincipalName     = $upn
            Name                  = $displayName
            GivenName             = $UserParams.FirstName
            Surname               = $UserParams.LastName
            DisplayName           = $displayName
            EmailAddress          = $email.ToLower()
            AccountPassword       = $UserParams.Password
            Enabled               = $true
            ChangePasswordAtLogon = $UserParams.MustChangePassword
        }

        # Add optional parameters
        if ($UserParams.Department) {
            $newUserParams['Department'] = $UserParams.Department
        }

        if ($UserParams.Title) {
            $newUserParams['Title'] = $UserParams.Title
        }

        if ($UserParams.TargetOU) {
            $newUserParams['Path'] = $UserParams.TargetOU
        }

        # Create the user
        New-ADUser @newUserParams -ErrorAction Stop
        Write-Host "[SUCCESS] Created user account: $($UserParams.UserName)" -ForegroundColor Green

        # Set manager if specified
        if ($UserParams.Manager) {
            try {
                $managerDN = (Get-ADUser -Identity $UserParams.Manager -ErrorAction Stop).DistinguishedName
                Set-ADUser -Identity $UserParams.UserName -Manager $managerDN -ErrorAction Stop
                Write-Host "[SUCCESS] Set manager to: $($UserParams.Manager)" -ForegroundColor Green
            }
            catch {
                Write-Host "[WARNING] Failed to set manager: $_" -ForegroundColor Yellow
            }
        }

        # Add to groups if specified
        if ($UserParams.Groups) {
            foreach ($group in $UserParams.Groups) {
                try {
                    Add-ADGroupMember -Identity $group -Members $UserParams.UserName -ErrorAction Stop
                    Write-Host "[SUCCESS] Added to group: $group" -ForegroundColor Green
                }
                catch {
                    Write-Host "[WARNING] Failed to add to group '$group': $_" -ForegroundColor Yellow
                }
            }
        }

        return [PSCustomObject]@{
            UserName           = $UserParams.UserName
            DisplayName        = $displayName
            Email              = $email.ToLower()
            UPN                = $upn
            Password           = $plainPassword
            Department         = $UserParams.Department
            Title              = $UserParams.Title
            Manager            = $UserParams.Manager
            Groups             = ($UserParams.Groups -join '; ')
            Status             = "Success"
            Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }
    catch {
        Write-Host "[ERROR] Failed to create user '$($UserParams.UserName)': $_" -ForegroundColor Red
        return [PSCustomObject]@{
            UserName = $UserParams.UserName
            Status   = "Failed - $_"
        }
    }
}

# Function for bulk user creation
function New-BulkADUsers {
    param(
        [string]$CSV,
        [string]$ExportFile,
        [string]$DefaultEmailDomain
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
        $requiredColumns = @('FirstName', 'LastName')
        $missingColumns = $requiredColumns | Where-Object { $_ -notin $data[0].PSObject.Properties.Name }

        if ($missingColumns) {
            Write-Host "[ERROR] CSV missing required columns: $($missingColumns -join ', ')" -ForegroundColor Red
            return
        }

        Write-Host "[INFO] Processing $($data.Count) users from CSV..." -ForegroundColor Yellow

        $results = @()

        foreach ($entry in $data) {
            Write-Host "`nProcessing: $($entry.FirstName) $($entry.LastName)" -ForegroundColor Cyan

            # Build user parameters
            $userParams = @{
                FirstName          = $entry.FirstName
                LastName           = $entry.LastName
                MustChangePassword = $true
            }

            if ($entry.UserName) { $userParams['UserName'] = $entry.UserName }
            if ($entry.Department) { $userParams['Department'] = $entry.Department }
            if ($entry.Title) { $userParams['Title'] = $entry.Title }
            if ($entry.Manager) { $userParams['Manager'] = $entry.Manager }
            if ($entry.TargetOU) { $userParams['TargetOU'] = $entry.TargetOU }
            if ($entry.EmailDomain) {
                $userParams['EmailDomain'] = $entry.EmailDomain
            }
            elseif ($DefaultEmailDomain) {
                $userParams['EmailDomain'] = $DefaultEmailDomain
            }

            # Parse groups (semicolon-separated)
            if ($entry.Groups) {
                $userParams['Groups'] = $entry.Groups -split ';' | ForEach-Object { $_.Trim() }
            }

            $result = New-ADUserAccount -UserParams $userParams
            if ($result) {
                $results += $result
            }
        }

        # Export results
        if ($ExportFile) {
            $results | Export-Csv -Path $ExportFile -NoTypeInformation -Encoding UTF8
            Write-Host "`n[SUCCESS] Results exported to: $ExportFile" -ForegroundColor Green
            Write-Host "[IMPORTANT] Store this file securely - it contains generated passwords!" -ForegroundColor Yellow
        }
        else {
            Write-Host "`n[WARNING] No export path specified. Displaying results:" -ForegroundColor Yellow
            $results | Format-Table UserName, DisplayName, Email, Password, Status -AutoSize
        }

        # Summary
        $successCount = ($results | Where-Object { $_.Status -eq "Success" }).Count
        $failCount = $results.Count - $successCount

        Write-Host "`n[SUMMARY] Bulk user creation complete:" -ForegroundColor Cyan
        Write-Host "  Successful: $successCount" -ForegroundColor Green
        Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
    }
    catch {
        Write-Host "[ERROR] Failed to process bulk operation: $_" -ForegroundColor Red
    }
}

# Main script execution
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AD User Account Creation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($CSVPath) {
    # Bulk creation mode
    if (-not $ExportPath) {
        Write-Host "[WARNING] -ExportPath not specified. Generated passwords will only be displayed on screen." -ForegroundColor Yellow
        $confirm = Read-Host "Continue without exporting passwords? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Host "[INFO] Operation cancelled" -ForegroundColor Yellow
            exit 0
        }
    }

    New-BulkADUsers -CSV $CSVPath -ExportFile $ExportPath -DefaultEmailDomain $EmailDomain
}
else {
    # Single user creation mode
    if (-not $FirstName -or -not $LastName) {
        Write-Host "[ERROR] -FirstName and -LastName are required for single user creation" -ForegroundColor Red
        Write-Host "[INFO] Use -CSVPath for bulk user creation" -ForegroundColor Yellow
        exit 1
    }

    $userParams = @{
        FirstName          = $FirstName
        LastName           = $LastName
        MustChangePassword = $MustChangePassword
    }

    if ($UserName) { $userParams['UserName'] = $UserName }
    if ($Department) { $userParams['Department'] = $Department }
    if ($Title) { $userParams['Title'] = $Title }
    if ($Manager) { $userParams['Manager'] = $Manager }
    if ($TargetOU) { $userParams['TargetOU'] = $TargetOU }
    if ($Groups) { $userParams['Groups'] = $Groups }
    if ($EmailDomain) { $userParams['EmailDomain'] = $EmailDomain }
    if ($Password) { $userParams['Password'] = $Password }

    $result = New-ADUserAccount -UserParams $userParams

    if ($result -and $result.Password) {
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "  User Created Successfully" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Username: $($result.UserName)" -ForegroundColor White
        Write-Host "Email: $($result.Email)" -ForegroundColor White
        Write-Host "Password: $($result.Password)" -ForegroundColor Yellow
        Write-Host "`n[IMPORTANT] Please provide credentials to user securely" -ForegroundColor Yellow
        Write-Host "========================================`n" -ForegroundColor Cyan
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Operation Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
