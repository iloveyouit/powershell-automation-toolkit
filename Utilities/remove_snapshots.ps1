# VMware VM Snapshot Removal Script
# This script connects to a vCenter server and removes snapshots created by the snapshot.ps1 script
# that were created for server patching by LVS

# Connect to the vCenter server
Connect-VIServer -Server "192.168.2.133" -User "administrator@vsphere.local" -Password "#*"
#Connect-VIServer -Server "192.168.0.171" -User "root" -Password "#*"

# Path to the text file containing VM names
$vmListPath = "C:\temp\vm_list.txt"

# Check if the file exists
if (Test-Path $vmListPath) {
    # Read VM names from the text file
    $vmNames = Get-Content -Path $vmListPath
    
    # Track statistics
    $successCount = 0
    $failCount = 0
    $noSnapshotCount = 0
    
    Write-Host "Starting snapshot removal process..." -ForegroundColor Cyan
    
    foreach ($vmName in $vmNames) {
        # Trim any whitespace from the VM name
        $vmName = $vmName.Trim()
        
        # Get the VM object
        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        
        if ($vm) {
            # Get all snapshots for this VM
            $snapshots = Get-Snapshot -VM $vm -ErrorAction SilentlyContinue | 
                         Where-Object { $_.Description -like "*by LVS for server patching*" }
            
            if ($snapshots) {
                $snapshotCount = ($snapshots | Measure-Object).Count
                Write-Host "Found $snapshotCount snapshot(s) to remove for VM: $vmName" -ForegroundColor Yellow
                
                foreach ($snapshot in $snapshots) {
                    try {
                        Write-Host "  Removing snapshot: $($snapshot.Name) created on $($snapshot.Created)" -ForegroundColor Yellow
                        Remove-Snapshot -Snapshot $snapshot -Confirm:$false -ErrorAction Stop
                        Write-Host "  Successfully removed snapshot: $($snapshot.Name)" -ForegroundColor Green
                        $successCount++
                    }
                    catch {
                        Write-Host "  Failed to remove snapshot: $($snapshot.Name). Error: $($_.Exception.Message)" -ForegroundColor Red
                        $failCount++
                    }
                }
            }
            else {
                Write-Host "No matching snapshots found for VM: $vmName" -ForegroundColor Gray
                $noSnapshotCount++
            }
        }
        else {
            Write-Host "VM not found: $vmName" -ForegroundColor Red
            $failCount++
        }
    }
    
    # Display summary
    Write-Host "`nSnapshot Removal Summary:" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan
    Write-Host "Successfully removed: $successCount snapshot(s)" -ForegroundColor Green
    Write-Host "Failed to remove: $failCount snapshot(s)" -ForegroundColor Red
    Write-Host "VMs with no matching snapshots: $noSnapshotCount" -ForegroundColor Gray
    
} else {
    Write-Host "The file $vmListPath does not exist." -ForegroundColor Red
    Write-Host "Please create this file with a list of VM names before running this script." -ForegroundColor Yellow
}

# Disconnect from the vCenter server
Disconnect-VIServer -Server "192.168.2.133" -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Disconnected from vCenter server." -ForegroundColor Cyan
