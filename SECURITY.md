# Security Policy

## Reporting Security Issues

If you discover a security vulnerability in this project, please report it responsibly:

- **Email:** Create a GitHub issue with the `security` label (do not include sensitive details publicly)
- **GitHub Security Advisory:** Use [GitHub's private security advisory feature](https://github.com/iloveyouit/powershell-automation-toolkit/security/advisories/new)

**DO NOT** create public issues that include details of security vulnerabilities.

## Supported Versions

We currently support the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Security Best Practices

When using scripts from this repository:

### Credential Management
- ✅ **Never hardcode credentials** in scripts
- ✅ Use `Get-Credential` for interactive credential prompts
- ✅ Store credentials securely using Windows Credential Manager or Azure Key Vault
- ✅ Use service accounts with minimum required permissions
- ✅ Rotate credentials regularly

### Script Execution
- ✅ **Review scripts before running** in production environments
- ✅ Test in non-production first
- ✅ Use `-WhatIf` parameter to preview changes
- ✅ Enable audit logging for all automation activities
- ✅ Validate script sources and integrity

### Configuration Files
- ✅ **Never commit sensitive configuration** to version control
- ✅ Use `.gitignore` to exclude credential files
- ✅ Store production configs separately from repository
- ✅ Use environment variables for sensitive values
- ✅ Encrypt configuration files containing secrets

### Network Security
- ✅ **Use encrypted connections** (HTTPS, WinRM over HTTPS)
- ✅ Validate SSL/TLS certificates in production
- ✅ Restrict script execution to authorized systems only
- ✅ Use firewall rules to limit access
- ✅ Log all remote connections and actions

### Code Security
- ✅ **Run PSScriptAnalyzer** on all scripts
- ✅ Avoid using `Invoke-Expression` with untrusted input
- ✅ Validate and sanitize all user inputs
- ✅ Use parameterized queries for database operations
- ✅ Keep PowerShell and modules up to date

## Known Security Considerations

### Self-Signed Certificates
Some scripts may disable certificate validation for lab environments. This is acceptable for:
- ✅ Isolated lab/development environments
- ✅ Testing and learning purposes

**Never use** certificate validation bypass in production environments.

### Hardcoded Values
Examples in this repository may contain:
- Default server names (replace with your environment)
- Sample credentials (always use `Get-Credential` in production)
- Test data (never use real production data)

### Remote Execution
Scripts that execute commands on remote systems:
- Require appropriate permissions (usually Administrator)
- Should use encrypted connections (HTTPS/TLS)
- Must log all actions for audit purposes
- Should implement timeout and error handling

## Security Updates

Security updates will be released as soon as possible after discovery. Subscribe to:
- GitHub repository releases
- Security advisory notifications
- GitHub watch feature for security updates

## Compliance

These scripts are designed for:
- ✅ Enterprise IT automation
- ✅ Infrastructure management
- ✅ System administration

Ensure compliance with your organization's:
- Security policies
- Change management procedures
- Audit requirements
- Data protection regulations

## Contact

For security concerns that don't require immediate attention:
- Open a GitHub issue with the `security` label
- Contact via GitHub discussions

For urgent security issues:
- Use GitHub's private security advisory feature
- Include: description, affected versions, reproduction steps, and potential impact

---

**Last Updated:** November 2025
**Version:** 1.0.0
