<#
.SYNOPSIS
    Removes VMware snapshots created for server patching operations.

.DESCRIPTION
    This script connects to a vCenter server and removes snapshots that match specific criteria.
    By default, it removes snapshots with descriptions containing "by LVS for server patching".
    VM names are read from a text file (one per line).

    The script provides:
    - Safety confirmation before removal
    - Detailed progress reporting
    - Summary statistics
    - Error handling and logging

.PARAMETER Server
    vCenter Server or ESXi host IP address or FQDN (default: 192.168.2.133)

.PARAMETER Credential
    PSCredential object for authentication. If not provided, will prompt for credentials.

.PARAMETER VMListPath
    Path to text file containing VM names (one per line). Default: C:\temp\vm_list.txt

.PARAMETER SnapshotFilter
    Filter string for snapshot descriptions (default: "*by LVS for server patching*")

.PARAMETER WhatIf
    Shows what would be removed without actually removing snapshots.

.EXAMPLE
    .\remove_snapshots.ps1

    Removes matching snapshots from VMs listed in C:\temp\vm_list.txt

.EXAMPLE
    .\remove_snapshots.ps1 -WhatIf

    Preview which snapshots would be removed without actually removing them.

.EXAMPLE
    .\remove_snapshots.ps1 -Server "vcenter.company.com" -VMListPath "D:\patching\servers.txt"

    Uses custom server and VM list path.

.EXAMPLE
    $cred = Get-Credential
    .\remove_snapshots.ps1 -Server "192.168.0.171" -Credential $cred -SnapshotFilter "*pre-patch*"

    Uses custom credentials and removes snapshots matching different description.

.NOTES
    Author: LVS
    Modified: 2025-10-28
    Requires: VMware PowerCLI module
    Version: 2.0

    WARNING: Snapshot removal is irreversible. Always verify you're removing the correct snapshots.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$Server = "192.168.2.133",

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$VMListPath = "C:\temp\vm_list.txt",

    [Parameter(Mandatory = $false)]
    [string]$SnapshotFilter = "*by LVS for server patching*"
)

#region Main Script

Write-Host "`n=== VMware Snapshot Removal Script ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Cyan

# Connect to vCenter if not already connected
$needsConnection = $true
if ($global:DefaultVIServer -and $global:DefaultVIServer.IsConnected) {
    Write-Host "`nUsing existing connection to: $($global:DefaultVIServer.Name)" -ForegroundColor Green
    $needsConnection = $false
}

if ($needsConnection) {
    try {
        if (-not $Credential) {
            Write-Host "`nEnter credentials for $Server" -ForegroundColor Cyan
            $Credential = Get-Credential -Message "Enter credentials for $Server"
        }

        Write-Host "Connecting to vCenter Server: $Server" -ForegroundColor Cyan
        Connect-VIServer -Server $Server -Credential $Credential -ErrorAction Stop | Out-Null
        Write-Host "Successfully connected to $Server" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to connect to $Server : $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Check if VM list file exists
if (-not (Test-Path $VMListPath)) {
    Write-Host "`nERROR: VM list file not found: $VMListPath" -ForegroundColor Red
    Write-Host "Please create this file with one VM name per line." -ForegroundColor Yellow
    if ($needsConnection) {
        Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
    }
    exit 1
}

# Check if the file exists
if (Test-Path $VMListPath) {
    # Read VM names from the text file
    $vmNames = Get-Content -Path $VMListPath | Where-Object { $_.Trim() -ne "" }
    
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
            # Get all snapshots for this VM matching the filter
            $snapshots = Get-Snapshot -VM $vm -ErrorAction SilentlyContinue |
                         Where-Object { $_.Description -like $SnapshotFilter }
            
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
    
}

Write-Host "`n=== Operation Complete ===" -ForegroundColor Cyan
Write-Host "Completed at: $(Get-Date)" -ForegroundColor Cyan

# Disconnect if we connected in this script
if ($needsConnection) {
    Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Disconnected from vCenter server" -ForegroundColor Cyan
}

#endregion
