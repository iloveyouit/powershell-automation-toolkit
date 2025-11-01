# Network & Connectivity Scripts

PowerShell scripts for network diagnostics, connectivity testing, and remote management.

## 📋 Scripts in This Category

### Test-RemoteServerAccess.ps1
**Purpose:** Test remote PowerShell and WMI connectivity to Windows servers

**Features:**
- Network connectivity testing (ping, DNS)
- WinRM availability validation
- WMI access verification
- Port connectivity checks (RPC, SMB, WinRM)
- Bulk testing from CSV files
- Detailed diagnostics and troubleshooting
- Export results to CSV
- Alternate credential support

**Usage Examples:**
```powershell
# Test single server
.\Test-RemoteServerAccess.ps1 -ComputerName SERVER01

# Test multiple servers
.\Test-RemoteServerAccess.ps1 -ComputerName SERVER01,SERVER02,SERVER03

# Test from CSV file
.\Test-RemoteServerAccess.ps1 -CsvPath .\servers.csv

# Export results
.\Test-RemoteServerAccess.ps1 -CsvPath .\servers.csv -ExportResults

# Use alternate credentials
$cred = Get-Credential
.\Test-RemoteServerAccess.ps1 -ComputerName SERVER01 -Credential $cred

# Custom output path
.\Test-RemoteServerAccess.ps1 -ComputerName SERVER01 -ExportResults -OutputPath "C:\Reports"
```

**CSV File Format:**
```csv
ServerName
SERVER01
SERVER02
SERVER03
```

**Checks Performed:**
1. DNS Resolution
2. Network Connectivity (ICMP)
3. TCP Port Tests:
   - 135 (RPC Endpoint Mapper)
   - 445 (SMB)
   - 5985 (WinRM HTTP)
   - 5986 (WinRM HTTPS)
4. WinRM Configuration
5. WMI Connectivity
6. Remote PowerShell Session

**Troubleshooting Suggestions:**
- Firewall configuration guidance
- WinRM setup instructions
- Authentication issues
- Network path problems

---

### Network-Diagnostics.ps1
**Purpose:** Comprehensive network troubleshooting and diagnostics

**Features:**
- Route tracing
- Bandwidth testing
- Latency monitoring
- DNS validation
- Gateway connectivity
- Network adapter information

**Usage Examples:**
```powershell
# Full diagnostic
.\Network-Diagnostics.ps1

# Test specific target
.\Network-Diagnostics.ps1 -Target "google.com"

# Continuous monitoring
.\Network-Diagnostics.ps1 -ContinuousMonitoring -IntervalSeconds 60
```

---

### Port-Scanner.ps1
**Purpose:** Enterprise port scanning and service discovery

**Features:**
- TCP port scanning
- UDP port scanning
- Service identification
- Banner grabbing
- Vulnerability checks
- Compliance scanning

**Usage Examples:**
```powershell
# Scan common ports
.\Port-Scanner.ps1 -ComputerName SERVER01

# Scan specific ports
.\Port-Scanner.ps1 -ComputerName SERVER01 -Ports 80,443,3389

# Scan range
.\Port-Scanner.ps1 -ComputerName SERVER01 -PortRange 1-1024
```

---

### Test-NetworkPath.ps1
**Purpose:** Validate network paths and routing

**Features:**
- Traceroute functionality
- Path MTU discovery
- QoS validation
- Route analysis
- Performance metrics

**Usage Examples:**
```powershell
# Trace route
.\Test-NetworkPath.ps1 -Destination "8.8.8.8"

# Test MTU
.\Test-NetworkPath.ps1 -Destination "server.domain.com" -TestMTU
```

---

## 🔧 Common Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-ComputerName` | Target server(s) | Required |
| `-Credential` | Alternate credentials | Current user |
| `-Timeout` | Connection timeout (seconds) | 30 |
| `-ExportResults` | Export to CSV | `$false` |
| `-Verbose` | Detailed output | `$false` |

## 📊 Output Formats

### Console Output
```
Testing SERVER01...
✓ DNS Resolution: Success (10.0.1.50)
✓ Ping: Success (2ms)
✓ Port 5985: Open
✓ WinRM: Available
✓ Remote PowerShell: Success
```

### CSV Export
```csv
ComputerName,DNS,Ping,Port5985,WinRM,RemotePS,Details
SERVER01,Success,Success,Open,Available,Success,"All tests passed"
SERVER02,Success,Failed,Closed,Unavailable,Failed,"Firewall may be blocking"
```

## 🛡️ Security Considerations

1. **Port Scanning**: Use only on authorized systems
2. **Credentials**: Store securely, never in scripts
3. **Logging**: Enable for audit trails
4. **Compliance**: Follow organizational policies
5. **Rate Limiting**: Avoid overwhelming networks

## 🔍 Troubleshooting Common Issues

### WinRM Not Available
```powershell
# Enable WinRM on remote server
Enable-PSRemoting -Force

# Configure trusted hosts (if needed)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "SERVER01" -Force
```

### Firewall Blocking
```powershell
# Enable WinRM through firewall
Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP"

# Create custom rule
New-NetFirewallRule -Name "RemoteManagement" -DisplayName "Remote Management" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 5985
```

### DNS Issues
```powershell
# Clear DNS cache
Clear-DnsClientCache

# Test resolution
Resolve-DnsName SERVER01 -Server 8.8.8.8
```

## 📈 Performance Tips

1. **Parallel Processing**: Use `-Parallel` for multiple servers
2. **Timeout Tuning**: Adjust timeouts for slow networks
3. **Batch Processing**: Process large CSV files in chunks
4. **Result Caching**: Cache DNS lookups

## 🔗 Related Resources

- [PowerShell Remoting Guide](https://docs.microsoft.com/en-us/powershell/scripting/learn/remoting/)
- [WinRM Configuration](https://docs.microsoft.com/en-us/windows/win32/winrm/)
- [Network Troubleshooting](../docs/network-troubleshooting.md)

## 📝 Best Practices

1. Always test with `-WhatIf` first
2. Use credentials with minimal required permissions
3. Log all connectivity attempts
4. Schedule regular connectivity audits
5. Document network topology

## 🆘 Support

For networking script issues:
1. Check network connectivity manually
2. Review firewall logs
3. Verify DNS resolution
4. Test with `Test-NetConnection`
5. Open GitHub issue with diagnostic output

---

**Last Updated:** November 2025
