# Changelog

All notable changes to the PowerShell Automation Toolkit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned Features
- Active Directory health check automation
- Enhanced Azure monitoring capabilities
- Security compliance reporting dashboard
- Automated backup validation scripts

## [1.0.0] - 2025-11-01

### Added - Initial Release

#### Azure & Cloud Management
- `Fix-ADSync-PHS.ps1` - Azure AD Connect Password Hash Sync troubleshooting and remediation
- Comprehensive checks for services, scheduler, connectivity, and disk space
- Multiple execution modes: standard, aggressive purge, and dry-run
- Database maintenance for LocalDB management

#### Network & Connectivity
- `Test-RemoteServerAccess.ps1` - Remote PowerShell connectivity testing
- WinRM and WMI access validation
- CSV input support for bulk testing
- Detailed diagnostics and troubleshooting suggestions
- Export results to CSV capability

#### System Maintenance
- `Enterprise-DriveCleanup.ps1` - Enterprise-level C: drive cleanup
- Windows Update cache cleanup
- Temporary files management
- Recycle bin handling
- Comprehensive logging and reporting
- Dry-run mode for testing
- Email report capability

#### Documentation
- Comprehensive README with usage examples
- MIT License
- Repository structure and organization
- Security best practices guide
- Contributing guidelines

### Repository Features
- Organized directory structure by category
- Consistent logging across all scripts
- Standardized parameter usage
- Error handling and validation
- PowerShell 5.1+ compatibility
- Windows Server 2016/2019/2022 support

---

## Version Numbering

- **Major version (X.0.0)**: Incompatible API changes or major restructuring
- **Minor version (0.X.0)**: New functionality in a backwards-compatible manner
- **Patch version (0.0.X)**: Backwards-compatible bug fixes

## Categories for Changes

- **Added**: New features or scripts
- **Changed**: Changes to existing functionality
- **Deprecated**: Features that will be removed in upcoming releases
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security-related changes or fixes

---

**Note:** For detailed commit history, see the [GitHub repository](https://github.com/YOUR-USERNAME/powershell-automation-toolkit/commits/main).
