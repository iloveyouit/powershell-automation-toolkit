# PowerShell Automation Toolkit

> Enterprise-grade PowerShell scripts and automation tools for Windows Server administration, Azure AD management, and infrastructure operations.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📋 Overview

This repository contains a comprehensive collection of production-ready PowerShell scripts designed for enterprise IT infrastructure management. All scripts include robust error handling, logging capabilities, and are tested for Windows Server 2016/2019/2022 environments.

## 🗂️ Repository Structure

```
powershell-automation-toolkit/
├── ActiveDirectory/          # AD management and maintenance scripts
├── Azure/                    # Azure AD Connect and cloud management
├── Maintenance/              # System cleanup and maintenance
├── Monitoring/               # Health checks and monitoring tools
├── Networking/               # Network connectivity and diagnostics
├── Security/                 # Security audit and compliance scripts
├── Utilities/                # General utility scripts
├── docs/                     # Documentation and guides
└── templates/                # Script templates and examples
```

## 🚀 Quick Start

### Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- Administrator privileges (for most scripts)
- Appropriate Windows Server versions (2016/2019/2022)
- Network access to target systems

### Installation

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/iloveyouit/powershell-automation-toolkit.git
   cd powershell-automation-toolkit
   ```

2. **Set execution policy (if needed):**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Import required modules:**
   ```powershell
   # Each script will specify its requirements
   Import-Module ActiveDirectory
   ```

## 📚 Script Categories

### Active Directory Management
- **AD-HealthCheck.ps1** - Comprehensive AD health monitoring
- **AD-UserCleanup.ps1** - Automated stale account management
- **AD-ReplicationMonitor.ps1** - Replication status monitoring

### Azure & Cloud Management
- **Fix-ADSync-PHS.ps1** - Azure AD Connect PHS troubleshooting
- **Test-AzureADConnectivity.ps1** - Azure connectivity validation
- **Monitor-AzureADSync.ps1** - Automated sync monitoring

### System Maintenance
- **Enterprise-DriveCleanup.ps1** - Comprehensive disk cleanup
- **Windows-UpdateMaintenance.ps1** - Update cache management
- **Server-HealthCheck.ps1** - Overall system health audit

### Network & Connectivity
- **Test-RemoteServerAccess.ps1** - Remote PowerShell connectivity testing
- **Network-Diagnostics.ps1** - Comprehensive network troubleshooting
- **Port-Scanner.ps1** - Enterprise port scanning utility

### Security & Compliance
- **Security-Audit.ps1** - System security configuration audit
- **Compliance-Check.ps1** - Policy compliance validation
- **Event-LogAnalyzer.ps1** - Security event log analysis

## 💡 Featured Scripts

### Test-RemoteServerAccess.ps1
Tests remote connectivity and WMI/PowerShell access to Windows servers with detailed diagnostics.

```powershell
# Test single server
.\Test-RemoteServerAccess.ps1 -ComputerName SERVER01

# Test from CSV file
.\Test-RemoteServerAccess.ps1 -CsvPath .\servers.csv -ExportResults

# Test with alternate credentials
$cred = Get-Credential
.\Test-RemoteServerAccess.ps1 -ComputerName SERVER01 -Credential $cred
```

### Enterprise-DriveCleanup.ps1
Enterprise-level C: drive cleanup with comprehensive logging and safety checks.

```powershell
# Standard cleanup
.\Enterprise-DriveCleanup.ps1

# Dry run (simulation)
.\Enterprise-DriveCleanup.ps1 -DryRun

# Cleanup only if below threshold
.\Enterprise-DriveCleanup.ps1 -MinimumFreeSpaceGB 50
```

### Fix-ADSync-PHS.ps1
Automated Azure AD Connect Password Hash Sync troubleshooting and remediation.

```powershell
# Standard fix
.\Fix-ADSync-PHS.ps1

# Aggressive cleanup mode
.\Fix-ADSync-PHS.ps1 -AggressivePurge

# Dry run mode
.\Fix-ADSync-PHS.ps1 -DryRun
```

## 📖 Documentation

Detailed documentation for each script is available in the `/docs` directory:

- [Getting Started Guide](docs/getting-started.md)
- [Best Practices](docs/best-practices.md)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Security Considerations](docs/security.md)
- [Contributing Guidelines](docs/contributing.md)

## 🔧 Common Parameters

Most scripts support these standard parameters:

- `-DryRun` - Simulate operations without making changes
- `-Verbose` - Enable detailed output
- `-LogPath` - Specify custom log file location
- `-Credential` - Use alternate credentials
- `-WhatIf` - Preview changes before execution

## ⚙️ Configuration

Many scripts use configuration files located in `/config`:

```powershell
# Example: Update email settings for reports
$config = @{
    SmtpServer = "smtp.company.com"
    From = "automation@company.com"
    To = "admin@company.com"
}
```

## 🛡️ Security Best Practices

1. **Always test scripts in non-production first**
2. **Review and customize scripts for your environment**
3. **Use least-privilege accounts where possible**
4. **Store credentials securely (never hardcode)**
5. **Enable logging for audit trails**
6. **Regularly update and patch systems**

## 📊 Logging

All scripts generate logs in a consistent format:

- Default location: `C:\Logs\ScriptName\`
- Format: `ScriptName_YYYYMMDD_HHMMSS.log`
- Retention: Configurable (default 30 days)

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](docs/contributing.md) before submitting pull requests.

### Development Guidelines

1. Follow PowerShell best practices and style guide
2. Include comprehensive help documentation
3. Add error handling and logging
4. Test in multiple environments
5. Update documentation as needed

## 📝 Version History

See [CHANGELOG.md](CHANGELOG.md) for detailed version history and updates.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues:** Report bugs or request features via [GitHub Issues](https://github.com/iloveyouit/powershell-automation-toolkit/issues)
- **Documentation:** Check the `/docs` directory
- **Community:** Join discussions in [GitHub Discussions](https://github.com/iloveyouit/powershell-automation-toolkit/discussions)

## 🙏 Acknowledgments

- Microsoft PowerShell Team
- Enterprise IT community contributors
- Open source PowerShell module developers

## 📞 Contact

For enterprise support or custom script development:
- Create an issue on GitHub
- Review existing documentation
- Check troubleshooting guides

---

**⚠️ Disclaimer:** These scripts are provided as-is. Always test thoroughly in non-production environments before deploying to production systems. Review and customize scripts to match your organization's requirements and security policies.

**Last Updated:** November 2025
