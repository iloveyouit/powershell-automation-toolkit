<#
.SYNOPSIS
    Synchronizes Active Directory group memberships between users or from templates.

.DESCRIPTION
    This script provides functions to:
    - Copy group memberships from one user to another
    - Synchronize groups based on department or role
    - Create group membership templates
    - Apply templates to multiple users
    - Generate group membership comparison reports

.PARAMETER Action
    The action to perform: CopyUser, ApplyTemplate, Compare, or CreateTemplate

.PARAMETER SourceUser
    Source username to copy group memberships from

.PARAMETER TargetUser
    Target username to apply group memberships to

.PARAMETER TargetUsers
    Array of target usernames for bulk operations

.PARAMETER TemplateName
    Name of the group membership template

.PARAMETER TemplateFile
    Path to JSON file containing group membership template

.PARAMETER Groups
    Array of group names to include in template

.PARAMETER ExportPath
    Path to export comparison reports or templates

.PARAMETER RemoveExisting
    Remove existing group memberships before applying new ones (default: $false)

.EXAMPLE
    .\Sync-ADGroupMemberships.ps1 -Action CopyUser -SourceUser "jdoe" -TargetUser "jsmith"

    Copies all group memberships from jdoe to jsmith.

.EXAMPLE
    .\Sync-ADGroupMemberships.ps1 -Action Compare -SourceUser "jdoe" -TargetUser "jsmith" -ExportPath "C:\Reports\comparison.csv"

    Compares group memberships between two users and exports the differences.

.EXAMPLE
    .\Sync-ADGroupMemberships.ps1 -Action CreateTemplate -SourceUser "jdoe" -TemplateName "IT-Admin-Template" -TemplateFile "C:\Templates\it-admin.json"

    Creates a group membership template based on a user's current groups.

.EXAMPLE
    .\Sync-ADGroupMemberships.ps1 -Action ApplyTemplate -TemplateFile "C:\Templates\it-admin.json" -TargetUsers @("user1","user2","user3")

    Applies a group membership template to multiple users.

.NOTES
    Author: System Administrator
    Date: 2025-11-01
    Requires: Active Directory PowerShell module
    Version: 1.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("CopyUser", "ApplyTemplate", "Compare", "CreateTemplate")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$SourceUser,

    [Parameter(Mandatory = $false)]
    [string]$TargetUser,

    [Parameter(Mandatory = $false)]
    [string[]]$TargetUsers,

    [Parameter(Mandatory = $false)]
    [string]$TemplateName,

    [Parameter(Mandatory = $false)]
    [string]$TemplateFile,

    [Parameter(Mandatory = $false)]
    [string[]]$Groups,

    [Parameter(Mandatory = $false)]
    [string]$ExportPath,

    [Parameter(Mandatory = $false)]
    [switch]$RemoveExisting
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

# Function to get user's group memberships
function Get-UserGroupMemberships {
    param([string]$User)

    try {
        $groups = Get-ADPrincipalGroupMembership -Identity $User -ErrorAction Stop |
            Select-Object Name, DistinguishedName, GroupCategory, GroupScope

        return $groups
    }
    catch {
        Write-Host "[ERROR] Failed to retrieve groups for user '$User': $_" -ForegroundColor Red
        return $null
    }
}

# Function to copy group memberships from one user to another
function Copy-UserGroupMemberships {
    param(
        [string]$Source,
        [string]$Target,
        [bool]$RemoveExistingGroups = $false
    )

    try {
        # Verify both users exist
        $sourceUser = Get-ADUser -Identity $Source -ErrorAction Stop
        $targetUser = Get-ADUser -Identity $Target -ErrorAction Stop

        Write-Host "[INFO] Copying group memberships from '$Source' to '$Target'..." -ForegroundColor Yellow

        # Get source user's groups
        $sourceGroups = Get-UserGroupMemberships -User $Source
        if (-not $sourceGroups) {
            Write-Host "[WARNING] Source user has no group memberships to copy" -ForegroundColor Yellow
            return
        }

        # Get target user's current groups
        $targetGroups = Get-UserGroupMemberships -User $Target
        $targetGroupNames = $targetGroups | Select-Object -ExpandProperty Name

        # Remove existing groups if requested
        if ($RemoveExistingGroups -and $targetGroups) {
            Write-Host "[INFO] Removing existing group memberships from target user..." -ForegroundColor Yellow
            foreach ($group in $targetGroups) {
                # Don't remove primary group (Domain Users)
                if ($group.Name -ne "Domain Users") {
                    try {
                        Remove-ADGroupMember -Identity $group.Name -Members $Target -Confirm:$false -ErrorAction Stop
                        Write-Host "[SUCCESS] Removed from: $($group.Name)" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "[WARNING] Failed to remove from '$($group.Name)': $_" -ForegroundColor Yellow
                    }
                }
            }
        }

        # Add source groups to target user
        $addedCount = 0
        $skippedCount = 0

        foreach ($group in $sourceGroups) {
            # Skip if already a member
            if ($targetGroupNames -contains $group.Name) {
                Write-Host "[SKIP] Already member of: $($group.Name)" -ForegroundColor Gray
                $skippedCount++
                continue
            }

            try {
                Add-ADGroupMember -Identity $group.Name -Members $Target -ErrorAction Stop
                Write-Host "[SUCCESS] Added to: $($group.Name)" -ForegroundColor Green
                $addedCount++
            }
            catch {
                Write-Host "[WARNING] Failed to add to '$($group.Name)': $_" -ForegroundColor Yellow
            }
        }

        Write-Host "`n[SUMMARY] Group membership copy complete:" -ForegroundColor Cyan
        Write-Host "  Groups added: $addedCount" -ForegroundColor Green
        Write-Host "  Already member: $skippedCount" -ForegroundColor Gray
    }
    catch {
        Write-Host "[ERROR] Failed to copy group memberships: $_" -ForegroundColor Red
    }
}

