# ActiveDirectory Scripts

Scripts for Active Directory management and daily operations.

## Overview

This collection provides PowerShell scripts to automate common Active Directory tasks, including user account management, group membership operations, inactive account cleanup, and password management.

## Prerequisites

- Active Directory PowerShell module
- Appropriate permissions in Active Directory
- PowerShell 5.1 or higher

## Scripts

### 1. Get-ADUserReport.ps1

Generates comprehensive reports on Active Directory user accounts with various filtering and export options.

**Features:**
- Filter users by department, enabled/disabled status, or OU
- Export to CSV, HTML, or console output
- Include password expiration information
- Track password policy compliance

**Common Use Cases:**
```powershell
# Display all users in console
.\Get-ADUserReport.ps1

# Export IT department users to CSV
.\Get-ADUserReport.ps1 -Department "IT" -ExportFormat CSV -OutputPath "C:\Reports\IT_Users.csv"

# Generate HTML report of disabled accounts
.\Get-ADUserReport.ps1 -Enabled $false -ExportFormat HTML -OutputPath "C:\Reports\DisabledUsers.html"

# Check password expiration for all users
.\Get-ADUserReport.ps1 -IncludePasswordInfo -ExportFormat CSV -OutputPath "C:\Reports\PasswordExpiry.csv"
```

---

### 2. Manage-ADGroupMembership.ps1

Manages Active Directory group membership operations including bulk operations from CSV files.

**Features:**
- Add/remove users from groups
- List all members of a group
- List all groups a user belongs to
- Bulk operations via CSV import
- Export membership lists to CSV

**Common Use Cases:**
```powershell
# Add user to a group
.\Manage-ADGroupMembership.ps1 -Action Add -GroupName "IT-Support" -UserName "jdoe"

# Remove user from a group
.\Manage-ADGroupMembership.ps1 -Action Remove -GroupName "IT-Support" -UserName "jdoe"

# List all members of a group
.\Manage-ADGroupMembership.ps1 -Action ListGroupMembers -GroupName "IT-Support"

# Export group members to CSV
.\Manage-ADGroupMembership.ps1 -Action ListGroupMembers -GroupName "IT-Support" -ExportPath "C:\Reports\IT-Members.csv"

# List all groups for a user
.\Manage-ADGroupMembership.ps1 -Action ListUserGroups -UserName "jdoe"

# Bulk add users to groups from CSV
.\Manage-ADGroupMembership.ps1 -Action BulkAdd -CSVPath "C:\Input\users.csv"
```

**CSV Format for Bulk Operations:**
```csv
UserName,GroupName
jdoe,IT-Support
jsmith,Developers
alee,IT-Support
```

---

### 3. Find-InactiveADAccounts.ps1

Identifies inactive user and computer accounts based on last logon date for cleanup and security operations.

**Features:**
- Find inactive user accounts
- Find inactive computer accounts
- Configurable inactivity threshold
- Report, disable, or move inactive accounts
- Export results to CSV
- OU-specific searches

**Common Use Cases:**
```powershell
# Find users inactive for 90+ days
.\Find-InactiveADAccounts.ps1 -InactiveDays 90 -ExportPath "C:\Reports\InactiveUsers.csv"

# Find inactive computers in last 60 days
.\Find-InactiveADAccounts.ps1 -AccountType Computer -InactiveDays 60

# Disable accounts inactive for 180+ days
.\Find-InactiveADAccounts.ps1 -InactiveDays 180 -Action Disable

# Move inactive accounts to disabled OU
.\Find-InactiveADAccounts.ps1 -InactiveDays 90 -Action Move -TargetOU "OU=Disabled,DC=company,DC=com"

# Search specific OU only
.\Find-InactiveADAccounts.ps1 -SearchBase "OU=Sales,DC=company,DC=com" -InactiveDays 60
```

---

### 4. New-ADUserAccount.ps1

Creates new Active Directory user accounts with standardized configuration and bulk creation capabilities.

**Features:**
- Create single or bulk user accounts
- Auto-generate usernames from first/last names
- Generate secure random passwords
- Assign users to groups during creation
- Set manager and organizational information
- Export credentials to secure CSV files
- Bulk creation from CSV input

**Common Use Cases:**
```powershell
# Create single user with auto-generated credentials
.\New-ADUserAccount.ps1 -FirstName "John" -LastName "Doe" -Department "IT" -Title "System Administrator" -EmailDomain "company.com"

# Create user and assign to groups
.\New-ADUserAccount.ps1 -FirstName "Jane" -LastName "Smith" -Department "Sales" -Groups @("Sales-Team","Office365-Users") -EmailDomain "company.com"

# Create user with specific username and manager
.\New-ADUserAccount.ps1 -FirstName "Bob" -LastName "Johnson" -UserName "bjohnson" -Manager "jdoe" -Department "IT"

# Bulk create users from CSV
.\New-ADUserAccount.ps1 -CSVPath "C:\Input\newusers.csv" -ExportPath "C:\Output\credentials.csv"
```

