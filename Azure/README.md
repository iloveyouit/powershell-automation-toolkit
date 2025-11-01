# Azure & Cloud Management Scripts

PowerShell automation scripts for Azure AD Connect, Azure AD, and Microsoft 365 management.

## 📋 Scripts in This Category

### Fix-ADSync-PHS.ps1
**Purpose:** Automated Azure AD Connect Password Hash Sync troubleshooting and remediation

**Features:**
- Comprehensive health checks (services, scheduler, connectivity)
- Disk space validation and cleanup
- LocalDB maintenance for oversized databases
- Multiple execution modes (standard, aggressive, dry-run)
- Detailed logging and reporting
- Email notifications (optional)

**Usage Examples:**
```powershell
# Standard fix
.\Fix-ADSync-PHS.ps1

# Aggressive cleanup mode
.\Fix-ADSync-PHS.ps1 -AggressivePurge

# Dry run (simulation)
.\Fix-ADSync-PHS.ps1 -DryRun

# Custom log path
.\Fix-ADSync-PHS.ps1 -LogPath "D:\Logs\ADSync"
```

**Prerequisites:**
- Azure AD Connect installed
- Run with Administrator privileges
- ADSync PowerShell module available

**Common Issues Addressed:**
- Password Hash Sync heartbeat skipped (120+ minutes)
- Sync cycle not running
- Database size issues
- Service failures
- Connectivity problems

---

### Test-AzureADConnectivity.ps1
**Purpose:** Validate connectivity to Azure AD endpoints

**Features:**
- Tests connectivity to required Azure endpoints
- Validates proxy settings
- Checks DNS resolution
- Certificate validation
- Network trace capability

**Usage Examples:**
```powershell
# Basic connectivity test
.\Test-AzureADConnectivity.ps1

# Test with proxy
.\Test-AzureADConnectivity.ps1 -ProxyServer "proxy.company.com:8080"

# Detailed network trace
.\Test-AzureADConnectivity.ps1 -NetworkTrace
```

---

### Monitor-AzureADSync.ps1
**Purpose:** Continuous monitoring of Azure AD Connect synchronization

**Features:**
- Scheduled health checks
- Performance metrics collection
- Alert on sync failures
- Historical tracking
- Dashboard reporting

**Usage Examples:**
```powershell
# Start monitoring
.\Monitor-AzureADSync.ps1 -IntervalMinutes 15

# One-time check
.\Monitor-AzureADSync.ps1 -RunOnce

# Generate report
.\Monitor-AzureADSync.ps1 -GenerateReport
```

---

## 🔧 Common Parameters

Most scripts in this category support:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-LogPath` | Custom log file location | `C:\Logs\ScriptName` |
| `-DryRun` | Simulate without changes | `$false` |
| `-Verbose` | Detailed output | `$false` |
| `-SendEmail` | Email notifications | `$false` |
| `-EmailTo` | Recipient address | None |

## 📊 Logging

All Azure scripts log to:
- Default: `C:\Logs\Azure\ScriptName\`
- Format: `ScriptName_YYYYMMDD_HHMMSS.log`
- Retention: 30 days (configurable)

## 🛡️ Security Considerations

1. **Credentials**: Never hardcode credentials
2. **Permissions**: Run with least privilege required
3. **Audit**: Enable logging for compliance
4. **Encryption**: Use TLS 1.2 or higher
5. **Secrets**: Store in Azure Key Vault when possible

## 🔗 Related Resources

- [Azure AD Connect Documentation](https://docs.microsoft.com/en-us/azure/active-directory/hybrid/)
- [Azure AD PowerShell Module](https://docs.microsoft.com/en-us/powershell/azure/active-directory/)
- [Troubleshooting Guide](../docs/azure-troubleshooting.md)

## 📝 Notes

- Test all scripts in non-production first
- Review and customize for your environment
- Monitor logs after deployment
- Schedule regular maintenance windows

## 🆘 Support

For issues specific to Azure scripts:
1. Check the troubleshooting guide
2. Review script logs
3. Open a GitHub issue with details
4. Include error messages and environment info

---

**Last Updated:** November 2025
