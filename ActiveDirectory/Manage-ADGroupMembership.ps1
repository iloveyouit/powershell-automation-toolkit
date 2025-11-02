<#
.SYNOPSIS
    Manages Active Directory group membership operations.

.DESCRIPTION
    This script provides functions to:
    - Add users to AD groups
    - Remove users from AD groups
    - List all members of a group
    - List all groups a user belongs to
    - Bulk add/remove users from groups using CSV input

.PARAMETER Action
    The action to perform: Add, Remove, ListGroupMembers, ListUserGroups, or BulkAdd

.PARAMETER GroupName
    The name of the Active Directory group

.PARAMETER UserName
    The username (SamAccountName) of the user

.PARAMETER CSVPath
    Path to CSV file for bulk operations (requires columns: UserName, GroupName)

.PARAMETER ExportPath
    Path to export membership lists to CSV

.EXAMPLE
    .\Manage-ADGroupMembership.ps1 -Action Add -GroupName "IT-Support" -UserName "jdoe"

    Adds user 'jdoe' to the 'IT-Support' group.

.EXAMPLE
    .\Manage-ADGroupMembership.ps1 -Action Remove -GroupName "IT-Support" -UserName "jdoe"

    Removes user 'jdoe' from the 'IT-Support' group.

.EXAMPLE
    .\Manage-ADGroupMembership.ps1 -Action ListGroupMembers -GroupName "IT-Support" -ExportPath "C:\Reports\IT-Support-Members.csv"

    Lists all members of the 'IT-Support' group and exports to CSV.

.EXAMPLE
    .\Manage-ADGroupMembership.ps1 -Action ListUserGroups -UserName "jdoe"

    Lists all groups that user 'jdoe' belongs to.

.EXAMPLE
    .\Manage-ADGroupMembership.ps1 -Action BulkAdd -CSVPath "C:\Input\users.csv"

    Bulk adds users to groups based on CSV input file.

.NOTES
    Author: System Administrator
    Date: 2025-11-01
    Requires: Active Directory PowerShell module
    Version: 1.0

    CSV Format for BulkAdd:
    UserName,GroupName
    jdoe,IT-Support
    jsmith,Developers
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Add", "Remove", "ListGroupMembers", "ListUserGroups", "BulkAdd", "BulkRemove")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$GroupName,

    [Parameter(Mandatory = $false)]
    [string]$UserName,

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

# Function to add user to group
function Add-UserToGroup {
    param(
        [string]$User,
        [string]$Group
    )

    try {
        # Verify user exists
        $adUser = Get-ADUser -Identity $User -ErrorAction Stop

        # Verify group exists
        $adGroup = Get-ADGroup -Identity $Group -ErrorAction Stop

        # Check if user is already a member
        $isMember = Get-ADGroupMember -Identity $Group | Where-Object { $_.SamAccountName -eq $User }

        if ($isMember) {
            Write-Host "[WARNING] User '$User' is already a member of '$Group'" -ForegroundColor Yellow
            return $false
        }

        # Add user to group
        Add-ADGroupMember -Identity $Group -Members $User -ErrorAction Stop
        Write-Host "[SUCCESS] Added user '$User' to group '$Group'" -ForegroundColor Green
        return $true
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Host "[ERROR] User '$User' or Group '$Group' not found" -ForegroundColor Red
        return $false
    }
    catch {
        Write-Host "[ERROR] Failed to add user '$User' to group '$Group': $_" -ForegroundColor Red
        return $false
    }
}

# Function to remove user from group
function Remove-UserFromGroup {
    param(
        [string]$User,
        [string]$Group
    )

    try {
        # Verify user exists
        $adUser = Get-ADUser -Identity $User -ErrorAction Stop

        # Verify group exists
        $adGroup = Get-ADGroup -Identity $Group -ErrorAction Stop

        # Check if user is a member
        $isMember = Get-ADGroupMember -Identity $Group | Where-Object { $_.SamAccountName -eq $User }

        if (-not $isMember) {
            Write-Host "[WARNING] User '$User' is not a member of '$Group'" -ForegroundColor Yellow
            return $false
        }

        # Remove user from group
        Remove-ADGroupMember -Identity $Group -Members $User -Confirm:$false -ErrorAction Stop
        Write-Host "[SUCCESS] Removed user '$User' from group '$Group'" -ForegroundColor Green
        return $true
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Host "[ERROR] User '$User' or Group '$Group' not found" -ForegroundColor Red
        return $false
    }
    catch {
        Write-Host "[ERROR] Failed to remove user '$User' from group '$Group': $_" -ForegroundColor Red
        return $false
    }
}

