
<#
.SYNOPSIS
    Gathers basic inventory information for all virtual machines in a vCenter Server.

.DESCRIPTION
    This script connects to a vCenter Server, retrieves a list of all VMs, and collects comprehensive information:
    - VM Name
    - Power State
    - CPU Count
    - Memory (GB)
    - NIC Count
    - IP Address
    - VMware Tools Version
    - VMware Tools Status

    The collected data is exported to a timestamped CSV file for record-keeping and analysis.

.PARAMETER vCenterServer
    The FQDN or IP address of the vCenter Server to connect to.

.PARAMETER Credential
    PSCredential object for authentication. If not provided, will prompt for credentials.

.EXAMPLE
    .\Get-VMwareInventory.ps1 -vCenterServer "vc01.example.com"

    Connects to vCenter server and exports VM inventory to CSV with current date.

.EXAMPLE
    $cred = Get-Credential
    .\Get-VMwareInventory.ps1 -vCenterServer "192.168.0.171" -Credential $cred

    Uses pre-defined credentials to connect and gather inventory.

.EXAMPLE
    .\Get-VMwareInventory.ps1 -vCenterServer "vcenter.company.com"

    Standard inventory collection with prompting for credentials.

.NOTES
    Author: System Administrator
    Date: 2025-10-28
    Requires: VMware PowerCLI module
    Version: 1.1
#>
param (
    [string]$vCenterServer,
    [System.Management.Automation.PSCredential]$Credential = (Get-Credential)
)

# Connect to vCenter Server
Write-Host "Connecting to vCenter Server: $vCenterServer"
Connect-VIServer -Server $vCenterServer -Credential $Credential

# Get all VMs
$vms = Get-VM

$inventory = foreach ($vm in $vms) {
    Write-Progress -Activity "Gathering VM Information" -Status "Processing $($vm.Name)" -PercentComplete (($vms.IndexOf($vm) / $vms.Count) * 100)
    [PSCustomObject]@{
        "VM Name" = $vm.Name
        "Power State" = $vm.PowerState
        "CPU Count" = $vm.NumCpu
        "Memory (GB)" = [math]::Round($vm.MemoryGB, 2)
        "NIC Count" = ($vm.Guest.Nics | Measure-Object).Count
        "IP Address" = $vm.Guest.IpAddress -join ','
        "VMware Tools Version" = $vm.Guest.ToolsVersion
        "VMware Tools Status" = $vm.Guest.ToolsStatus
    }
}

# Export to CSV
$date = Get-Date -Format "yyyy-MM-dd"
$filename = "VMware-Inventory-$date.csv"
$inventory | Export-Csv -Path $filename -NoTypeInformation

Write-Host "Inventory complete. Data exported to $filename"

# Disconnect from vCenter Server
Disconnect-VIServer -Server $vCenterServer -Confirm:$false
