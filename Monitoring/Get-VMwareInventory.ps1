
<#
.SYNOPSIS
    This script gathers basic inventory information for all virtual machines in a vCenter Server.
.DESCRIPTION
    The script connects to a vCenter Server, retrieves a list of all VMs, and for each VM, it collects the following information:
    - VM Name
    - Power State
    - CPU Count
    - Memory (GB)
    - NIC Count
    - IP Address
    - VMware Tools Version
    - VMware Tools Status
    The collected data is then exported to a CSV file.
.PARAMETER vCenterServer
    The FQDN or IP address of the vCenter Server.
.PARAMETER Credential
    Specifies a user account that has permission to perform this action.
.EXAMPLE
    .C:\Get-VMwareInventory.ps1 -vCenterServer vc01.example.com
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