**CSV Format for Bulk Creation:**
```csv
FirstName,LastName,Department,Title,Manager,Groups,TargetOU
John,Doe,IT,Admin,jmanager,"IT-Support;Office365-Users","OU=IT,DC=company,DC=com"
Jane,Smith,Sales,Rep,smanager,"Sales-Team;Office365-Users","OU=Sales,DC=company,DC=com"
```

---

### 5. Reset-ADUserPassword.ps1

Manages user password resets with secure password generation and account unlock functionality.

**Features:**
- Reset passwords with auto-generated secure passwords
- Manual password specification
- Unlock locked accounts
- Force password change at next logon
- Bulk password reset operations
- Export generated passwords securely to CSV

**Common Use Cases:**
```powershell
# Reset password with auto-generated secure password
.\Reset-ADUserPassword.ps1 -Action Reset -UserName "jdoe"

# Reset password to specific value
.\Reset-ADUserPassword.ps1 -Action Reset -UserName "jdoe" -Password (ConvertTo-SecureString "NewP@ssw0rd123" -AsPlainText -Force)

# Reset password without forcing change at next logon
.\Reset-ADUserPassword.ps1 -Action Reset -UserName "jdoe" -MustChangePassword $false

# Unlock account
.\Reset-ADUserPassword.ps1 -Action Unlock -UserName "jdoe"

# Force user to change password at next logon
.\Reset-ADUserPassword.ps1 -Action ForceChange -UserName "jdoe"

# Bulk password reset from CSV
.\Reset-ADUserPassword.ps1 -Action BulkReset -CSVPath "C:\Input\users.csv" -ExportPath "C:\Output\passwords.csv"
```

**CSV Format for Bulk Reset:**
```csv
UserName
jdoe
jsmith
alee
```

**Security Note:** Always store exported password files in a secure location and transmit passwords to users through secure channels.

---

### 6. Sync-ADGroupMemberships.ps1

Synchronizes Active Directory group memberships between users or applies group membership templates.

**Features:**
- Copy all group memberships from one user to another
- Compare group memberships between users
- Create reusable group membership templates
- Apply templates to multiple users
- Export comparison reports
- Optionally remove existing groups before applying new ones

**Common Use Cases:**
```powershell
# Copy groups from one user to another
.\Sync-ADGroupMemberships.ps1 -Action CopyUser -SourceUser "jdoe" -TargetUser "jsmith"

# Compare group memberships between users
.\Sync-ADGroupMemberships.ps1 -Action Compare -SourceUser "jdoe" -TargetUser "jsmith" -ExportPath "C:\Reports\comparison.csv"

# Create template from existing user
.\Sync-ADGroupMemberships.ps1 -Action CreateTemplate -SourceUser "jdoe" -TemplateName "IT-Admin-Template" -TemplateFile "C:\Templates\it-admin.json"

# Create template from group list
.\Sync-ADGroupMemberships.ps1 -Action CreateTemplate -Groups @("IT-Support","Developers","VPN-Users") -TemplateFile "C:\Templates\custom.json"

# Apply template to single user
.\Sync-ADGroupMemberships.ps1 -Action ApplyTemplate -TemplateFile "C:\Templates\it-admin.json" -TargetUser "newuser"

# Apply template to multiple users
.\Sync-ADGroupMemberships.ps1 -Action ApplyTemplate -TemplateFile "C:\Templates\it-admin.json" -TargetUsers @("user1","user2","user3")

# Replace all groups with template (remove existing first)
.\Sync-ADGroupMemberships.ps1 -Action ApplyTemplate -TemplateFile "C:\Templates\sales.json" -TargetUser "jsmith" -RemoveExisting
```

**Template File Format (JSON):**
```json
{
  "Name": "IT-Admin-Template",
  "Description": "Group membership template",
  "Created": "2025-11-01 10:30:00",
  "Groups": [
    "IT-Support",
    "Developers",
    "VPN-Users",
    "Office365-Users"
  ]
}
```

---

## Best Practices

1. **Permissions**: Run scripts with appropriate AD permissions. Use dedicated service accounts where possible.

2. **Testing**: Test scripts in a non-production environment first, especially for bulk operations or actions that modify accounts.

3. **Logging**: Review script output and save logs for audit purposes.

