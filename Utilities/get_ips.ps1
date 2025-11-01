<#
.SYNOPSIS
    Collects VMware VM names and IP addresses using PowerCLI.
.DESCRIPTION
    This script retrieves all virtual machines and their current IP addresses
    (if VMware Tools is running). You must already be connected to vCenter or ESXi.
.EXAMPLE
    .\Get-VM-IPReport.ps1
.NOTES
    Author: Rob Loftin
    Requires: VMware PowerCLI module
    Version: 1.0
#>

# ==========================
# CONFIGURATION
# ==========================
$ReportPath = "C:\Temp\VM_IP_Report_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"

# ==========================
# MAIN
# ==========================
Write-Host "Collecting VM IP data..." -ForegroundColor Cyan

# 1️⃣ Get all VMs and display Name + IPs
$vms = Get-VM | Select-Object Name,
    @{Name="PowerState";Expression={$_.PowerState}},
    @{Name="IPAddress";Expression={
        $ip = $_.Guest.IPAddress
        if ($ip -is [array]) { $ip -join ", " } elseif ($ip) { $ip } else { "N/A" }
    }}

# 2️⃣ Display to console
$vms | Format-Table -AutoSize

# 3️⃣ Export to CSV
#$vms | Export-Csv -Path $ReportPath -NoTypeInformation -Force

Write-Host "`nReport exported to: $ReportPath" -ForegroundColor Green

# 4️⃣ Optional - Filter out blank IPs
# Uncomment below line if you only want VMs with valid IP addresses
# $vms | Where-Object { $_.IPAddress -ne "N/A" } | Export-Csv -Path $ReportPath -NoTypeInformation -Force