# Function to compare group memberships between users
function Compare-UserGroupMemberships {
    param(
        [string]$User1,
        [string]$User2,
        [string]$ExportFile
    )

    try {
        # Verify both users exist
        $null = Get-ADUser -Identity $User1 -ErrorAction Stop
        $null = Get-ADUser -Identity $User2 -ErrorAction Stop

        Write-Host "[INFO] Comparing group memberships between '$User1' and '$User2'..." -ForegroundColor Yellow

        # Get groups for both users
        $user1Groups = Get-UserGroupMemberships -User $User1
        $user2Groups = Get-UserGroupMemberships -User $User2

        $user1GroupNames = $user1Groups | Select-Object -ExpandProperty Name
        $user2GroupNames = $user2Groups | Select-Object -ExpandProperty Name

        # Find differences
        $onlyInUser1 = $user1GroupNames | Where-Object { $_ -notin $user2GroupNames }
        $onlyInUser2 = $user2GroupNames | Where-Object { $_ -notin $user1GroupNames }
        $inBoth = $user1GroupNames | Where-Object { $_ -in $user2GroupNames }

        # Build comparison report
        $comparisonData = @()

        foreach ($group in ($user1GroupNames + $user2GroupNames | Select-Object -Unique | Sort-Object)) {
            $comparisonData += [PSCustomObject]@{
                GroupName  = $group
                User1      = if ($group -in $user1GroupNames) { "Yes" } else { "No" }
                User2      = if ($group -in $user2GroupNames) { "Yes" } else { "No" }
                Status     = if ($group -in $inBoth) { "Both" }
                             elseif ($group -in $onlyInUser1) { "Only $User1" }
                             else { "Only $User2" }
            }
        }

        # Display summary
        Write-Host "`n[SUMMARY] Group Membership Comparison:" -ForegroundColor Cyan
        Write-Host "  Common groups: $($inBoth.Count)" -ForegroundColor Green
        Write-Host "  Only in $User1: $($onlyInUser1.Count)" -ForegroundColor Yellow
        Write-Host "  Only in $User2: $($onlyInUser2.Count)" -ForegroundColor Yellow

        # Export or display
        if ($ExportFile) {
            $comparisonData | Export-Csv -Path $ExportFile -NoTypeInformation -Encoding UTF8
            Write-Host "`n[SUCCESS] Comparison report exported to: $ExportFile" -ForegroundColor Green
        }
        else {
            Write-Host "`nDetailed Comparison:" -ForegroundColor Cyan
            $comparisonData | Format-Table -AutoSize
        }
    }
    catch {
        Write-Host "[ERROR] Failed to compare group memberships: $_" -ForegroundColor Red
    }
}

# Function to create group membership template
function New-GroupMembershipTemplate {
    param(
        [string]$User,
        [string]$Name,
        [string]$File,
        [string[]]$GroupList
    )

    try {
        $groups = @()

        if ($User) {
            # Create template from user's groups
            $null = Get-ADUser -Identity $User -ErrorAction Stop
            Write-Host "[INFO] Creating template from user '$User'..." -ForegroundColor Yellow

            $userGroups = Get-UserGroupMemberships -User $User
            $groups = $userGroups | Select-Object -ExpandProperty Name
        }
        elseif ($GroupList) {
            # Create template from provided group list
            Write-Host "[INFO] Creating template from provided group list..." -ForegroundColor Yellow
            $groups = $GroupList
        }
        else {
            Write-Host "[ERROR] Either -SourceUser or -Groups must be specified" -ForegroundColor Red
            return
        }

        # Build template object
        $template = @{
            Name        = if ($Name) { $Name } else { "GroupTemplate_$(Get-Date -Format 'yyyyMMdd_HHmmss')" }
            Description = "Group membership template"
            Created     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Groups      = $groups | Sort-Object
        }

        if ($File) {
            # Export to JSON
            $template | ConvertTo-Json -Depth 10 | Out-File -FilePath $File -Encoding UTF8
            Write-Host "[SUCCESS] Template saved to: $File" -ForegroundColor Green
        }
        else {
            # Display template
            Write-Host "`nTemplate Details:" -ForegroundColor Cyan
            Write-Host "Name: $($template.Name)" -ForegroundColor White
            Write-Host "Groups ($($template.Groups.Count)):" -ForegroundColor White
            $template.Groups | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
        }

        return $template
    }
    catch {
        Write-Host "[ERROR] Failed to create template: $_" -ForegroundColor Red
    }
}