4. **Backup**: Always have a backup strategy before performing bulk modifications.

5. **Security**:
   - Store password export files securely
   - Use encrypted connections
   - Follow your organization's password policies
   - Regularly audit inactive accounts

6. **Scheduling**: Consider scheduling regular reports using Task Scheduler for proactive account management.

## Common Workflows

### New Employee Onboarding
```powershell
# Create user account
.\New-ADUserAccount.ps1 -FirstName "John" -LastName "Doe" -Department "Sales" -Title "Sales Rep" -Manager "smanager" -EmailDomain "company.com"

# Copy group memberships from similar user
.\Sync-ADGroupMemberships.ps1 -Action CopyUser -SourceUser "template-sales-user" -TargetUser "john.doe"

# Or apply a department template
.\Sync-ADGroupMemberships.ps1 -Action ApplyTemplate -TemplateFile "C:\Templates\sales-standard.json" -TargetUser "john.doe"
```

### Employee Offboarding
```powershell
# Find user's group memberships
.\Manage-ADGroupMembership.ps1 -Action ListUserGroups -UserName "exiting-user"

# Disable account and move to disabled OU
Disable-ADAccount -Identity "exiting-user"
```

### Monthly Security Audit
```powershell
# Find inactive accounts
.\Find-InactiveADAccounts.ps1 -InactiveDays 90 -ExportPath "C:\Reports\Monthly\Inactive-$(Get-Date -Format 'yyyy-MM').csv"

# Check password expirations
.\Get-ADUserReport.ps1 -IncludePasswordInfo -ExportPath "C:\Reports\Monthly\PasswordExpiry-$(Get-Date -Format 'yyyy-MM').csv"
```

### Bulk Password Reset After Security Incident
```powershell
# Reset passwords for affected users
.\Reset-ADUserPassword.ps1 -Action BulkReset -CSVPath "C:\Input\affected-users.csv" -ExportPath "C:\Secure\new-passwords.csv"
```

## Troubleshooting

### Common Issues

**"Access Denied" errors:**
- Verify you have appropriate AD permissions
- Run PowerShell as Administrator
- Check if your account can modify target OUs

**"Module not found" errors:**
- Install RSAT tools: `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0`
- Import module manually: `Import-Module ActiveDirectory`

**CSV import failures:**
- Verify CSV format matches expected columns
- Check for UTF-8 encoding
- Remove any BOM (Byte Order Mark) characters

## Support and Contributions

For issues, improvements, or questions, please refer to the main repository documentation.

### Role Change / Department Transfer
```powershell
# Compare current groups with new role requirements
.\Sync-ADGroupMemberships.ps1 -Action Compare -SourceUser "user-new-role" -TargetUser "template-manager" -ExportPath "C:\Reports\role-change-analysis.csv"

# Apply new role template
.\Sync-ADGroupMemberships.ps1 -Action ApplyTemplate -TemplateFile "C:\Templates\manager-role.json" -TargetUser "user-new-role" -RemoveExisting
```

### Bulk New Hire Onboarding
```powershell
# Create all new users from HR CSV
.\New-ADUserAccount.ps1 -CSVPath "C:\HR\new-hires-november.csv" -ExportPath "C:\Secure\new-hire-credentials.csv"

# Apply department-specific templates to groups
.\Sync-ADGroupMemberships.ps1 -Action ApplyTemplate -TemplateFile "C:\Templates\sales-standard.json" -TargetUsers @("user1","user2","user3")
```

## Quick Reference

| Task | Script | Key Parameters |
|------|--------|----------------|
| Generate user report | Get-ADUserReport.ps1 | -ExportFormat, -Department, -IncludePasswordInfo |
| Create new user | New-ADUserAccount.ps1 | -FirstName, -LastName, -Department, -Groups |
| Reset password | Reset-ADUserPassword.ps1 | -Action Reset, -UserName |
| Add user to group | Manage-ADGroupMembership.ps1 | -Action Add, -GroupName, -UserName |
| Find inactive accounts | Find-InactiveADAccounts.ps1 | -InactiveDays, -AccountType, -Action |
| Copy group memberships | Sync-ADGroupMemberships.ps1 | -Action CopyUser, -SourceUser, -TargetUser |

## Version History

- **v1.0** (2025-11-01): Initial release with 6 core AD management scripts
  - Get-ADUserReport.ps1: User reporting and analysis
  - Manage-ADGroupMembership.ps1: Group membership operations
  - Find-InactiveADAccounts.ps1: Inactive account detection
  - New-ADUserAccount.ps1: User account creation
  - Reset-ADUserPassword.ps1: Password management
  - Sync-ADGroupMemberships.ps1: Group membership synchronization