# Function to list group members
function Get-GroupMembersList {
    param(
        [string]$Group,
        [string]$ExportFile
    )

    try {
        # Verify group exists
        $adGroup = Get-ADGroup -Identity $Group -ErrorAction Stop
        Write-Host "[INFO] Retrieving members of group '$Group'..." -ForegroundColor Yellow

        # Get group members
        $members = Get-ADGroupMember -Identity $Group -ErrorAction Stop |
            Select-Object Name, SamAccountName, ObjectClass, @{Name='Email';Expression={(Get-ADUser $_.SamAccountName -Properties EmailAddress).EmailAddress}}

        if ($members.Count -eq 0) {
            Write-Host "[WARNING] Group '$Group' has no members" -ForegroundColor Yellow
            return
        }

        Write-Host "[SUCCESS] Found $($members.Count) members in group '$Group'" -ForegroundColor Green

        if ($ExportFile) {
            $members | Export-Csv -Path $ExportFile -NoTypeInformation -Encoding UTF8
            Write-Host "[SUCCESS] Exported to: $ExportFile" -ForegroundColor Green
        }
        else {
            $members | Format-Table -AutoSize
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Host "[ERROR] Group '$Group' not found" -ForegroundColor Red
    }
    catch {
        Write-Host "[ERROR] Failed to retrieve group members: $_" -ForegroundColor Red
    }
}

# Function to list user's group memberships
function Get-UserGroupsList {
    param(
        [string]$User,
        [string]$ExportFile
    )

    try {
        # Verify user exists
        $adUser = Get-ADUser -Identity $User -ErrorAction Stop
        Write-Host "[INFO] Retrieving groups for user '$User'..." -ForegroundColor Yellow

        # Get user's groups
        $groups = Get-ADPrincipalGroupMembership -Identity $User -ErrorAction Stop |
            Select-Object Name, GroupCategory, GroupScope, @{Name='Description';Expression={(Get-ADGroup $_.Name -Properties Description).Description}}

        Write-Host "[SUCCESS] User '$User' is a member of $($groups.Count) groups" -ForegroundColor Green

        if ($ExportFile) {
            $groups | Export-Csv -Path $ExportFile -NoTypeInformation -Encoding UTF8
            Write-Host "[SUCCESS] Exported to: $ExportFile" -ForegroundColor Green
        }
        else {
            $groups | Format-Table -AutoSize
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        Write-Host "[ERROR] User '$User' not found" -ForegroundColor Red
    }
    catch {
        Write-Host "[ERROR] Failed to retrieve user groups: $_" -ForegroundColor Red
    }
}

# Function for bulk operations
function Invoke-BulkOperation {
    param(
        [string]$CSV,
        [string]$OperationType
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
        if (-not ($data[0].PSObject.Properties.Name -contains 'UserName' -and
                  $data[0].PSObject.Properties.Name -contains 'GroupName')) {
            Write-Host "[ERROR] CSV must contain 'UserName' and 'GroupName' columns" -ForegroundColor Red
            return
        }

        Write-Host "[INFO] Processing $($data.Count) entries from CSV..." -ForegroundColor Yellow

        $successCount = 0
        $failCount = 0

        foreach ($entry in $data) {
            $result = if ($OperationType -eq "Add") {
                Add-UserToGroup -User $entry.UserName -Group $entry.GroupName
            }
            else {
                Remove-UserFromGroup -User $entry.UserName -Group $entry.GroupName
            }

            if ($result) {
                $successCount++
            }
            else {
                $failCount++
            }
        }

        Write-Host "`n[SUMMARY] Bulk operation complete:" -ForegroundColor Cyan
        Write-Host "  Successful: $successCount" -ForegroundColor Green
        Write-Host "  Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
    }
    catch {
        Write-Host "[ERROR] Failed to process bulk operation: $_" -ForegroundColor Red
    }
}

# Main script execution
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AD Group Membership Management" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

switch ($Action) {
    "Add" {
        if (-not $GroupName -or -not $UserName) {
            Write-Host "[ERROR] Both -GroupName and -UserName are required for Add action" -ForegroundColor Red
            exit 1
        }
        Add-UserToGroup -User $UserName -Group $GroupName
    }

    "Remove" {
        if (-not $GroupName -or -not $UserName) {
            Write-Host "[ERROR] Both -GroupName and -UserName are required for Remove action" -ForegroundColor Red
            exit 1
        }
        Remove-UserFromGroup -User $UserName -Group $GroupName
    }

    "ListGroupMembers" {
        if (-not $GroupName) {
            Write-Host "[ERROR] -GroupName is required for ListGroupMembers action" -ForegroundColor Red
            exit 1
        }
        Get-GroupMembersList -Group $GroupName -ExportFile $ExportPath
    }

    "ListUserGroups" {
        if (-not $UserName) {
            Write-Host "[ERROR] -UserName is required for ListUserGroups action" -ForegroundColor Red
            exit 1
        }
        Get-UserGroupsList -User $UserName -ExportFile $ExportPath
    }

    "BulkAdd" {
        if (-not $CSVPath) {
            Write-Host "[ERROR] -CSVPath is required for BulkAdd action" -ForegroundColor Red
            exit 1
        }
        Invoke-BulkOperation -CSV $CSVPath -OperationType "Add"
    }

    "BulkRemove" {
        if (-not $CSVPath) {
            Write-Host "[ERROR] -CSVPath is required for BulkRemove action" -ForegroundColor Red
            exit 1
        }
        Invoke-BulkOperation -CSV $CSVPath -OperationType "Remove"
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Operation Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
