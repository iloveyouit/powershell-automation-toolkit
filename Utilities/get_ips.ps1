<#
.SYNOPSIS
    Collects VMware VM names and IP addresses using PowerCLI.

.DESCRIPTION
    This script retrieves all virtual machines and their current IP addresses from VMware Tools.
    The script requires an active connection to vCenter or ESXi (use Connect-VIServer first).

    Features:
    - Displays VM name, power state, and IP addresses
    - Handles multiple IPs per VM (comma-separated)
    - Shows N/A for VMs without VMware Tools or powered-off VMs
    - Optional CSV export functionality

.PARAMETER ReportPath
    Path where the CSV report will be saved (default: C:\Temp\VM_IP_Report_<timestamp>.csv)

.PARAMETER ExportToCsv
    Switch to enable CSV export. By default, results are only displayed to console.

.PARAMETER FilterPoweredOn
    Switch to only show powered-on VMs.

.EXAMPLE
    .\get_ips.ps1

    Displays all VM names and IP addresses to the console.

.EXAMPLE
    .\get_ips.ps1 -ExportToCsv

    Displays VM information and exports to CSV file in C:\Temp.

.EXAMPLE
    .\get_ips.ps1 -FilterPoweredOn

    Shows only powered-on VMs with their IP addresses.

.EXAMPLE
    Connect-VIServer -Server "192.168.0.171"
    .\get_ips.ps1 -ExportToCsv -ReportPath "D:\Reports\VM_IPs.csv"

    Uses existing connection and exports to custom path.

.NOTES
    Author: Rob Loftin
    Modified: 2025-10-28
    Requires: VMware PowerCLI module and active vCenter connection
    Version: 1.1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ReportPath = "C:\Temp\VM_IP_Report_$(Get-Date -Format 'yyyyMMdd_HHmm').csv",

    [Parameter(Mandatory = $false)]
    [switch]$ExportToCsv,

    [Parameter(Mandatory = $false)]
    [switch]$FilterPoweredOn
)

# ==========================
# MAIN SCRIPT
# ==========================

# Check for active vCenter connection
if (-not $global:DefaultVIServer) {
    Write-Host "ERROR: Not connected to vCenter or ESXi host." -ForegroundColor Red
    Write-Host "Please connect first using: Connect-VIServer -Server <server>" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== VM IP Address Report ===" -ForegroundColor Cyan
Write-Host "Connected to: $($global:DefaultVIServer.Name)" -ForegroundColor Green
Write-Host "Collecting VM IP data..." -ForegroundColor Cyan

# Get all VMs and collect data
$vms = Get-VM | Select-Object Name,
    @{Name="PowerState"; Expression={$_.PowerState}},
    @{Name="IPAddress"; Expression={
        $ip = $_.Guest.IPAddress
        if ($ip -is [array]) { $ip -join ", " } elseif ($ip) { $ip } else { "N/A" }
    }},
    @{Name="ToolsStatus"; Expression={$_.ExtensionData.Guest.ToolsStatus}},
    @{Name="GuestOS"; Expression={$_.Guest.OSFullName}}

# Apply filter if requested
if ($FilterPoweredOn) {
    Write-Host "Filtering for powered-on VMs only..." -ForegroundColor Yellow
    $vms = $vms | Where-Object { $_.PowerState -eq "PoweredOn" }
}

# Display to console
Write-Host "`nTotal VMs: $($vms.Count)" -ForegroundColor Cyan
$vms | Format-Table -AutoSize

# Export to CSV if requested
if ($ExportToCsv) {
    try {
        # Create directory if it doesn't exist
        $directory = Split-Path -Path $ReportPath -Parent
        if ($directory -and -not (Test-Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        $vms | Export-Csv -Path $ReportPath -NoTypeInformation -Force
        Write-Host "`nReport exported to: $ReportPath" -ForegroundColor Green
    }
    catch {
        Write-Host "`nERROR: Failed to export CSV: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "`nTo export to CSV, use the -ExportToCsv parameter" -ForegroundColor Yellow
}

Write-Host "`n=== Report Complete ===" -ForegroundColor Cyan