# System Maintenance Scripts

PowerShell scripts for system cleanup, maintenance, and optimization.

## 📋 Scripts in This Category

### Enterprise-DriveCleanup.ps1
**Purpose:** Enterprise-level C: drive cleanup for Windows 11 machines

**Features:**
- Windows Update cache cleanup
- Temporary files removal
- User profile cleanup
- Recycle bin management
- System log cleanup
- Shadow copy management
- Comprehensive logging
- Dry-run mode
- Email reporting
- Minimum free space thresholds

**Usage Examples:**
```powershell
# Standard cleanup
.\Enterprise-DriveCleanup.ps1

# Dry run (simulation only)
.\Enterprise-DriveCleanup.ps1 -DryRun

# Clean only if below threshold
.\Enterprise-DriveCleanup.ps1 -MinimumFreeSpaceGB 50

# Skip specific operations
.\Enterprise-DriveCleanup.ps1 -SkipWindowsUpdate -SkipRecycleBin

# Send email report
.\Enterprise-DriveCleanup.ps1 -SendEmailReport -EmailTo "admin@company.com" `
    -EmailFrom "cleanup@company.com" -SmtpServer "smtp.company.com"

# Custom log path
.\Enterprise-DriveCleanup.ps1 -LogPath "D:\Logs\Cleanup"
```

**Cleanup Operations:**
1. **Windows Update Cache**
   - `C:\Windows\SoftwareDistribution\Download`
   - Old update files
   - Superseded packages

2. **Temporary Files**
   - `C:\Windows\Temp`
   - `C:\Users\*\AppData\Local\Temp`
   - System temp locations

3. **User Profiles**
   - Inactive profiles (configurable age)
   - Profile temp files
   - IE/Edge cache

4. **System Files**
   - Windows error reports
   - Delivery optimization files
   - Thumbnail cache
   - DNS cache files

5. **Recycle Bin**
   - All user recycle bins
   - System recycle bin

6. **Logs**
   - Old Windows logs
   - IIS logs (if applicable)
   - Application logs (configurable)

**Space Savings:**
- Typical: 2-10 GB
- Windows Update heavy: 10-30 GB
- Long-running systems: 30+ GB

---

### Windows-UpdateMaintenance.ps1
**Purpose:** Windows Update cache and component cleanup

**Features:**
- DISM cleanup operations
- Component store optimization
- Update cache management
- Service pack cleanup
- Integrity verification

**Usage Examples:**
```powershell
# Full cleanup
.\Windows-UpdateMaintenance.ps1

# Analyze only
.\Windows-UpdateMaintenance.ps1 -AnalyzeOnly

# Aggressive cleanup
.\Windows-UpdateMaintenance.ps1 -AggressiveCleanup
```

---

### Server-HealthCheck.ps1
**Purpose:** Comprehensive system health validation

**Features:**
- Disk space monitoring
- Service status checks
- Event log analysis
- Performance metrics
- Security updates status
- Certificate expiration
- Backup validation

**Usage Examples:**
```powershell
# Full health check
.\Server-HealthCheck.ps1

# Quick check
.\Server-HealthCheck.ps1 -QuickCheck

# Generate report
.\Server-HealthCheck.ps1 -GenerateReport -OutputPath "C:\Reports"
```

---

### Optimize-WindowsPerformance.ps1
**Purpose:** System performance optimization

**Features:**
- Service optimization
- Startup program management
- Page file optimization
- Visual effects tuning
- Network optimization
- Power plan configuration

**Usage Examples:**
```powershell
# Standard optimization
.\Optimize-WindowsPerformance.ps1

# Server optimization profile
.\Optimize-WindowsPerformance.ps1 -Profile Server

# Workstation profile
.\Optimize-WindowsPerformance.ps1 -Profile Workstation
```

---

## 🔧 Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-DryRun` | Simulate without changes | `$false` |
| `-LogPath` | Log file location | `C:\Logs\ScriptName` |
| `-MinimumFreeSpaceGB` | Space threshold | 20 GB |
| `-Verbose` | Detailed output | `$false` |
| `-SendEmailReport` | Email notifications | `$false` |

## 📊 Reporting

### Console Output
```
=== Enterprise Drive Cleanup ===
Start Time: 2025-11-01 10:00:00
Server: SERVER01

Current Status:
  Total Size: 500 GB
  Free Space: 45 GB (9%)
  Used Space: 455 GB (91%)

Cleanup Operations:
✓ Windows Update Cache: 8.5 GB recovered
✓ Temporary Files: 2.3 GB recovered
✓ Recycle Bin: 1.2 GB recovered
✓ Old Logs: 0.8 GB recovered

Final Status:
  Free Space: 57.8 GB (11.56%)
  Total Recovered: 12.8 GB
```

### Email Report
- Before/after disk space
- Operations performed
- Space recovered by category
- Warnings and errors
- Next scheduled run

## 🛡️ Safety Features

1. **Dry Run Mode**: Test without changes
2. **Space Validation**: Verify sufficient space
3. **Critical File Protection**: Never delete system files
4. **Service Dependencies**: Check before stopping services
5. **Rollback Capability**: Shadow copies maintained
6. **Logging**: Comprehensive audit trail

## ⚠️ Important Notes

### What Gets Deleted
✓ Safe to delete:
- Temp files older than 7 days
- Update cache files
- Old log files
- Recycle bin contents
- User temp folders

✗ Never deleted:
- System files
- Program files
- Active user data
- Recent temp files (<7 days)
- Critical logs (<30 days)

### Prerequisites
- Run as Administrator
- Minimum 5 GB free space required
- No critical processes running
- Backup recent data (recommended)

## 📈 Scheduling

### Task Scheduler Example
```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Scripts\Enterprise-DriveCleanup.ps1"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount

Register-ScheduledTask -TaskName "Weekly Drive Cleanup" `
    -Action $action -Trigger $trigger -Principal $principal
```

## 🔍 Troubleshooting

### Cleanup Failed
```powershell
# Check disk errors
chkdsk C: /scan

# Verify permissions
icacls C:\Windows\Temp

# Check disk space
Get-PSDrive C
```

### Services Won't Stop
```powershell
# Check dependencies
Get-Service -Name "ServiceName" | Select-Object -ExpandProperty DependentServices

# Force stop (use caution)
Stop-Service -Name "ServiceName" -Force
```

## 🔗 Related Resources

- [DISM Documentation](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism)
- [Disk Cleanup Tool](https://support.microsoft.com/en-us/windows/disk-cleanup-in-windows)
- [Maintenance Best Practices](../docs/maintenance-best-practices.md)

## 📝 Best Practices

1. **Schedule Regular Cleanups**: Weekly or monthly
2. **Monitor Trends**: Track space usage over time
3. **Test in Non-Production**: Verify before production use
4. **Review Logs**: Check for errors after cleanup
5. **Maintain Baselines**: Know normal space usage
6. **Document Exclusions**: Note files/folders to skip

## 🆘 Support

For maintenance script issues:
1. Run in dry-run mode first
2. Check system event logs
3. Verify free space before/after
4. Review script logs
5. Open GitHub issue with details

---

**Last Updated:** November 2025
