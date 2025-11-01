# Getting Started with PowerShell Automation Toolkit

Welcome! This guide will help you get up and running with the PowerShell Automation Toolkit.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Initial Configuration](#initial-configuration)
4. [Your First Script](#your-first-script)
5. [Common Workflows](#common-workflows)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)
8. [Next Steps](#next-steps)

## Prerequisites

### Required Software

1. **PowerShell**
   - Windows PowerShell 5.1 (minimum)
   - PowerShell 7+ (recommended)
   - Check version: `$PSVersionTable.PSVersion`

2. **Operating System**
   - Windows Server 2016 or later
   - Windows 10/11 (for workstation scripts)

3. **Permissions**
   - Administrator rights (for most scripts)
   - Appropriate domain permissions (for AD scripts)
   - Azure AD permissions (for cloud scripts)

### Optional Tools

- **Git**: For version control
- **VS Code**: Recommended editor
- **Pester**: For testing (install via `Install-Module Pester`)
- **PSScriptAnalyzer**: Code quality tool

## Installation

### Method 1: Git Clone (Recommended)

```powershell
# Clone the repository
git clone https://github.com/YOUR-USERNAME/powershell-automation-toolkit.git

# Navigate to the directory
cd powershell-automation-toolkit

# Verify structure
Get-ChildItem
```

### Method 2: Download ZIP

1. Download from GitHub: `Code > Download ZIP`
2. Extract to desired location (e.g., `C:\Scripts\`)
3. Unblock files:
   ```powershell
   Get-ChildItem -Recurse | Unblock-File
   ```

### Verify Installation

```powershell
# Check directory structure
Test-Path .\Azure\Fix-ADSync-PHS.ps1
Test-Path .\Networking\Test-RemoteServerAccess.ps1
Test-Path .\Maintenance\Enterprise-DriveCleanup.ps1

# All should return True
```

## Initial Configuration

### 1. Set Execution Policy

```powershell
# Check current policy
Get-ExecutionPolicy

# Set for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or for entire machine (requires admin)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### 2. Configure Logging

```powershell
# Create default log directory
New-Item -Path "C:\Logs" -ItemType Directory -Force

# Set permissions (optional)
icacls "C:\Logs" /grant "Administrators:(OI)(CI)F"
```

### 3. Test Prerequisites

```powershell
# Test PowerShell version
if ($PSVersionTable.PSVersion.Major -ge 5) {
    Write-Host "✓ PowerShell version OK" -ForegroundColor Green
}

# Test admin rights
if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "✓ Running as Administrator" -ForegroundColor Green
}

# Test module availability
$requiredModules = @('ActiveDirectory', 'ADSync')
foreach ($module in $requiredModules) {
    if (Get-Module -ListAvailable -Name $module) {
        Write-Host "✓ Module $module available" -ForegroundColor Green
    } else {
        Write-Host "⚠ Module $module not found" -ForegroundColor Yellow
    }
}
```

## Your First Script

Let's run a simple connectivity test to verify everything works.

### Example 1: Test Remote Server Access

```powershell
# Navigate to the repository
cd C:\Scripts\powershell-automation-toolkit

# Run connectivity test on localhost
.\Networking\Test-RemoteServerAccess.ps1 -ComputerName localhost -Verbose

# Expected output:
# ✓ DNS Resolution: Success
# ✓ Ping: Success  
# ✓ WinRM: Available
# ✓ Remote PowerShell: Success
```

### Example 2: Dry-Run Disk Cleanup

```powershell
# Simulate cleanup without making changes
.\Maintenance\Enterprise-DriveCleanup.ps1 -DryRun -Verbose

# Review what would be cleaned:
# [DRYRUN] Would delete: C:\Windows\Temp\* (2.3 GB)
# [DRYRUN] Would delete: Update cache (5.1 GB)
# Total that would be recovered: 7.4 GB
```

### Example 3: Azure AD Connect Check

```powershell
# Check Azure AD Connect status (dry-run)
.\Azure\Fix-ADSync-PHS.ps1 -DryRun

# Review the checks:
# ✓ ADSync Service: Running
# ✓ Scheduler: Enabled
# ✓ Last Sync: 15 minutes ago
# ✓ Disk Space: 45 GB free
```

## Common Workflows

### Workflow 1: Server Onboarding Check

```powershell
# Create server list
$servers = @(
    "SERVER01",
    "SERVER02",
    "SERVER03"
)

# Test connectivity
.\Networking\Test-RemoteServerAccess.ps1 -ComputerName $servers -ExportResults

# Review results
Import-Csv .\RemoteAccess_Results_*.csv | Format-Table
```

### Workflow 2: Maintenance Window

```powershell
# 1. Perform health check
.\Maintenance\Server-HealthCheck.ps1 -GenerateReport

# 2. Run cleanup (dry-run first)
.\Maintenance\Enterprise-DriveCleanup.ps1 -DryRun

# 3. If satisfied, run actual cleanup
.\Maintenance\Enterprise-DriveCleanup.ps1

# 4. Verify results
Get-PSDrive C | Select-Object Used, Free
```

### Workflow 3: Azure AD Connect Monitoring

```powershell
# 1. Check current status
.\Azure\Fix-ADSync-PHS.ps1 -DryRun

# 2. If issues found, run fix
.\Azure\Fix-ADSync-PHS.ps1

# 3. Verify sync completed
Get-ADSyncScheduler

# 4. Check last sync time
Get-ADSyncConnectorRunStatus
```

## Best Practices

### 1. Always Use -WhatIf or -DryRun First

```powershell
# Good practice
.\Script.ps1 -DryRun
# Review output, then:
.\Script.ps1

# For built-in cmdlets
Remove-Item -Path "C:\Temp\*" -WhatIf
```

### 2. Enable Verbose Logging

```powershell
# See what the script is doing
.\Script.ps1 -Verbose

# Or set preference
$VerbosePreference = "Continue"
.\Script.ps1
```

### 3. Save Credentials Securely

```powershell
# Never do this:
$password = "MyPassword123"  # BAD!

# Instead, do this:
$cred = Get-Credential
# Or use Windows Credential Manager

# For automated scripts:
$securePassword = ConvertTo-SecureString "password" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential("username", $securePassword)
```

### 4. Test in Non-Production First

```powershell
# Development environment
.\Script.ps1 -ComputerName DEV-SERVER01

# Verify results, then production
.\Script.ps1 -ComputerName PROD-SERVER01
```

### 5. Review Logs After Execution

```powershell
# Check latest log
Get-ChildItem C:\Logs\ScriptName\*.log -File | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1 | 
    Get-Content -Tail 50
```

## Troubleshooting

### Issue: "Execution Policy" Error

```powershell
# Error: cannot be loaded because running scripts is disabled

# Solution:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: "Access Denied"

```powershell
# Error: Access to the path is denied

# Solution: Run as Administrator
# Right-click PowerShell > Run as Administrator

# Or use elevation:
Start-Process powershell -Verb RunAs -ArgumentList "-File C:\Scripts\Script.ps1"
```

### Issue: Module Not Found

```powershell
# Error: The term 'Get-ADUser' is not recognized

# Solution: Install required module
Install-WindowsFeature RSAT-AD-PowerShell

# Or for desktop:
Install-Module -Name ActiveDirectory
```

### Issue: WinRM Not Enabled

```powershell
# Error: WinRM cannot process the request

# Solution: Enable WinRM
Enable-PSRemoting -Force

# Configure trusted hosts (if needed)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
```

### Issue: Script Hangs

```powershell
# If script appears frozen:
# 1. Press Ctrl+C to cancel
# 2. Check logs for last operation
# 3. Add -Verbose to see progress
# 4. Reduce timeout values

.\Script.ps1 -Timeout 10 -Verbose
```

## Next Steps

### 1. Customize Scripts

```powershell
# Copy script to customize
Copy-Item .\Azure\Fix-ADSync-PHS.ps1 .\Azure\Fix-ADSync-PHS-Custom.ps1

# Edit for your environment
# - Update email settings
# - Modify log paths
# - Adjust thresholds
```

### 2. Schedule Automation

```powershell
# Create scheduled task for regular maintenance
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Scripts\Maintenance\Enterprise-DriveCleanup.ps1"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am

Register-ScheduledTask -TaskName "Weekly Maintenance" `
    -Action $action -Trigger $trigger -RunLevel Highest
```

### 3. Build Your Own Scripts

```powershell
# Use templates as starting point
Copy-Item .\templates\Script-Template.ps1 .\Utilities\My-Custom-Script.ps1

# Review contributing guidelines
Get-Content .\CONTRIBUTING.md

# Follow the patterns in existing scripts
```

### 4. Join the Community

- ⭐ Star the repository on GitHub
- 🐛 Report issues you encounter
- 💡 Suggest new features
- 🤝 Contribute improvements
- 📖 Improve documentation

## Quick Reference

### Common Commands

```powershell
# Get help for a script
Get-Help .\Script.ps1 -Full

# List parameters
Get-Help .\Script.ps1 -Parameter *

# See examples
Get-Help .\Script.ps1 -Examples

# Check script syntax
Test-Path .\Script.ps1

# Run with all safety options
.\Script.ps1 -DryRun -Verbose -WhatIf
```

### Useful Aliases

```powershell
# Create shortcuts
New-Alias -Name test-remote -Value "C:\Scripts\powershell-automation-toolkit\Networking\Test-RemoteServerAccess.ps1"

# Save to profile
$profile | Get-Content
# Add your aliases there
```

## Need Help?

- 📖 **Documentation**: Check the `/docs` directory
- 🔍 **Search Issues**: [GitHub Issues](https://github.com/YOUR-USERNAME/powershell-automation-toolkit/issues)
- 💬 **Ask Questions**: [GitHub Discussions](https://github.com/YOUR-USERNAME/powershell-automation-toolkit/discussions)
- 🐛 **Report Bugs**: Create a new issue with details

## Resources

- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- [Repository Wiki](https://github.com/YOUR-USERNAME/powershell-automation-toolkit/wiki)

---

**Congratulations!** You're now ready to use the PowerShell Automation Toolkit. Happy automating! 🚀

**Last Updated:** November 2025