# Function to apply group membership template
function Apply-GroupMembershipTemplate {
    param(
        [string]$File,
        [string[]]$Users,
        [bool]$RemoveExistingGroups = $false
    )

    try {
        # Load template
        if (-not (Test-Path $File)) {
            Write-Host "[ERROR] Template file not found: $File" -ForegroundColor Red
            return
        }

        $template = Get-Content -Path $File -Raw | ConvertFrom-Json
        Write-Host "[INFO] Loaded template: $($template.Name)" -ForegroundColor Yellow
        Write-Host "[INFO] Template contains $($template.Groups.Count) groups" -ForegroundColor Yellow

        if (-not $Users -or $Users.Count -eq 0) {
            Write-Host "[ERROR] No target users specified" -ForegroundColor Red
            return
        }

        Write-Host "`n[INFO] Applying template to $($Users.Count) user(s)..." -ForegroundColor Yellow

        foreach ($user in $Users) {
            Write-Host "`nProcessing user: $user" -ForegroundColor Cyan

            try {
                # Verify user exists
                $null = Get-ADUser -Identity $user -ErrorAction Stop

                # Get current groups
                $currentGroups = Get-UserGroupMemberships -User $user
                $currentGroupNames = $currentGroups | Select-Object -ExpandProperty Name

                # Remove existing groups if requested
                if ($RemoveExistingGroups -and $currentGroups) {
                    Write-Host "[INFO] Removing existing groups..." -ForegroundColor Yellow
                    foreach ($group in $currentGroups) {
                        if ($group.Name -ne "Domain Users") {
                            try {
                                Remove-ADGroupMember -Identity $group.Name -Members $user -Confirm:$false -ErrorAction Stop
                            }
                            catch {
                                Write-Host "[WARNING] Failed to remove from '$($group.Name)': $_" -ForegroundColor Yellow
                            }
                        }
                    }
                }

                # Add template groups
                $addedCount = 0
                $skippedCount = 0

                foreach ($groupName in $template.Groups) {
                    if ($currentGroupNames -contains $groupName) {
                        Write-Host "[SKIP] Already member of: $groupName" -ForegroundColor Gray
                        $skippedCount++
                        continue
                    }

                    try {
                        Add-ADGroupMember -Identity $groupName -Members $user -ErrorAction Stop
                        Write-Host "[SUCCESS] Added to: $groupName" -ForegroundColor Green
                        $addedCount++
                    }
                    catch {
                        Write-Host "[WARNING] Failed to add to '$groupName': $_" -ForegroundColor Yellow
                    }
                }

                Write-Host "[SUMMARY] User '$user': Added $addedCount, Skipped $skippedCount" -ForegroundColor Cyan
            }
            catch {
                Write-Host "[ERROR] Failed to process user '$user': $_" -ForegroundColor Red
            }
        }

        Write-Host "`n[SUCCESS] Template application complete" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to apply template: $_" -ForegroundColor Red
    }
}

# Main script execution
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  AD Group Membership Sync" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

switch ($Action) {
    "CopyUser" {
        if (-not $SourceUser -or -not $TargetUser) {
            Write-Host "[ERROR] Both -SourceUser and -TargetUser are required" -ForegroundColor Red
            exit 1
        }
        Copy-UserGroupMemberships -Source $SourceUser -Target $TargetUser -RemoveExistingGroups $RemoveExisting
    }

    "Compare" {
        if (-not $SourceUser -or -not $TargetUser) {
            Write-Host "[ERROR] Both -SourceUser and -TargetUser are required" -ForegroundColor Red
            exit 1
        }
        Compare-UserGroupMemberships -User1 $SourceUser -User2 $TargetUser -ExportFile $ExportPath
    }

    "CreateTemplate" {
        if (-not $SourceUser -and -not $Groups) {
            Write-Host "[ERROR] Either -SourceUser or -Groups must be specified" -ForegroundColor Red
            exit 1
        }
        New-GroupMembershipTemplate -User $SourceUser -Name $TemplateName -File $TemplateFile -GroupList $Groups
    }

    "ApplyTemplate" {
        if (-not $TemplateFile) {
            Write-Host "[ERROR] -TemplateFile is required" -ForegroundColor Red
            exit 1
        }
        if (-not $TargetUsers -and -not $TargetUser) {
            Write-Host "[ERROR] Either -TargetUser or -TargetUsers must be specified" -ForegroundColor Red
            exit 1
        }

        $users = if ($TargetUsers) { $TargetUsers } else { @($TargetUser) }
        Apply-GroupMembershipTemplate -File $TemplateFile -Users $users -RemoveExistingGroups $RemoveExisting
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Operation Complete" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
