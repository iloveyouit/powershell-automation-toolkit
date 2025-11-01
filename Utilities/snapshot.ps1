# VMware VM Snapshot Script by LVS for server patching
# This script connects to a vCenter server and takes snapshots of specified VMs, including VM memory.
# by LVS for server patching

# Connect to the vCenter server
#Connect-VIServer -Server "192.168.2.133" -User "administrator@vsphere.local" -Password "Sneake1uc"

# Path to the text file containing VM names
$vmListPath = "C:\temp\vm_list.txt"

# Check if the file exists
if (Test-Path $vmListPath) {
    # Read VM names from the text file
    $vmNames = Get-Content -Path $vmListPath

    foreach ($vmName in $vmNames) {
        # Trim any whitespace from the VM name
        $vmName = $vmName.Trim()

        # Get the VM object
        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue

        if ($vm) {
            # Take a snapshot of the VM
            $snapshotName = "Snapshot_" + (Get-Date -Format "yyyyMMdd_HHmmss")
            New-Snapshot -VM $vm -Name $snapshotName -Description "Snapshot taken on $(Get-Date) by LVS for server patching" -Memory
            Write-Host "Snapshot with memory created for VM: $vmName with snapshot name: $snapshotName"
        } else {
            Write-Host "VM not found: $vmName"
        }
    }
} else {
    Write-Host "The file $vmListPath does not exist."
}

# Disconnect from the vCenter server
Disconnect-VIServer -Server "192.168.2.133" -Confirm:$false